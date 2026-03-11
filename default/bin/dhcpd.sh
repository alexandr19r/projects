#!/bin/bash
# [dhcpd.sh] файл установки редактора dhcpd

# Инициализация переменных
PROJECT_NAME="isc-dhcp-server"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
export DHCP_INTERFACE="eth0"
export YOUR_DOMAIN="home.local"         # Ваш локальный домен (например, corp.local)
# --- Переменные IPv4 ---
export YOUR_SERVER_IP="10.10.100.1"     # IP-адрес вашего сервера
export YOUR_NETWORK_ADDR="10.10.100.0"
export YOUR_BROADCAST="${YOUR_NETWORK_ADDR%.*}.255"
export YOUR_NETMASK="255.255.255.0"
export YOUR_GATEWAY="10.10.100.2"
export DHCP_RANGE_START="10.10.100.100"
export DHCP_RANGE_END="10.10.100.200"
export GOOGLE_DNS="8.8.8.8"
# --- Настройки серверов сети ---
export GW_MAC="00:15:5D:00:03:04"
export GW_IP="10.10.100.2"
export DEVSRV_MAC="00:15:5D:00:6A:02"
export DEVSRV_IP="10.10.100.3"
export SRV1C_MAC="00:15:5D:00:6A:03"
export SRV1C_IP="10.10.100.4"
# --- Переменные IPv6 ---
export YOUR_SERVER_IPV6="fd00:db9:aaaa::1"
export YOUR_NETWORK_IPV6="fd00:db9:aaaa::/64"
export YOUR_GATEWAY_IPV6="fd00:db9:aaaa::2"
export DHCP6_RANGE_START="fd00:db9:aaaa::100"
export DHCP6_RANGE_END="fd00:db9:aaaa::200"
# --- Настройки серверов сети ---
export GW_DUID="00:01:00:01:2B:4C:09:F1:34:6F:24:6B:C1:95"
export GW_IPV6="fd00:db9:aaaa::2"
export DEVSRV_DUID="00:01:00:01:2A:E1:6D:49:00:15:5D:00:6A:02"
export DEVSRV_IPV6="fd00:db9:aaaa::3"
export SRV1C_DUID="00:01:00:01:2A:99:15:B6:00:15:5D:00:67:00"
export SRV1C_IPV6="fd00:db9:aaaa::4"
# --- Данные модификации файлов ---
export AUTHOR=$(id -un) #Имя текущего пользователя системы
export LAST_MODIFIED=$(date '+%Y-%m-%d') #Текущая дата изменения

# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

enable_ipv6_forwarding() {
    log_info "--- Включение пересылки (Forwarding) IPv6 в ядре ---"

    # 1. Мгновенная активация
    sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null

    # 2. Сохранение после перезагрузки
    local sysctl_file="/etc/sysctl.d/99-ipv6-forwarding.conf"
    echo "net.ipv6.conf.all.forwarding=1" > "$sysctl_file"
    
    # Применяем настройки из всех файлов sysctl
    sysctl -p "$sysctl_file" > /dev/null
}

setup_ipv6_gateway() {
    # Переменная YOUR_GATEWAY_IPV6 должна быть экспортирована (например, fc00:db9:aaaa::2)
    local ext_gw="${YOUR_GATEWAY_IPV6}"
    local iface="${DHCP_INTERFACE}"

    log_info "--- Настройка маршрута по умолчанию через $ext_gw ---"

    if [[ -z "$ext_gw" ]]; then
        log_error "Переменная YOUR_GATEWAY_IPV6 не задана. Роутинг не настроен."
        return 1
    fi

    # Устанавливаем маршрут по умолчанию (удаляем старый, ставим новый)
    ip -6 route del default dev "$iface" 2>/dev/null
    ip -6 route add default via "$ext_gw" dev "$iface"

    # Настройка NAT66 (Masquerade), чтобы клиенты могли выходить в интернет
    if command -v ip6tables >/dev/null; then
        log_info "Включение NAT66 (Masquerade) через ip6tables..."
        # Очищаем старое правило, чтобы не дублировать
        ip6tables -t nat -D POSTROUTING -o "$iface" -j MASQUERADE 2>/dev/null
        # Добавляем актуальное
        ip6tables -t nat -A POSTROUTING -o "$iface" -j MASQUERADE
    else
        log_warn "Утилита ip6tables не найдена. NAT66 не настроен."
    fi
}

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
    
    log_info "--- НАЧАЛО РАЗВЕРТЫВАНИЯ СЛУЖБ DHCP (IPv4/IPv6) <<<"

    log_info "--- Проверка наличия прав root ---"
    check_root || return 1

    # Установка необходимых пакетов
    log_info "--- Установка ПО ---"
    install_list "${PROJECT_NAME} radvd rsyslog" || return 1

    # Подготовка системы (DNS и Роутинг)
    enable_ipv6_forwarding      # Включаем форвардинг для radvd
    setup_ipv6_gateway          # Настраиваем роутинг на внешний шлюз
    
    # Создаем backup настроек
    log_info "--- Создаем backup версию ---"
    
    # Добавляем папку в backup
    add_to_staging "/etc/default/isc-dhcp-server"
    add_to_staging "/etc/dhcp/"
    add_to_staging "/etc/radvd.conf"
    add_to_staging "/etc/rsyslog.d/dhcpd.conf"
    add_to_staging "/etc/logrotate.d/dhcpd"
    # Финализируем процесс
    finalize_backup

    # Создание структуры (только один раз)
    log_info "--- Создаем все необходимые каталоги ---"

    # Создаем папку для логов DHCP
    # Владелец: root (или syslog), группа: adm, права: 750
    ensure_path_exists "/var/log/dhcp" "dir" "syslog:adm" "750"
    # Создаем сам файл лога
    # Владелец: syslog (т.к. пишет rsyslog), группа: adm, права: 640
    ensure_path_exists "/var/log/dhcp/dhcpd.log" "file" "syslog:adm" "640"

    # Цикл генерации конфигураций
    log_info "--- Генерация конфигурационных файлов ---"
    for entry in "${DHCP_CONFIG_MAP[@]}"; do
        # Разбираем строку: tpl (1), dest (2), desc (3), а остальное (vars) идет в 'rest'
        IFS='|' read -r tpl_name dest_path description vars_list <<< "$entry"

        # Если переменных много, мы берем всё, что идет после 3-го разделителя
        # Это позволяет писать "VAR1|VAR2|VAR3" без ограничений
        local target_vars=$(echo "$entry" | cut -d'|' -f4-)
        
        # Снимаем блокировку (для resolv.conf)
        [ -f "$dest_path" ] && chattr -i "$dest_path" 2>/dev/null
        
        log_info "Применяю: $description -> $dest_path"
        update_configs "${ROOT_DIR}/template/${tpl_name}.tpl" "$dest_path" "$target_vars"
        
        # Установка прав
        if [[ "$dest_path" == "/etc/dhcp/"* ]]; then
            chown root:root "$dest_path" && chmod 644 "$dest_path"
        elif [[ "$dest_path" == "/etc/resolv.conf" ]]; then
            chown root:root "$dest_path" && chmod 644 "$dest_path"
            chattr +i "$dest_path" 2>/dev/null
        fi
    done

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