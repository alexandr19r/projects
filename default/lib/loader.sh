#!/bin/bash
# [loader.sh] - Управление зависимостями

[[ -n "${_LOADER_SH_:-}" ]] && return 0
readonly _LOADER_SH_=1

# Массив для отслеживания уже загруженных библиотек
declare -gA _LOADED_MODULES_

import_lib() {
    local name=$1
    local path="${ROOT_DIR}/lib/${name}.sh"

    # Если уже загружено — выходим
    [[ -n "${_LOADED_MODULES_[$name]}" ]] && return 0

    if [[ -f "$path" ]]; then
        source "$path"
        _LOADED_MODULES_["$name"]=1
        log_debug "Библиотека [${name}] успешно импортирована"
    else
        log_error "Критическая библиотека не найдена: $path"
        exit 1
    fi
}

import_config() {
    local name=$1
    local path="${ROOT_DIR}/config/${name}.conf"

    if [[ -f "$path" ]]; then
        # Используем 'set -a' перед source, если конфиги — это просто VAR=VAL
        # чтобы они сразу экспортировались (опционально)
        source "$path"
        log_debug "Конфигурация [${name}] применена"
    else
        log_warn "Файл конфигурации $name не найден. Применяются настройки по умолчанию."
    fi
}

load_env() {
    local name=$1
    local path="${ROOT_DIR}/env/${name}.env"

    if [[ -f "$path" ]]; then
        log_debug "Загрузка переменных окружения из: $path"

        # 'set -a' помечает все последующие переменные как export
        set -a
        
        # Подключаем файл. Мы используем 'source', чтобы переменные 
        # попали в текущую оболочку, а не в дочернюю.
        # shellcheck disable=SC1090
        source "$path"
        
        # 3. 'set +a' отключает автоматический экспорт
        set +a
        
        log_ok "Файл окружения [$path] успешно применен."
        return 0
    else
        log_warn "Файл окружения $path не найден. Используются дефолты."
        return 1
    fi
}
