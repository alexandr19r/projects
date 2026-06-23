#!/bin/bash
# [utils.sh] - Профессиональный инструментарий хелперов v2026.1

[[ -n "${_UTILS_SH_:-}" ]] && return
readonly _UTILS_SH_=1

# --- СИСТЕМНЫЕ ПРОВЕРКИ ---

# Проверка наличия прав (root)
is_root() { [[ $EUID -eq 0 ]]; }

# Прерывание выполнения, если не root
check_root() {
    is_root || { log_error "Операция требует прав root."; exit 1; }
}

# Проверка наличия утилиты в системе
# Использование: has_command "zstd" || exit 1
has_command() {
    command -v "$1" &> /dev/null
}

# Проверка, является ли путь папкой и доступен ли он на запись
# Использование: is_writable_dir "/var/backups"
is_writable_dir() {
    [[ -d "$1" && -w "$1" ]]
}

# --- ВАЛИДАЦИЯ ДАННЫХ ---

# Проверка на пустоту переменных (поддерживает несколько аргументов)
is_empty() {
    for arg in "$@"; do
        [[ -z "${arg-}" ]] && return 0
    done
    return 1
}

# Проверка, является ли строка числом
is_numeric() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# --- СЕТЕВЫЕ ХЕЛПЕРЫ ---

# Проверка доступности интернет-соединения (через Google DNS)
has_internet() {
    timeout 2 bash -c 'cat < /dev/null > /dev/tcp/8.8.8.8/53' &> /dev/null
}

# Получение внешнего IP-адреса
get_external_ip() {
    curl -s --connect-timeout 3 https://ifconfig.me || echo "unknown"
}

# --- ФОРМАТИРОВАНИЕ И ТЕКСТ ---

# Приведение текста к нижнему регистру (Bash 4+)
to_lower() {
    echo "${1,,}"
}

# Генерация случайной строки заданной длины (безопасный метод)
# Использование: generate_token 16
generate_token() {
    local length="${1:-32}"
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c "$length"
}

# --- РАБОТА С ФАЙЛАМИ ---

# Безопасное удаление временных файлов (атомарно)
safe_remove() {
    [[ -f "$1" ]] && rm -f "$1"
}

# Получение размера файла в человекочитаемом виде
get_file_size() {
    [[ -f "$1" ]] && du -sh "$1" | cut -f1
}

# --- UI ХЕЛПЕРЫ ---

# Отрисовка разделительной линии на всю ширину терминала
draw_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' "${1:-=}"
}

# ДРУГИЕ ФУНКЦИИ

# Проверка существования связки user:group
# Гарантирует наличие пользователя и группы в системе
ensure_owner_exists() {
    local owner_str="$1"
    local user_name="${owner_str%:*}"
    local group_name="${owner_str#*:}"

    # 1. Если группа указана и её нет — создаем её как системную
    if [[ -n "$group_name" && "$group_name" != "$user_name" ]]; then
        if ! getent group "$group_name" >/dev/null 2>&1; then
            log_warn "Группа [$group_name] не найдена. Создаю системную группу..."
            if ! _exec "Создание системной группы $group_name" groupadd -r "$group_name"; then
                log_error "Не удалось создать группу: $group_name"
                return 1
            fi
        fi
    fi

    # 2. Если пользователя нет — создаем его как системного
    if ! getent passwd "$user_name" >/dev/null 2>&1; then
        log_warn "Пользователь [$user_name] не найден. Создаю системного пользователя..."
        
        # Параметры: -r (system), -s (nologin), -g (primary group)
        local user_opts="-r -s /usr/sbin/nologin"
        
        # Если группа была указана, привязываем пользователя к ней
        if [[ -n "$group_name" && "$group_name" != "$user_name" ]]; then
            if [[ "${DRY_RUN:-false}" == "true" ]] && ! getent group "$group_name" >/dev/null 2>&1; then
                log_error "Критическая ошибка: Попытка создать пользователя с несуществующей группой [$group_name]"
                return 1
            fi
            user_opts+=(-g "$group_name")
        fi

        # Выполняем создание пользователя через прокси-перехватчик
        if ! _exec "Создание системного пользователя $user_name" useradd "${user_opts[@]}" "$user_name"; then
            log_error "Не удалось создать пользователя: $user_name"
            return 1
        fi
        useradd $user_opts "$user_name" || { 
            log_error "Не удалось создать пользователя $user_name"
            return 1 
        }

        # Выводим статус успеха (в DRY-RUN режиме пишем инфо-заглушку)
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_warn "[DRY-RUN] Имитация успешного создания пользователя [$user_name]"
        else
            log_ok "Пользователь [$user_name] успешно создан в системе."
        fi
    fi

    return 0
}

