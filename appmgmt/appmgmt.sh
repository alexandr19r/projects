#!/bin/bash
# /opt/netmgmt/netmgmt.sh

# Импорт настроек и ядра
# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

# Валидация аргументов
if [ "$#" -lt 2 ]; then
    log_error "Использование: $0 <app_name> <action> [arguments]"
    log_error "Доступные приложения: bind, isc-dhcp-server, nftables"
    log_error "Доступные действия: install, uninstall, update" #, update-config, backup"
    exit 1
fi

APP_NAME="$1"
ACTION="$2"
shift 2 # Смещаем аргументы, чтобы передать остаток в модуль

# Динамическое подключение модуля приложения
import_module "$APP_NAME"

# 4. Вызов функции из модуля (каждый модуль обязан иметь функции вида app_action)
FUNC_NAME="${APP_NAME}_${ACTION}"
if declare -f "$FUNC_NAME" > /dev/null; then
    $FUNC_NAME "$@"
else
    log_error "Действие '$ACTION' не поддерживается модулем '$APP_NAME' (Функция $FUNC_NAME не найдена)"
    exit 1
fi