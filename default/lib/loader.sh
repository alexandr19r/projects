#!/bin/bash
# [loader.sh] - Управление зависимостями

[[ -n "${_LOADER_SH_}" ]] && return
readonly _LOADER_SH_=1

import_lib() {
    local name=$1
    local path="${ROOT_DIR}/lib/${name}.sh"

    if [[ -f "$path" ]]; then
        source "$path"
        log_debug "Импортирована библиотека: ${name}.sh"
    else
        log_error "Критическая библиотека не найдена: $path"
        exit 1
    fi
}

import_config() {
    local name=$1
    local path="${ROOT_DIR}/config/${name}.conf"

    if [[ -f "$path" ]]; then
        source "$path"
        log_debug "Применена конфигурация: ${name}.conf"
    else
        log_warn "Файл конфигурации $name не найден. Применяются настройки по умолчанию."
    fi
}
