#!/bin/bash
# [utils.sh] - Профессиональный инструментарий хелперов v2026.1

[[ -n "${_UTILS_SH_}" ]] && return
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
    local path="$1" type="${2:-dir}" owner="${3:-root:root}" mode="$4"

    # Создание объекта
    if [[ "$type" == "dir" ]]; then
        mkdir -p "$path" || { log_error "Ошибка mkdir: $path"; return 1; }
    else
        # Создаем родительскую директорию без рекурсии через mkdir -p
        mkdir -p "$(dirname "$path")" && touch "$path" || { log_error "Ошибка touch: $path"; return 1; }
    fi

    # Применение владельца и прав (всегда, для гарантии консистентности)
    chown "$owner" "$path"
    [[ -n "$mode" ]] && chmod "$mode" "$path"
    
    log_debug "Путь готов: $path ($type, $owner, ${mode:-default})"
}

# Упрощенная обертка для директорий (Strict mode)
# Прерывает выполнение, если папку создать нельзя
ensure_dir_exists() {
    local dir_path="$1"
    ensure_path_exists "$dir_path" "dir" || { log_error "Критическая ошибка доступа: $dir_path"; exit 1; }
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
