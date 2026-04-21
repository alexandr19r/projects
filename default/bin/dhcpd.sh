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

main_dhcpd() {
    
    log_info ">>> НАЧАЛО РАЗВЕРТЫВАНИЯ СЛУЖБ DHCP (IPv4/IPv6) <<<"

    # Проверка прав и зависимостей
    log_info "--- Проверка наличия прав root ---"
    check_root || return 1

    # Загружаем переменные окружения
    log_info "--- Загрузка переменных из настроек приложения ---"
    load_env "dhcp/dhcp"

    # Проверка и автоматическое определение интерфейса
    log_info "--- Проверка и автоматическое определение интерфейса ---"
    if [[ -z "$DHCP_INTERFACE" ]]; then
        export DHCP_INTERFACE=$(ip -4 route ls | grep default | awk '{print $5}' | head -n1)
        log_warn "DHCP_INTERFACE не задан. Авто-определение: $DHCP_INTERFACE"
    fi

    # Установка пакета
    log_info "--- Установка DCHP сервера (isc-dhcp-server) и зависимостей ---"
    install_list "${PACKAGES}" || return 1
    
    # Прибиваем зависшие процессы dhcpd, которые могли остаться от кривой установки пакета
    log_info "Очистка окружения DHCP..."
    pkill -9 dhcpd 2>/dev/null || true

    # Запуск начала транзакции
    begin_transaction
    
    # Инициализируем модуль бэкапа (создаем временные папки)
    init_backup
    
    # Загрузка списка инфраструктуры dhcp
    local dhcp_list
    dhcp_list="${ROOT_DIR}/config/dhcp/dhcp.list"

    # Поверяем корректность загрузки списка инфраструктуры dhcp
    if [[ ! -f "$dhcp_list" ]]; then
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
    # Используем перенаправление < вместо пайпа |, чтобы rollback работал в основном процессе
    while IFS='|' read -r type tpl dest mode owner dep attr desc vars || [[ -n "$type" ]]; do
        
        # 1. Очистка от пробелов и пропуск пустых строк/комментариев
        type=$(echo "${type}" | xargs)
        [[ -z "$type" || "$type" =~ ^# ]] && continue

        # 2. Очистка остальных переменных от лишних пробелов по бокам пайпа
        tpl=$(echo "${tpl}" | xargs)
        dest=$(echo "${dest}" | xargs)
        mode=$(echo "${mode}" | xargs)
        owner=$(echo "${owner}" | xargs)
        dep=$(echo "${dep}" | xargs)
        attr=$(echo "${attr}" | xargs)
        desc=$(echo "${desc}" | xargs)
        vars=$(echo "${vars}" | xargs)

        # 3. Вызов add_item
        if ! add_item "$type" "$tpl" "$dest" "$mode" "$owner" "$dep" "$attr" "$desc" "$vars"; then
            log_error "Сбой при настройке: $desc"
            # Теперь rollback сработает правильно, так как мы не в subshell
            rollback_transaction
            return 1
        fi

    done < "$dhcp_list"
    
    # Проверка синтаксиса dhcp перед фиксацией (Commit)
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

    # 4. Проверка Rsyslog
    log_info "Валидация Rsyslog..."
    if ! rsyslogd -N1 >/dev/null 2>&1; then
        log_error "Критическая ошибка в конфигурации Rsyslog"
        { rsyslogd -N1 2>&1 || true; } | log_debug
        HAS_ERROR=true
    fi

    # --- ОТКАТ ТРАНЗАКЦИИ ---
    if [[ "$HAS_ERROR" == "true" ]]; then
        log_error "Тестирование провалено. Инициирую ROLLBACK..."
        # Выполняем откат изменений
        rollback_transaction
        return 1
    fi

    log_ok "Все тесты пройдены. Фиксация изменений..."
    # Финализируем бекап
    finalize_backup
    # Применяем изменения
    commit_transaction

    # Перезапуск и проверка служб
    log_info "--- Активация и проверка сервисов ---"
    local services=("rsyslog" "radvd" "isc-dhcp-server")

    for svc in "${services[@]}"; do
        # 1. Сначала делаем enable, чтобы служба стартовала после перезагрузки
        systemctl enable "$svc" 2>&1 | log_debug
        
        # 2. Перезапуск
        if systemctl restart "$svc"; then
            # 3. Дополнительная проверка: активна ли она на самом деле
            if systemctl is-active --quiet "$svc"; then
                log_ok "Служба [$svc] успешно запущена и добавлена в автозагрузку."
            else
                log_error "Служба [$svc] формально стартовала, но сейчас неактивна."
            fi
        else
            log_error "Критический сбой при запуске $svc. Код ошибки: $?"
            log_debug "Вывод диагностики: $(journalctl -u "$svc" -n 20 --no-pager)"
        fi
    done
    
    log_info ">>> ЗАВЕРШЕНИЕ РАЗВЕРТЫВАНИЯ СЛУЖБ DHCP (IPv4/IPv6) <<<"

}

main_dhcpd "$@"