#!/bin/bash 
# [dhcpd.sh] - Развертывание сервера dhcpd (ISC-DHCP-SERVER + RADVD)

# Инициализация переменных
PROJECT_NAME="dhcp"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# см. [dhcp.env]

# Определение глобальных параметров "класса" NFTables
DHCP_PACKAGES="isc-dhcp-server radvd"
DHCP_SERVICES=("isc-dhcp-server radvd")
DHCP_LIST="${ROOT_DIR}/apps.d/dhcp/config/dhcp.list"

# Кастомный метод очистки портов
dhcp_pre_clean() {
    log_info "Жесткая очистка процессов dhcpd..."
    log_info "Остановка процессов dhcpd..."
    { sudo systemctl stop isc-dhcp-server 2>&1 || true; } | log_debug
    log_info "Удаление из автозапуска процессов dhcpd..."
    { sudo systemctl disable  isc-dhcp-server 2>&1 || true; } | log_debug
    log_info "Удаление из памяти процессов dhcpd..."
    { sudo pkill -9 dhcpd 2>&1 || true; } | log_debug
    log_info "Удаление файлов процессов..."
    sudo rm -fv /var/run/dhcpd/dhcpd.pid
    sudo rm -fv /var/run/dhcpd/dhcpd6.pid
    sudo rm -rfv /run/dhcp-server
    sleep 2
}

# Кастомный полиморфный метод валидации
dhcp_validate() {
    local HAS_ERROR=false
    
    # 1. Проверка DHCPv4
    log_info "Валидация DHCPv4..."
    if ! dhcpd -t -cf "/etc/dhcp/dhcpd.conf" >/dev/null 2>&1; then
        log_error "Синтаксическая ошибка в /etc/dhcp/dhcpd.conf"
        { dhcpd -t -cf "/etc/dhcp/dhcpd.conf" 2>&1 || true; } | log_debug
        HAS_ERROR=true
    fi

    # 2. Проверка DHCPv6
    log_info "Валидация DHCPv6..."
    if ! dhcpd -6 -t -cf "/etc/dhcp/dhcpd6.conf" >/dev/null 2>&1; then
        log_error "Синтаксическая ошибка в /etc/dhcp/dhcpd6.conf"
        { dhcpd -6 -t -cf "/etc/dhcp/dhcpd6.conf" 2>&1 || true; } | log_debug
        HAS_ERROR=true
    fi

    # 3. Проверка RADVD
    log_info "Валидация RADVD..."
    if ! radvd -c -C "/etc/radvd.conf" >/dev/null 2>&1; then
        log_error "Синтаксическая ошибка в /etc/radvd.conf"
        { radvd -c -C "/etc/radvd.conf" 2>&1 || true; } | log_debug
        HAS_ERROR=true
    fi

    if [[ "$HAS_ERROR" == "true" ]]; then
        return 1
    fi
}

# --- ООП МЕТОДЫ ИНТЕРФЕЙСА ---

dhcp_install() {
    load_env "$PROJECT_NAME"
    deploy_install "dhcp" "${DHCP_PACKAGES}" "${DHCP_LIST}" DHCP_SERVICES "dhcp_pre_clean"
}

# Доработать
dhcp_backup() {
    load_env "$PROJECT_NAME"
    deploy_backup "dhcp" "/etc/nftables.conf"
}

# Доработать
dhcp_update_config() {
    local source_file="${1:?Не указан путь к новому файлу настроек}"
    load_env "$PROJECT_NAME"
    deploy_update_config "dhcp" "/etc/nftables.conf" "$source_file" DHCP_SERVICES
}

dhcp_update_app() {
    load_env "$PROJECT_NAME"
    deploy_update_app "dhcp" "${DHCP_PACKAGES}" "${DHCP_LIST}" DHCP_SERVICES
}

dhcp_uninstall() {
    load_env "$PROJECT_NAME"
    deploy_uninstall "dhcp" "${DHCP_PACKAGES}" "${DHCP_LIST}"
}
