#!/bin/bash
# [nftables.sh] файл установки редактора nftables

# Инициализация переменных проекта
PROJECT_NAME="nftables"
PACKAGES="nftables rsyslog"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# export DHCP_INTERFACE="eth0"
# --- Данные модификации файлов ---
# export AUTHOR=$(id -un) #Имя текущего пользователя системы
# export LAST_MODIFIED=$(date '+%Y-%m-%d') #Текущая дата изменения

# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

main_nftables() {
    
    log_info ">>> НАЧАЛО РАЗВЕРТЫВАНИЯ FIREWALL (nftables) <<<-"

    # Проверка прав и зависимостей
    log_info "--- Проверка наличия прав root ---"
    check_root || return 1

    # Загружаем переменные окружения
    log_info "--- Загрузка переменных из настроек приложения ---"
    load_env "${ROOT_DIR}/config/nftables/nftables.env"

    # Проверка и автоматическое определение интерфейса
    log_info "--- Проверка и автоматическое определение интерфейса ---"
    if [[ -z "$DHCP_INTERFACE" ]]; then
        export DHCP_INTERFACE=$(ip -4 route ls | grep default | awk '{print $5}' | head -n1)
        log_warn "DHCP_INTERFACE не задан. Авто-определение: $DHCP_INTERFACE"
    fi

    log_info "--- Установка Firewall (nftables) ---"

    # Установка пакета
    install_list "${PACKAGES}" || return 1
    
    # Транзакционная настройка по списку
    begin_transaction

    # Динамическое резервное копирование и подготовка структуры логов
    log_info "--- Создаем backup версию ---"
    
    # Добавляем в бэкап все файлы, которые прописаны в массиве как цели (dest_path)
    for entry in "${NFTABLES_CONFIG_MAP[@]}"; do
        local dest_path=$(echo "$entry" | cut -d'|' -f2)
        [[ -f "$dest_path" ] ] && add_to_staging "$dest_path"
    done
    # Финализируем процесс
    finalize_backup
    
    log_info "--- Настройка инфраструктуры Firewall (nftables) ---"
    
    # Читаем реестр и вызываем add_item для каждой строки
    grep -vE '^(#|$)' "$INFRA_LIST" | while read -r type tpl dest mode owner dep attr desc vars; do
        if ! add_item "$type" "$tpl" "$dest" "$mode" "$owner" "$dep" "$attr" "$desc" "$vars"; then
            log_error "Сбой при настройке: $desc"
            rollback_transaction
            return 1
        fi
    done || return 1 # Выход из main если цикл вернул ошибку
    
    # Проверка синтаксиса nftables перед фиксацией (Commit)
    if nft -c -f /etc/nftables.conf; then
        log_info "[OK] Синтаксис nftables корректен."
        commit_transaction
    else
        log_error "Критическая ошибка в правилах nftables! Откат..."
        rollback_transaction
        return 1
    fi

    # Включение и перезапуск
    # Перезапуск сервисов
    systemctl restart rsyslog
    systemctl enable --now nftables

    if systemctl is-active --quiet nftables; then
        log_info "[SUCCESS] Firewall активен и защищает систему."
    else
        log_error "Не удалось запустить nftables."
        return 1
    fi

    log_info ">>> ЗАВЕРШЕНИЕ РАЗВЕРТЫВАНИЯ FIREWALL (nftables) <<<"

}

main_nftables
