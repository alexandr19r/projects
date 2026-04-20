#!/bin/bash
# [bind.sh] - Развертывание сервера DNS (BIND9)

# Инициализация переменных
PROJECT_NAME="bind9"
PACKAGES="bind9 dnsutils rsyslog"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# см. [bind.env]

# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

# Функция отключения служб
disable_dns_managers() {
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

# Далее код может использовать функции ядра, например log_info
main_bind9() {
    
    log_info ">>> НАЧАЛО РАЗВЕРТЫВАНИЯ СЛУЖБ DNS (IPv4/IPv6) <<<"

    # Проверка прав и зависимостей
    log_info "--- Проверка наличия прав root ---"
    check_root || return 1

    # Сначала убираем "умные" службы resolv
    log_info "--- Отключаем умные службы resolv ---"
    disable_dns_managers

    # Загружаем переменные окружения
    log_info "--- Загрузка переменных из настроек приложения ---"
    load_env "bind/bind"

    # Установка пакета
    log_info "--- Установка DNS (${PROJECT_NAME}) и зависимостей ---"
    install_list "${PACKAGES}" || return 1
    
    # Запуск начала транзакции
    begin_transaction

    # Инициализируем модуль бэкапа (создаем временные папки)
    init_backup
    
    # Загрузка списка инфраструктуры bind
    local bind_list
    bind_list="${ROOT_DIR}/config/bind/bind.list"

    # Поверяем корректность загрузки списка инфраструктуры bind
    if [[ ! -f "$bind_list" ]]; then
        log_warn "Реестр $bind_list не найден, бэкап конфигураций пропущен."
        return 1
    fi

    # Читаем только строки с типом 'file', извлекаем путь (3-я колонка)
    # Добавляем в бэкап все файлы, которые прописаны в массиве как цели (dest_path)
    local files_to_back
    files_to_back=$(grep -vE '^(#|$)' "$bind_list" | awk '$1 == "file" {print $3}')

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
        
        # Магия подстановки для путей (заменяем метку DOMAIN на реальный домен)
        # Если в пути есть слово DOMAIN, оно заменится на значение переменной YOUR_DOMAIN
        local final_dest="${dest//DOMAIN/$LOCAL_DOMAIN}"

        # 3. Вызов add_item
        if ! add_item "$type" "$tpl" "$final_dest" "$mode" "$owner" "$dep" "$attr" "$desc" "$vars"; then
            log_error "Сбой при настройке: $desc"
            # Теперь rollback сработает правильно, так как мы не в subshell
            rollback_transaction
            return 1
        fi

    done < "$bind_list"
    
    # --- ВАЛИДАЦИЯ DNS (BIND9) ---
    # Проверка синтаксиса bind перед фиксацией (Commit)
    log_info "Валидация конфигурации BIND9..."
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
    local services=("rsyslog" "named")

    for svc in "${services[@]}"; do
        # 1. Активация автозагрузки # >/dev/null 2>&1 
        systemctl enable "$svc" | log_debug

        # 2. Перезапуск
        log_info "Перезапуск службы [$svc]..."
        if systemctl restart "$svc"; then
            # 3. Безопасная проверка активности (добавляем || : чтобы set -e не сработал)
            local status=0
            systemctl is-active --quiet "$svc" || status=$?
            
            if [[ $status -eq 0 ]]; then
                log_ok "Служба [$svc] успешно запущена."
            else
                log_error "Служба [$svc] не прошла проверку активности (is-active). Код: $status"
                log_debug "$(journalctl -u "$svc" -n 20 --no-pager)"
                return 1 # Или HAS_ERROR=true
            fi
        else
            log_error "systemctl restart $svc завершился с ошибкой."
            return 1
        fi
    done

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

    log_info ">>> ЗАВЕРШЕНИЕ РАЗВЕРТЫВАНИЯ DNS (bind9) <<<"
}

main_bind9 "$@"