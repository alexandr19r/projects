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