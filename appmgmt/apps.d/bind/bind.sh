#!/bin/bash
# [bind.sh] - Развертывание сервера DNS (BIND9)

# Инициализация переменных
PROJECT_NAME="bind"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# см. [bind.env]

# Определение глобальных параметров "класса" BIND9
BIND_PACKAGES="bind9 dnsutils"
BIND_SERVICES=("bind9")
BIND_LIST="${ROOT_DIR}/apps.d/bind/config/bind.list"

# Кастомный метод очистки портов
bind_pre_clean() {
    log_info "--- Отключение системных менеджеров DNS ---"

    # 1. Останавливаем и маскируем systemd-resolved (самый частый виновник)
    if systemctl is-active --quiet systemd-resolved; then
        log_info "Остановка systemd-resolved..."
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        systemctl mask systemd-resolved # Маскировка защищает от случайного запуска
    fi

    # 2. Удаляем пакет resolvconf, если он установлен
    if dpkg -l | grep -q "^ii  resolvconf"; then
        log_info "Удаление пакета resolvconf..."
        apt-get purge -y resolvconf
    fi

    # 3. Если используется NetworkManager, запрещаем ему трогать resolv.conf
    if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
        log_info "Настройка NetworkManager: main.dns=none"
        sed -i '/\[main\]/a dns=none' /etc/NetworkManager/NetworkManager.conf
        systemctl reload NetworkManager 2>/dev/null
    fi

    # 4. Удаляем символическую ссылку (если resolv.conf указывает на /run/...)
    # Это критично: часто /etc/resolv.conf — это просто ссылка
    if [ -L /etc/resolv.conf ]; then
        log_info "Удаление символической ссылки /etc/resolv.conf"
        rm /etc/resolv.conf
    fi
}

# Кастомный полиморфный метод валидации
bind_validate() {
    local HAS_ERROR=false

    # Общая проверка синтаксиса всех конфигов
    if ! named-checkconf /etc/bind/named.conf >/dev/null 2>&1; then
        log_error "Критическая ошибка в структуре named.conf или include-файлах"
        named-checkconf /etc/bind/named.conf 2>&1 | log_debug
        HAS_ERROR=true
    fi

    # Проверка системных зон (internal)
    log_info "Проверка системных зон (internal)..."
    
    # Проверка зоны root hints (только наличие файла)
    if [[ ! -f "/usr/share/dns/root.hints" ]]; then
        log_error "Файл корневых подсказок (root.hints) не найден!"
        HAS_ERROR=true
    fi

    # Массив пар: "Имя зоны" "Путь к файлу"
    declare -A INTERNAL_CHECKS=(
        ["localhost"]="/etc/bind/zones/internal/db.localhost"
        ["127.in-addr.arpa"]="/etc/bind/zones/internal/db.127"
        ["0.in-addr.arpa"]="/etc/bind/zones/internal/db.0"
        ["255.in-addr.arpa"]="/etc/bind/zones/internal/db.255"
        ["0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"]="/etc/bind/zones/internal/db.ip6.0"
    )

    for szone in "${!INTERNAL_CHECKS[@]}"; do
        local zfile="${INTERNAL_CHECKS[$szone]}"
        
        if [[ ! -f "$zfile" ]]; then
            log_error "Файл базы данных для зоны $szone отсутствует: $zfile"
            HAS_ERROR=true
            continue
        fi

        if ! named-checkzone "$szone" "$zfile" >/dev/null 2>&1; then
            log_error "Ошибка валидации системной зоны: $szone ($zfile)"
            named-checkzone "$szone" "$zfile" 2>&1 | log_debug
            HAS_ERROR=true
        fi
    done

    # Проверка пользовательских зон (master)
    log_info "Проверка рабочих зон (master)..."
    
    # Прямая зона
    if ! named-checkzone "$LOCAL_DOMAIN" "/etc/bind/zones/master/db.$LOCAL_DOMAIN" >/dev/null 2>&1; then
        log_error "Ошибка в файле прямой зоны: db.$LOCAL_DOMAIN"
        named-checkzone "$LOCAL_DOMAIN" "/etc/bind/zones/master/db.$LOCAL_DOMAIN" 2>&1 | log_debug
        HAS_ERROR=true
    fi

    # Обратная зона IPv4
    local REV4_ZONE="$REVERSE_OCTET_V4.in-addr.arpa"
    if ! named-checkzone "$REV4_ZONE" "/etc/bind/zones/master/db.rev4.$LOCAL_DOMAIN" >/dev/null 2>&1; then
        log_error "Ошибка в файле обратной зоны IPv4"
        named-checkzone "$REV4_ZONE" "/etc/bind/zones/master/db.rev4.$LOCAL_DOMAIN" 2>&1 | log_debug
        HAS_ERROR=true
    fi

    # Обратная зона IPv6
    local REV6_ZONE="$REVERSE_OCTET_V6.ip6.arpa"
    if ! named-checkzone "$REV6_ZONE" "/etc/bind/zones/master/db.rev6.$LOCAL_DOMAIN" >/dev/null 2>&1; then
        log_error "Ошибка в файле обратной зоны IPv6"
        named-checkzone "$REV6_ZONE" "/etc/bind/zones/master/db.rev6.$LOCAL_DOMAIN" 2>&1 | log_debug
        HAS_ERROR=true
    fi

    # Проверка прав доступа к папке логов (критично для старта)
    if [[ ! -w "/var/log/named" ]]; then
        log_error "У пользователя $(whoami) или группы bind нет прав на запись в /var/log/named"
        HAS_ERROR=true
    fi

    if [[ "$HAS_ERROR" == "true" ]]; then
        return 1
    fi
}

