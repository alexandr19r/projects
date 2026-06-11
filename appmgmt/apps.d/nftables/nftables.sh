#!/bin/bash
# [apps.d/nftables.sh] - Развертывание шлюза NFTables (MITM Router)

# Инициализация переменных проекта
PROJECT_NAME="nftables"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# см. [nftables.env]

# Определение глобальных параметров "класса" NFTables
NFTABLES_PACKAGES="nftables ulogd2 ulogd2-json"
NFTABLES_SERVICES=("nftables ulogd2")
NFTABLES_LIST="${ROOT_DIR}/apps.d/nftables/config/nftables.list"

# Кастомный метод очистки портов
nftables_pre_clean() {
    #    pkill -9 kea-dhcp4 || true
    #    rm -f /var/run/kea/*.pid
    true
}

# Кастомный полиморфный метод валидации
nftables_validate() {
    local HAS_ERROR="false"
    
    # Проверка NFTables
    log_info "Валидация NFTables..."
    if ! nft -c -f "/etc/nftables.conf" >/dev/null 2>&1; then
        log_error "Синтаксическая ошибка в /etc/nftables.conf"
        nft -c -f "/etc/nftables.conf" 2>&1 | log_debug
        HAS_ERROR="true"
    fi

    # Проверка ulogd
    log_info "Валидация ulogd..."

    # Запускаем ulogd с указанием нашего конфига на 1 секунду в фоне.
    # Если в конфиге ошибка — он упадет мгновенно. Если всё ок — будет работать.
    ulogd -c /etc/ulogd.conf -d >/dev/null 2>&1
    local ulogd_pid=$!

    # Даем демону 1 секунду на инициализацию парсером ядра
    sleep 1

    # Проверяем, жив ли процесс. Если процесс умер — значит конфиг невалиден.
    if ! kill -0 "$ulogd_pid" 2>/dev/null; then
        log_error "Критическая ошибка в конфигурации ulogd"
        HAS_ERROR="true"
        return 1
    else
        kill "$ulogd_pid" && wait "$ulogd_pid" 2>/dev/null
        log_ok "Синтаксис конфигурации ulogd успешно проверен."
    fi
    # Конец проверки ulogd

    if [[ "$HAS_ERROR" == "true" ]]; then
        return 1
    fi
}

# --- ООП МЕТОДЫ ИНТЕРФЕЙСА ---

nftables_install() {
    load_env "$PROJECT_NAME"
    deploy_install "nftables" "${NFTABLES_PACKAGES}" "${NFTABLES_LIST}" NFTABLES_SERVICES "nftables_pre_clean"
}

# Доработать
nftables_backup() {
    load_env "$PROJECT_NAME"
    deploy_backup "nftables" "/etc/nftables.conf"
}

# Доработать
nftables_update_config() {
    local source_file="${1:?Не указан путь к новому файлу настроек}"
    load_env "$PROJECT_NAME"
    deploy_update_config "nftables" "/etc/nftables.conf" "$source_file" NFTABLES_SERVICES
}

nftables_update_app() {
    load_env "$PROJECT_NAME"
    deploy_update_app "nftables" "${NFTABLES_PACKAGES}" "${NFTABLES_LIST}" NFTABLES_SERVICES
}

nftables_uninstall() {
    load_env "$PROJECT_NAME"
    deploy_uninstall "nftables" "${NFTABLES_PACKAGES}" "${NFTABLES_LIST}"
}