# Универсальный конструктор путей
# Аргументы: path, type(dir|file), owner(user:group), mode(octal), target_path(link)
ensure_path_exists() {
    local path="${1:-}" 
    local type="${2:-dir}" 
    local owner="${3:-root:root}" 
    local mode="${4:-}"
    local target_path="${5:-}"
    
    # Удаляем любые пробелы по краям из переменной type
    log_debug "Тип текущего обрабатываемого объекта -${type}-"

    [[ -z "$path" ]] && { log_error "Переменная path пустая строка."; return 1; }
    
    # Логика создания родительских директорий для файлов и ссылок
    if [[ "$type" == "file" || "$type" == "link" ]]; then
        local parent_dir
        parent_dir=$(dirname "$path")

        if [[ ! -d "$parent_dir" ]]; then
            if ! _exec "Создание родительской папки для $path" mkdir -p "$parent_dir"; then
                log_error "Ошибка создания родительской папки: $parent_dir"
                return 1
            fi        
        fi
    fi

    # Создание объекта в зависимости от типа
    case "$type" in
        dir)
            if [[ ! -d "$path" ]]; then
                # Защита: если на месте папки файл или ссылка, удаляем их
                if [[ -e "$path" || -L "$path" ]]; then
                    _exec "Удаление конфликтующего объекта на месте папки $path" rm -rf "$path"
                fi
                _exec "Создание директории $path" mkdir -p "$path" || return 1
            fi
            ;;
        file)
            if [[ ! -f "$path" ]]; then
                # Защита: если на месте файла папка или ссылка, удаляем их
                if [[ -e "$path" || -L "$path" ]]; then
                    _exec "Удаление конфликтующего объекта на месте файла $path" rm -rf "$path"
                fi
                _exec "Создание пустого файла $path" touch "$path" || return 1
            fi
            # Снимаем защиту, если она есть (только для файлов)
            if command -v chattr >/dev/null 2>&1; then
                # Используем || true, так как в DRY-RUN файла нет, и chattr на боевом запуске без DRY_RUN не должен падать
                _exec "Снятие защиты атрибутов с файла $path" chattr -i "$path" 2>/dev/null || true
            fi
            ;;
        link)
            [[ -z "$target_path" ]] && { log_error "Для типа link обязательно указание target_path (аргумент 5)"; return 1; }
            
            # Проверяем, существует ли уже ссылка и указывает ли она на нужный target
            if [[ -L "$path" ]]; then
                local current_target
                current_target=$(readlink "$path")
                if [[ "$current_target" != "$target_path" ]]; then
                    log_warn "Ссылка $path указывает на $current_target вместо $target_path. Пересоздаем..."
                    _exec "Удаление старой неверной ссылки $path" rm -f "$path"
                fi
            elif [[ -e "$path" ]]; then
                log_warn "На месте ссылки $path обнаружен обычный объект. Удаляем его..."
                _exec "Удаление конфликтующего объекта на месте ссылки $path" rm -rf "$path"
            fi

            # Создаем символическую ссылку (ln -sf)
            if [[ ! -L "$path" ]]; then
                if ! _exec "Создание символической ссылки $path -> $target_path" ln -sf "$target_path" "$path"; then
                    log_error "Ошибка создания symlink $path -> $target_path"
                fi
            fi
            ;;
        *)
            log_error "Неизвестный тип объекта: $type"
            return 1
            ;;
    esac

    # Перед chown гарантируем наличие субъектов (пользователей/групп)
    if ensure_owner_exists "$owner"; then
        if [[ "$type" == "link" ]]; then
            # Для ссылок используем флаг -h, чтобы сменить владельца самой ссылки, а не целевого файла
            if ! _exec "Смена владельца ссылки $path на $owner" chown -h "$owner" "$path"; then
                log_error "Ошибка chown -h $owner для ссылки: $path"
                return 1
            fi
        else
            if ! _exec "Смена владельца $path на $owner" chown "$owner" "$path"; then
                log_error "Ошибка chown $owner для: $path"
                return 1
        fi
    else
        log_error "Критическая ошибка: не удалось подготовить владельца $owner"
        return 1
    fi

    # Применение прав (для ссылок chmod обычно пропускают, так как они всегда 777, но делаем проверку)
    if [[ -n "$mode" && "$type" != "link" ]]; then
        if ! _exec "Установка прав доступа $mode для $path" chmod "$mode" "$path"; then
            log_error "Ошибка chmod $mode: $path"
            return 1
        fi
    fi
    
    log_debug "Объект готов: $path ($type, $owner, ${mode:-default})"}
    return 0
}

