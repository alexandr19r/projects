#!/bin/bash
# [logger.sh] - Модуль профессионального логирования

[[ -n "${_LOGGER_SH_}" ]] && return 0
readonly _LOGGER_SH_=1

# Пред-инициализация конфигурации
# Устанавливаем дефолт ТОЛЬКО если переменная не была задана ранее
: "${PROJECT_NAME:=default}"

: "${LOG_TO_CONSOLE:=true}" 
: "${DEBUG_MODE:=false}"
: "${LOG_TO_FILE:=false}"

# Цвета
readonly C_RES='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GRE='\033[0;32m'
readonly C_YEL='\033[0;33m'
readonly C_BLU='\033[0;34m'
readonly C_MAG='\033[0;35m'

# Инициализация конфигурации по умолчанию (если не определено)
init_logger() {
    # Формируем финальный путь к логу, если он не был жестко задан в конфиге
    LOG_FILE="${LOG_FILE:-${ROOT_DIR}/var/log/${PROJECT_NAME}.log}"
    
    # Подготовка файловой системы
    if [[ "$LOG_TO_FILE" == "true" ]]; then
        # Создаем дерево директорий
        if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then
            echo -e "\e[31m[ERROR] Ошибка прав: невозможно создать путь для лога $LOG_FILE\e[0m" >&2
            LOG_TO_FILE=false
            return 1
        fi
        
        # Проверяем возможность записи в сам файл (touch)
        if ! touch "$LOG_FILE" 2>/dev/null; then
            echo -e "\e[31m[ERROR] Нет прав на запись в файл лога: $LOG_FILE\e[0m" >&2
            LOG_TO_FILE=false
            return 1
        fi
    fi
}

_log_base() {
    local level=$1; local color=$2; local message=$3
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local formatted_msg="[$timestamp] [$level] $message"

    # Вывод в консоль (с цветами)
    # Вывод в STDERR (стандарт для логов), чтобы не мешать выводу данных в STDOUT
   if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${color}${formatted_msg}${C_RES}" >&2
    fi

    # Вывод в файл (без цветов)
    if [[ "$LOG_TO_FILE" == "true" ]]; then
        # Используем printf или следим, чтобы в сообщении не было спецсимволов
        # echo "$formatted_msg" >> "$LOG_FILE"
        printf "%s\n" "$formatted_msg" >> "$LOG_FILE" 2>/dev/null
    fi
}

log_info()  { _log_base "INFO"  "$C_BLU" "$1"; }
log_ok()    { _log_base "OK"    "$C_GRE" "$1"; }
log_warn()  { _log_base "WARN"  "$C_YEL" "$1"; }
log_error() { _log_base "ERROR" "$C_RED" "$1"; }
log_debug() { [[ "$DEBUG_MODE" == "true" ]] && _log_base "DEBUG" "$C_MAG" "$1"; }
