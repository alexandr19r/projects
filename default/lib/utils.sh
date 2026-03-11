#!/bin/bash
# [utils.sh] - Профессиональный инструментарий хелперов v2026.1

[[ -n "${_UTILS_SH_}" ]] && return
readonly _UTILS_SH_=1

# --- СИСТЕМНЫЕ ПРОВЕРКИ ---

# Проверка наличия прав (root)
# Просто возвращает true/false, ничего не прерывая
is_root() {
    [[ $EUID -eq 0 ]]
}

check_root() {
    if ! is_root; then
        # Мы используем функцию логгера, так как utils загружается после core
        log_error "Эта операция требует прав суперпользователя (root)."
        exit 1
    fi
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

# Универсальная функция для подготовки путей
# Использование: ensure_path_exists "/путь/к/объекту" "тип(dir|file)" "владелец" "права"
# Пример: ensure_path_exists "/etc/bind/zones" "dir" "root:bind" "750" или "2750", префикс 2 -  SGID (g+s)
ensure_path_exists() {
    local path="$1"
    local type="$2"      # dir или file
    local owner="${3:-root:root}" # по умолчанию root
    local mode="$4"      # права (опционально)

    # 1. Создание объекта, если его нет
    if [[ "$type" == "dir" && ! -d "$path" ]]; then
        log_info "Создание директории: $path"
        mkdir -p "$path" || { log_error "Не удалось создать директорию $path"; return 1; }
    elif [[ "$type" == "file" && ! -f "$path" ]]; then
        log_info "Создание файла: $path"
        # Сначала убедимся, что родительская папка есть (рекурсия)
        ensure_path_exists "$(dirname "$path")" "dir" "$owner" "755"
        touch "$path" || { log_error "Не удалось создать файл $path"; return 1; }
    else
        log_info "Объект уже существует: $path"
        return 0 # Объект уже существует, выходим тихо
    fi

    # 2. Установка владельца и прав (только если объект был создан или изменен)
    chown "$owner" "$path"
    [[ -n "$mode" ]] && chmod "$mode" "$path"
    
    log_debug "Настроены права для $path ($owner, ${mode:-default})"
    return 0
}

# Функция проверяет существование папки и создает при необходимости
# В случае ошибки прерывает выполнение
ensure_dir_exists() {
  local dir_path="$1"
  
  # -p уже проверяет существование, поэтому if [[ ! -d ]] не обязателен
  if mkdir -p "$dir_path" 2>/dev/null; then
    # Выводим сообщение только если папка реально была создана (опционально)
    log_debug "Директория готова: $dir_path"
    return 0
  else
    # Сигнализируем об ошибке, но не убиваем весь скрипт
    log_error "Ошибка прав доступа к '$dir_path'" >&2
    return 1
  fi
}

# Функция для генерации конфигов из шаблонов
# Использование: update_configs "путь/к/шаблону" "путь/к/цели" "MY_|AUTHOR|ROOT_DIR|LAST_MODIFIED"
update_configs() {
    local tpl_file="$1"   # Первый аргумент: файл-шаблон (.tpl)
    local dest_file="$2"  # Второй аргумент: куда сохранить результат
    local var_list="$3"   # Третий аргумент: список переменных для подстановки

    # 1. Проверка существования шаблона
    if [[ ! -f "$tpl_file" ]]; then
        log_error "Шаблон не найден: $tpl_file"
        return 1
    fi

    # Проверка наличия переменных в списке
    if [[ -z "$var_list" ]]; then
        log_error "Список переменных для замены пуст"
        return 1
    fi

    # 2. Подготовка списка переменных (только экспортированные и нужные нам)
    # Фильтруем по префиксам (например, MY_ или системные AUTHOR, ROOT_DIR)
    local vars_to_subst
    vars_to_subst=$(printf '$%s ' $(env | cut -d= -f1 | grep -E "^($var_list)"))

    # 3. Создание директории назначения, если её нет (например для ~/.ssh/config)
    mkdir -p "$(dirname "$dest_file")"

    # 4. Основная магия envsubst
    if envsubst "$vars_to_subst" < "$tpl_file" > "$dest_file"; then
        echo "[SUCCESS] Файл обновлен: $dest_file"
    else
        log_error "Ошибка при генерации: $dest_file"
        return 1
    fi
}

# Функция для получения следующего серийного номера в формате YYYYMMDDNN
# Использование: SERIAL=$(get_next_serial "/path/to/zone/file")
get_next_serial() {
    local zone_file="$1"
    local today=$(date +"%Y%m%d")
    local new_serial

    # 1. Проверяем, существует ли файл и есть ли в нем 10-значное число (Serial)
    if [[ -f "$zone_file" ]]; then
        local old_serial=$(grep -oE '[0-9]{10}' "$zone_file" | head -n1)
        
        # 2. Если старый сериал совпадает с сегодняшней датой (начало строки)
        if [[ "$old_serial" == "$today"* ]]; then
            # Увеличиваем число на 1 (например, 2024052001 -> 2024052002)
            new_serial=$((old_serial + 1))
        else
            # Если день сменился, начинаем с 01
            new_serial="${today}01"
        fi
    else
        # 3. Если файла нет, создаем первый сериал для текущего дня
        new_serial="${today}01"
    fi

    echo "$new_serial"
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