#!/bin/bash

#Файл logger.sh

# Цветовые коды для терминала
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (сброс)

# Файл лога (путь можно брать из конфига)
LOG_FILE="${LOG_FILE:-script.log}"

# Функция для вывода лога
# Использование: log_msg "INFO" "Сообщение"
log_msg() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local color=""

    case "$level" in
        "INFO")    color="$GREEN" ;;
        "WARN")    color="$YELLOW" ;;
        "ERROR")   color="$RED" ;;
        "DEBUG")   color="$BLUE" ;;
        *)         color="$NC" ;;
    esac

    # Форматированный вывод в терминал
    printf "${BLUE}[%s]${NC} ${color}[%-5s]${NC} %s\n" "$timestamp" "$level" "$message"

    # Запись в файл без цветовых кодов (чистый текст)
    printf "[%s] [%-5s] %s\n" "$timestamp" "$level" "$message" >> "$LOG_FILE"
}

# Обертки для удобства
log_info()  { log_msg "INFO"  "$1"; }
log_warn()  { log_msg "WARN"  "$1"; }
log_error() { log_msg "ERROR" "$1"; }
log_debug() { [[ "$DEBUG" == "true" ]] && log_msg "DEBUG" "$1"; }

