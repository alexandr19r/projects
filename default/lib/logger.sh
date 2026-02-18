#!/bin/bash
# [logger.sh] - Модуль профессионального логирования

[[ -n "${_LOGGER_SH_}" ]] && return 0
readonly _LOGGER_SH_=1

# Пред-инициализация конфигурации
LOG_TO_CONSOLE=true

# Цвета
readonly C_RES='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GRE='\033[0;32m'
readonly C_YEL='\033[0;33m'
readonly C_BLU='\033[0;34m'
readonly C_MAG='\033[0;35m'

# Инициализация конфигурации по умолчанию (если не определено)
init_logger() {
    PROJECT_NAME="${PROJECT_NAME:-default_project}"
    LOG_TO_CONSOLE="${LOG_TO_CONSOLE:-true}"
    LOG_TO_FILE="${LOG_TO_FILE:-false}"
    LOG_FILE="${LOG_FILE:-${ROOT_DIR}/var/log/${PROJECT_NAME}.log}"
    DEBUG_MODE="${DEBUG_MODE:-false}"
}

_log_base() {
    local level=$1; local color=$2; local message=$3
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local formatted_msg="[$timestamp] [$level] $message"

    # Вывод в консоль (с цветами)
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        echo -e "${color}${formatted_msg}${C_RES}" >&2
    fi

    # Вывод в файл (без цветов)
    if [[ "$LOG_TO_FILE" == "true" ]]; then
        echo "$formatted_msg" >> "$LOG_FILE"
    fi
}

log_info()  { _log_base "INFO"  "$C_BLU" "$1"; }
log_ok()    { _log_base "OK"    "$C_GRE" "$1"; }
log_warn()  { _log_base "WARN"  "$C_YEL" "$1"; }
log_error() { _log_base "ERROR" "$C_RED" "$1"; }
log_debug() { [[ "$DEBUG_MODE" == "true" ]] && _log_base "DEBUG" "$C_MAG" "$1"; }
