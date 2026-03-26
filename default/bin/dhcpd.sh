#!/bin/bash
# [dhcpd.sh] - Развертывание сервера dhcpd (ISC-DHCP-SERVER + RADVD)

# Инициализация переменных
PROJECT_NAME="isc-dhcp-server"
PACKAGES="isc-dhcp-server radvd rsyslog"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# см. [dhcp.env]

# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

DHCP_CONFIG_MAP=(
    "system/rsyslog_dhcp|/etc/rsyslog.d/dhcpd.conf|Настройка логов DHCP (local7)|\
AUTHOR|LAST_MODIFIED"
    "system/logrotate_dhcp|/etc/logrotate.d/dhcpd|Ротация логов DHCP|\
AUTHOR|LAST_MODIFIED"
    "network/radvd.conf|/etc/radvd.conf|Анонсы IPv6|\
AUTHOR|LAST_MODIFIED|DHCP_INTERFACE|YOUR_NETWORK_IPV6"
    "dhcp/isc-dhcp-server|/etc/default/isc-dhcp-server|Интерфейсы DHCP|\
AUTHOR|LAST_MODIFIED|DHCP_INTERFACE"
    "dhcp/dhcpd.conf|/etc/dhcp/dhcpd.conf|Конфиг DHCPv4|\
AUTHOR|LAST_MODIFIED|YOUR_SERVER_IP|GOOGLE_DNS|YOUR_DOMAIN|YOUR_NETWORK_ADDR|YOUR_NETMASK|YOUR_BROADCAST|\
YOUR_GATEWAY|DHCP_RANGE_START|DHCP_RANGE_END|GW_MAC|GW_IP|DEVSRV_MAC|DEVSRV_IP|SRV1C_MAC|SRV1C_IP"
    "dhcp/dhcpd6.conf|/etc/dhcp/dhcpd6.conf|Конфиг DHCPv6|\
AUTHOR|LAST_MODIFIED|YOUR_SERVER_IPV6|YOUR_DOMAIN|YOUR_NETWORK_IPV6|DHCP6_RANGE_START|DHCP6_RANGE_END|\
GW_DUID|GW_IPV6|DEVSRV_DUID|DEVSRV_IPV6"
)

main_dhcpd() {
    
    log_info ">>> НАЧАЛО РАЗВЕРТЫВАНИЯ СЛУЖБ DHCP (IPv4/IPv6) <<<"

    # Проверка прав и зависимостей
    log_info "--- Проверка наличия прав root ---"
    check_root || return 1

    # Загружаем переменные окружения
    log_info "--- Загрузка переменных из настроек приложения ---"
    load_env "${ROOT_DIR}/config/dhcp/dhcp.env"

    # Проверка и автоматическое определение интерфейса
    log_info "--- Проверка и автоматическое определение интерфейса ---"
    if [[ -z "$DHCP_INTERFACE" ]]; then
        export DHCP_INTERFACE=$(ip -4 route ls | grep default | awk '{print $5}' | head -n1)
        log_warn "DHCP_INTERFACE не задан. Авто-определение: $DHCP_INTERFACE"
    fi

    # Установка пакета
    log_info "--- Установка DCHP сервера (isc-dhcp-server) и зависимостей ---"
    install_list "${PACKAGES}" || return 1

    # Запуск начала транзакции
    begin_transaction
    
    # Инициализируем модуль бэкапа (создаем временные папки)
    init_backup
    
    # Загрузка списка инфраструктуры dhcp
    local dhcp_list
    dhcp_list="${ROOT_DIR}/config/dhcp/dhcp.list"

    # Поверяем корректность загрузки списка инфраструктуры dhcp
    if [[ !-f "$dhcp_list" ]]; then
        log_warn "Реестр $dhcp_list не найден, бэкап конфигураций пропущен."
        return 1
    fi

    # Читаем только строки с типом 'file', извлекаем путь (3-я колонка)
    # Добавляем в бэкап все файлы, которые прописаны в массиве как цели (dest_path)
    local files_to_back
    files_to_back=$(grep -vE '^(#|$)' "$dhcp_list" | awk '$1 == "file" {print $3}')

    log_info "--- Создаем backup версию ---"
    for file_path in $files_to_back; do
        if [[ -f "$file_path" ]]; then
            log_debug "Добавление в бэкап: $file_path"
            add_to_staging "$file_path"
        fi
    done

    
    # Читаем реестр и вызываем add_item для каждой строки
    log_info "--- Настройка инфраструктуры Firewall (nftables) ---"
    grep -vE '^(#|$)' "$dhcp_list" | while read -r type tpl dest mode owner dep attr desc vars; do
        if ! add_item "$type" "$tpl" "$dest" "$mode" "$owner" "$dep" "$attr" "$desc" "$vars"; then
            log_error "Сбой при настройке: $desc"
            rollback_transaction
            return 1
        fi
    done || return 1 # Выход из main если цикл вернул ошибку
    

    # Перезапуск и проверка служб
    log_info "--- Перезапуск служб ---"
    local services=("rsyslog" "radvd" "isc-dhcp-server")
    
    for svc in "${services[@]}"; do
        systemctl restart "$svc"
        systemctl enable "$svc"
        if systemctl is-active --quiet "$svc"; then
            log_info "[OK] Служба $svc запущена."
        else
            log_error "Ошибка запуска $svc. Проверь journalctl -u $svc"
        fi
    done

    log_info "====================================================="
    log_info "Настройка DHCP-сервера завершена. Проверьте вывод выше."
    log_info "====================================================="

}

main_dhcpd "$@"