# Упрощенная обертка для директорий (Strict mode)
# Прерывает выполнение, если папку создать нельзя
ensure_dir_exists() {
    local dir_path="${1:-}"
    [[ -z "$dir_path" ]] && { log_error "Переменная dir_path пустая строка."; return 1; }
    # Вызываем через || return 1 вместо exit 1, чтобы сработал твой Rollback
    ensure_path_exists "$dir_path" "dir" || { log_error "Критическая ошибка доступа: $dir_path"; return 1; }
}

# Обертка для символических ссылок (Strict mode)
ensure_link_exists() {
    local link_path="${1:-}"   # Путь создаваемой ссылки (DEST_PATH)
    local target_path="${2:-}" # Путь к оригинальному файлу (TPL_NAME / TARGET)
    local owner="${3:-root:root}"

    [[ -z "$link_path" ]] && { log_error "Переменная link_path пустая строка."; return 1; }
    [[ -z "$target_path" ]] && { log_error "Переменная target_path пустая строка для ссылки $link_path."; return 1; }
    
    # Ссылки всегда создаются с системными правами 777, поэтому mode передаем пустым
    ensure_path_exists "$link_path" "link" "$owner" "" "$target_path" || { 
        log_error "Критическая ошибка создания символической ссылки: $link_path -> $target_path"
        return 1
    }
}
# Функция для генерации конфигов из шаблонов
# Использование: update_configs "путь/к/шаблону" "путь/к/цели" "MY_|AUTHOR|ROOT_DIR|LAST_MODIFIED"
update_configs() {
    local tpl_file="$1"   # Первый аргумент: файл-шаблон (.tpl)
    local dest_file="$2"  # Второй аргумент: куда сохранить результат
    local var_list="$3"   # Третий аргумент: список переменных для подстановки

    # Проверка существования шаблона
    if [[ ! -f "$tpl_file" ]]; then
        log_error "Шаблон не найден: $tpl_file"
        return 1
    fi

    # Проверка наличия переменных в списке
    if [[ -z "$var_list" ]]; then
        log_error "Список переменных для замены пуст"
        return 1
    fi

    # Подготовка списка переменных (только экспортированные и нужные нам)
    # Фильтруем по префиксам (например, MY_ или системные AUTHOR, ROOT_DIR)
    local vars_to_subst
    # vars_to_subst=$(printf '$%s ' $(env | cut -d= -f1 | grep -E "^($var_list)"))
    vars_to_subst=$(compgen -v | grep -E "^($var_list)" | sed 's/^/$/' | tr '\n' ' ')
    
    local target_dir
    target_dir=$(dirname "$dest_file")

    # Создание директории назначения, если её нет (например для ~/.ssh/config)
    if [[ ! -d "$target_dir" ]]; then
        if ! _exec "Создание директории назначения конфигурации" mkdir -p "$target_dir"; then
            log_error "Не удалось создать директорию: $target_dir"
            return 1
        fi
    fi
    
    # Вспомогательная локальная функция для безопасного проксирования envsubst со стримами
    _run_envsubst() {
        envsubst "$vars_to_subst" < "$tpl_file" > "$1"
    }

    local tmp_file="${dest_file}.tmp"

    # 4. Основной блок выполнения с защитой транзакции и DRY-RUN
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        # Имитируем весь процесс сборки и перемещения одной строкой для чистоты логов
        _exec "Генерация конфигурации $dest_file из шаблона $(basename "$tpl_file")" true
        log_warn "[DRY-RUN] Имитация успешной генерации файла: $dest_file"
        return 0
    fi

    # Физический боевой режим (выполняется только если DRY_RUN=false)
    # Запускаем сборку через прокси, передавая нашу локальную функцию
    if _exec "Компиляция шаблона через envsubst" _run_envsubst "$tmp_file"; then
        
        # Атомарно подменяем старый файл новым
        if _exec "Атомарное обновление конфигурационного файла" mv "$tmp_file" "$dest_file"; then
            log_ok "Конфигурационный файл успешно обновлен: $dest_file"
            return 0
        else
            log_error "Критический сбой mv при обновлении файла: $dest_file"
            _exec "Очистка временного файла после сбоя mv" rm -f "$tmp_file"
            return 1
        fi
    else
        log_error "Сбой компиляции envsubst для: $dest_file"
        _exec "Очистка временного файла после сбоя envsubst" rm -f "$tmp_file"
        return 1
    fi
}