bind_test(){
    log_info "--- Тестирование DNS-сервера (Валидация ответов) ---"

    local TEST_DNS="${SERVER_IP_V4}" # Тестируем через локальный IPv4 адрес сервера
    local DNS_FAIL=false

    # Проверка прямой зоны (IPv4)
    log_info "Тест: Прямая зона (A) -> ${LOCAL_DOMAIN}"
    if nslookup "${LOCAL_DOMAIN}" "${TEST_DNS}" | grep -q "Address: ${SERVER_IP_V4}"; then
        log_ok "IPv4 резолвинг работает корректно."
    else
        log_error "Ошибка резолвинга ${LOCAL_DOMAIN} через ${TEST_DNS}"
        DNS_FAIL=true
    fi

    # Проверка прямой зоны (IPv6)
    log_info "Тест: Прямая зона (AAAA) -> ${LOCAL_DOMAIN}"
    if nslookup -type=aaaa "${LOCAL_DOMAIN}" "${TEST_DNS}" | grep -q "${SERVER_IP_V6}"; then
        log_ok "IPv6 резолвинг работает корректно."
    else
        log_warn "Запись AAAA для ${LOCAL_DOMAIN} не найдена или неверна."
        # Не ставим DNS_FAIL=true, если IPv6 опционален, но лучше проверить
    fi

    # Проверка обратной зоны IPv4 (PTR)
    log_info "Тест: Обратная зона IPv4 (PTR) -> ${SERVER_IP_V4}"
    if nslookup "${SERVER_IP_V4}" "${TEST_DNS}" | grep -q "name = ns1.${LOCAL_DOMAIN}"; then
        log_ok "Обратный резолвинг IPv4 работает."
    else
        log_error "Ошибка PTR записи для ${SERVER_IP_V4}"
        DNS_FAIL=true
    fi

    # Проверка рекурсии (внешний мир)
    log_info "Тест: Рекурсия (Forwarding) -> google.com"
    if nslookup "google.com" "${TEST_DNS}" >/dev/null 2>&1; then
        log_ok "Внешние запросы (Forwarders) работают."
    else
        log_warn "Сервер не смог разрешить google.com. Проверьте FORWARDER_DNS."
    fi

    # Итоговый статус теста
    if [[ "$DNS_FAIL" == "true" ]]; then
        log_error "DNS тесты завершились с критическими ошибками."
        return 1
    else
        log_ok "DNS-сервер полностью функционален."
    fi
}
# --- ООП МЕТОДЫ ИНТЕРФЕЙСА ---

bind_install() {
    load_env "$PROJECT_NAME"
    deploy_install "bind9" "${BIND_PACKAGES}" "${BIND_LIST}" BIND_SERVICES "nftables_pre_clean"
    bind_test
}

# Доработать
bind_backup() {
    load_env "$PROJECT_NAME"
    deploy_backup "nftables" "/etc/nftables.conf"
}

# Доработать
bind_update_config() {
    local source_file="${1:?Не указан путь к новому файлу настроек}"
    load_env "$PROJECT_NAME"
    deploy_update_config "nftables" "/etc/nftables.conf" "$source_file" BIND_SERVICES
}

bind_update_app() {
    load_env "$PROJECT_NAME"
    deploy_update_app "nftables" "${BIND_PACKAGES}" "${BIND_LIST}" BIND_SERVICES
    bind_test
}

bind_uninstall() {
    load_env "$PROJECT_NAME"
    deploy_uninstall "nftables" "${BIND_PACKAGES}" "${BIND_LIST}"
}