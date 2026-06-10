#!/bin/bash
# [pgsql.sh] - Развертывание базы данных Postgre SQL

# Инициализация переменных проекта
PROJECT_NAME="postgresql"
PACKAGES="postgresql postgresql-contrib"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# см. [nftables.env]

# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

main_pgsql() {
    
    log_info ">>> НАЧАЛО РАЗВЕРТЫВАНИЯ DATABASE (Postgre SQL)  <<<-"

}

main_pgsql "$@"