# Функция для получения следующего серийного номера в формате YYYYMMDDNN
# Использование: SERIAL=$(get_next_serial "/path/to/zone/file")
get_next_serial() {
    local zone_file="${1:-}"
    local today=$(date +"%Y%m%d")
    local old_serial=""
    
    # Ищем 10 цифр, которые обычно помечены комментарием Serial
    if [[ -f "$zone_file" ]]; then
        old_serial=$(grep -iE '[0-9]{10}.*;.*serial' "$zone_file" | grep -oE '[0-9]{10}' | head -n1)
    fi

    # Если старый сериал найден и он сегодняшний
    if [[ -n "${old_serial:-}" && "$old_serial" == "$today"* ]]; then
        # 10# форсирует десятичную систему, игнорируя ведущие нули
        echo $((10#$old_serial + 1))
    else
        # Если день сменился или файла нет
        echo "${today}01"
    fi
}

# Функция-помощник для IPv6, которая выводит "красивый список" всех текущих аренд (IP + DUID) 
# из файла /var/lib/dhcp/dhcpd6.leases, чтобы было легче заполнять эти переменные
show_dhcp6_leases() {
    local lease_file="/var/lib/dhcp/dhcpd6.leases"

    if [[ ! -f "$lease_file" ]]; then
        log_error "Файл аренды IPv6 ($lease_file) не найден. Возможно, еще никто не подключался."
        return 1
    fi

    echo -e "\n\e[32m--- Список активных аренд DHCPv6 (IPv4) ---\e[0m"
    echo -e "IPv6 Address                | DUID"
    echo "---------------------------|--------------------------------------------------"

    # Парсим файл: ищем строки 'iaaddr' (IP) и 'client-id' (DUID)
    awk '
    /^iaaddr / { ip=$2 }
    /client-id/ { 
        gsub(/[";]/, "", $2); 
        # Конвертируем HEX-строку (если она в кавычках) в формат с двоеточиями
        print ip " | " $2 
    }' "$lease_file" | sort -u
    echo -e "------------------------------------------------------------------------------\n"
}

# Функция-помощник для IPv4, которая выводит "красивый список" всех текущих аренд (IP + DUID) 
# из файла /var/lib/dhcp/dhcpd.leases, чтобы было легче заполнять эти переменные
show_dhcp4_leases() {
    local lease_file="/var/lib/dhcp/dhcpd.leases"

    if [[ ! -f "$lease_file" ]]; then
        log_error "Файл аренды IPv4 ($lease_file) не найден."
        return 1
    fi

    echo -e "\n\e[34m--- Список активных аренд DHCPv4 (IPv4) ---\e[0m"
    printf "%-15s | %-17s | %-20s\n" "IP Address" "MAC Address" "Hostname"
    echo "----------------|-------------------|---------------------"

    # Парсим файл: ищем блоки lease, extract IP, MAC и client-hostname
    awk '
    /^lease / { ip=$2 }
    /hardware ethernet/ { mac=$3; gsub(/;/, "", mac) }
    /client-hostname/ { name=$2; gsub(/[";]/, "", name) }
    /^}/ { 
        if (ip != "") {
            printf "%-15s | %-17s | %-20s\n", ip, (mac ? mac : "unknown"), (name ? name : "n/a")
            ip=""; mac=""; name=""
        }
    }' "$lease_file" | sort -u -t'|' -k1,1
    echo -e "----------------------------------------------------------\n"
}

# Функция для генерации нибблов (полубайтов) IPv6 для зоны .ip6.arpa
# Аргумент 1: IPv6 адрес или префикс
# Аргумент 2: Режим (network или host)
# Аргумент 3: Длина префикса (например, 64)
ipv6_to_nibbles() {
    local ip="$1"
    local mode="$2"
    local prefix_len="$3"

    python3 -c "
import ipaddress
ip_str = '$ip'
try:
    # Приводим к полному виду (32 знака)
    addr = ipaddress.IPv6Address(ip_str.split('/')[0]).exploded.replace(':', '')
    # Инвертируем и разделяем точками
    nibbles = '.'.join(addr[::-1])
    
    # Вычисляем количество нибблов для сетевой и хостовой части
    # Каждый ниббл - это 4 бита
    net_nibbles = $prefix_len // 4
    
    if '$mode' == 'network':
        # Берем ПРАВУЮ часть (так как адрес уже инвертирован)
        print('.'.join(nibbles.split('.')[-net_nibbles:]))
    else:
        # Берем ЛЕВУЮ часть (хостовая часть)
        print('.'.join(nibbles.split('.')[:-net_nibbles]))
except:
    pass
"
}

# [.env]
# Формат: NAME:IP4:IP6 (через пробел)
# export EXTRA_HOSTS_DATA="gw:10.10.100.2:fc00:db9:aaaa::2 devsrv:10.10.100.3:fc00:db9:aaaa::3 srv1c:10.10.100.4:fc00:db9:aaaa::4"
generate_dns_blocks() {
    local forward="" rev4="" rev6=""
    
    # Берем данные из .env (NAME:IP4:IP6)
    for entry in $EXTRA_HOSTS_DATA; do
        local name=$(echo "$entry" | cut -d: -f1)
        local ip4=$(echo "$entry" | cut -d: -f2)
        local ip6=$(echo "$entry" | cut -d: -f3)

        # 1. Прямая зона
        forward+="${name}    IN    A       ${ip4}\n"
        forward+="${name}    IN    AAAA    ${ip6}\n"

        # 2. Реверс IPv4 (последний октет)
        rev4+="$(echo "$ip4" | cut -d. -f4)    IN    PTR    ${name}.${LOCAL_DOMAIN}.\n"

        # 3. Реверс IPv6 (инверсия хост-части)
        # Вызываем нашу функцию из utils.sh
        local nibbles_host=$(ipv6_to_nibbles "$ip6" "host" 64)
        rev6+="${nibbles_host}    IN    PTR    ${name}.${LOCAL_DOMAIN}.\n"
    done

    # Экспортируем для envsubst
    export DNS_FORWARD_BLOCK=$(printf "$forward")
    export DNS_REV4_BLOCK=$(printf "$rev4")
    export DNS_REV6_BLOCK=$(printf "$rev6")
}

generate_ipv6_pool() {
    local pool=""
    # Диапазон от 100 до 1FF (в десятичной это 256-511)
    for i in $(seq 256 511); do
        # Переводим число в hex (4 знака) и инвертируем с точками
        # 0x1a2 -> 2.a.1.0
        local hex=$(printf "%04x" $i)
        local nibbles=$(echo "$hex" | sed 's/./&./g' | rev | cut -c 2-)
        
        # Добавляем оставшиеся нули до 16 нибблов (для префикса /64)
        pool+="${nibbles}.0.0.0.0.0.0.0.0.0.0.0.0    IN    PTR    host-${hex}.${LOCAL_DOMAIN}.\n"
    done
    export DNS_REV6_POOL=$(printf "$pool")
}