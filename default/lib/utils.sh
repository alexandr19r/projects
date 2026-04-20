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

# Универсальный конструктор путей
# Аргументы: path, type(dir|file), owner(user:group), mode(octal)
ensure_path_exists() {
    local path="${1:-}" 
    local type="${2:-dir}" 
    local owner="${3:-root:root}" 
    local mode="${4:-}"

    [[ -z "$path" ]] && { log_error "Переменная path пустая строка."; return 1; }

    # Создание объекта
    if [[ "$type" == "dir" ]]; then
        # Если это директория
        if [[ ! -d "$path" ]]; then
            mkdir -p "$path" || { log_error "Ошибка mkdir: $path"; return 1; }
        fi
    else
        # Создаем родительскую директорию, если её нет
        local parent_dir
        parent_dir=$(dirname "$path")

        # Создаем родительскую папку, если её нет
        if [[ ! -d "$parent_dir" ]]; then
            mkdir -p "$parent_dir" || { log_error "Ошибка mkdir для родительской папки: $parent_dir"; return 1; }
        fi
        
        # Создаем сам файл (touch), если его нет
        if [[ ! -f "$path" ]]; then
            touch "$path" || { log_error "Ошибка touch для файла: $path"; return 1; }
        fi
    fi

    # Применение владельца
    # Используем || true, чтобы ошибка chown не прерывала скрипт (если это критично, убери)
    chown "$owner" "$path" 2>/dev/null || log_warn "Не удалось сменить владельца на $owner для $path"

    #  Применение прав
    if [[ -n "$mode" ]]; then
        chmod "$mode" "$path" || { log_error "Ошибка chmod $mode: $path"; return 1; }
    fi
    
    log_debug "Объект готов: $path ($type, $owner, ${mode:-default})"}
}

# Упрощенная обертка для директорий (Strict mode)
# Прерывает выполнение, если папку создать нельзя
ensure_dir_exists() {
    local dir_path="${1:-}"
    [[ -z "$dir_path" ]] && { log_error "Переменная dir_path пустая строка."; return 1; }
    # Вызываем через || return 1 вместо exit 1, чтобы сработал твой Rollback
    ensure_path_exists "$dir_path" "dir" || { log_error "Критическая ошибка доступа: $dir_path"; return 1; }
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

    # Создание директории назначения, если её нет (например для ~/.ssh/config)
    mkdir -p "$(dirname "$dest_file")"

    # Генерация через временный файл (атомарность)
    local tmp_file="${dest_file}.tmp"
    if envsubst "$vars_to_subst" < "$tpl_file" > "$tmp_file"; then
        mv "$tmp_file" "$dest_file"
        log_ok "Конфиг обновлен: $dest_file"
    else
        rm -f "$tmp_file"
        log_error "Сбой envsubst для: $dest_file"
        return 1
    fi
}

# Функция для получения следующего серийного номера в формате YYYYMMDDNN
# Использование: SERIAL=$(get_next_serial "/path/to/zone/file")
get_next_serial() {
    local zone_file="$1"
    local today=$(date +"%Y%m%d")
    local old_serial
    
    # Ищем 10 цифр, которые обычно помечены комментарием Serial
    if [[ -f "$zone_file" ]]; then
        old_serial=$(grep -iE '[0-9]{10}.*;.*serial' "$zone_file" | grep -oE '[0-9]{10}' | head -n1)
    fi

    # Если старый сериал найден и он сегодняшний
    if [[ -n "$old_serial" && "$old_serial" == "$today"* ]]; then
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