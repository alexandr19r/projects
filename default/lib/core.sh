#!/bin/bash
# [core.sh] - Точка сборки системы

# Защита от повторного подключения
[[ -n "${_CORE_SH_:-}" ]] && return 0
readonly _CORE_SH_=1

set -euo pipefail
IFS=$'\n\t'

# 1. Определяем корень проекта, делаем переменную неизменяемой и доступной окружению
export readonly ROOT_DIR="${ROOT_DIR:-$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")}"

# 2. Функция инициализации ядра системы
init_system() {
    local lib_dir="${ROOT_DIR}/lib"
    local conf_dir="${ROOT_DIR}/config"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    # Подключаем модуль логирования
    if [[ ! -f "${lib_dir}/logger.sh" ]]; then
        # Типизация сообщения под модуль логирования
        echo -e "\033[0;31m[$timestamp] [ERROR] Критическая ошибка: модуль logger.sh не найден!\033[0m" >&2
        exit 1
    fi
    source "${lib_dir}/logger.sh"
    log_debug "Импортирована библиотека logger.sh"

    # Подключаем модуль загрузчика
    if [[ ! -f "${lib_dir}/loader.sh" ]]; then
        log_error "Критическая ошибка: модуль loader.sh не найден!"
        exit 1
    fi
    source "${lib_dir}/loader.sh"
    log_debug "Импортирована библиотека loader.sh"

    # Подключаем конфигурационный файл
    if [[ ! -f "${conf_dir}/settings.conf" ]]; then
        log_error "Критическая ошибка: конфигурационный файл settings.conf не найден!"
        exit 1
    fi
    source "${conf_dir}/settings.conf"
    log_debug "Применена конфигурация: settings.conf"

    # Пост-инициализация модуля логирования
    if [[ $(type -t init_logger) != "function" ]]; then
        log_error "Критическая ошибка: функция пост-инициализации init_logger не найдена!"
        exit 1
    fi
    init_logger
    log_debug "Выполнена пост-инициализация init_logger"

    bootstrap_registry
    log_debug "Ядро системы инициализировано. Strict mode: ON."

}

# Инициализация модулей согласно табличному реестру
bootstrap_registry() {
    local MODULE_LIST
    read -r -d '' MODULE_LIST <<-'EOF' || true
        # ИМЯ_МОДУЛЯ       LOAD_LIB   LOAD_CONF
        utils              yes        no
        backup             yes        no
        installer          yes        no
        telegram           no         no
        transaction        yes        no
        provisioner        yes        no
EOF

    # Используем IFS для четкого разделения колонок
    while IFS=$' \t' read -r module_name load_lib load_conf _ || [[ -n "${module_name:-}" ]]; do
        # Пропуск комментариев и пустых строк (защита от пустых переменных)
        [[ -z "${module_name:-}" || "${module_name}" =~ ^# ]] && continue

        # 1. Сначала загружаем конфиг (если требуется)
        if [[ "${load_conf:-no}" == "yes" ]]; then
            import_config "${module_name}"
        fi

        # 2. Затем загружаем саму библиотеку
        if [[ "${load_lib:-no}" == "yes" ]]; then
            import_lib "${module_name}"
            log_debug "Модуль [${module_name}] инициализирован."
        fi

    done <<< "${MODULE_LIST}"
}

# Глобальный обработчик завершения
_cleanup() {
    local exit_code=$?
    # Если транзакция была активна, но не зафиксирована — откатываем
    if [[ "${TRANSACTION_ACTIVE:-false}" == "true" ]]; then
        rollback_transaction
    fi
    
    [[ $exit_code -ne 0 ]] && log_error "Скрипт завершился с ошибкой: $exit_code"
    exit $exit_code
}
trap _cleanup EXIT

# Инициализация (вызов)
init_system

log_info "--- Ядро успешно подключено в защищенном режиме. ---"