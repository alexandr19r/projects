#!/bin/bash
# [loader.sh] - Управление зависимостями

[[ -n "${_LOADER_SH_:-}" ]] && return 0
readonly _LOADER_SH_=1

# Массив для отслеживания уже загруженных библиотек
declare -gA _LOADED_RESOURCES_

_import_core() {
    local type="$1"       # 'lib', 'app', 'conf', 'env', tpl
    local name="$2"       # имя компонента, например 'logger' или 'kea'
    local path="$3"       # полный вычисленный путь к файлу
    local strict="${4}"   # 'true' (упасть при ошибке) или 'false' (вернуть статус)

    # Защита от повторного импорта (учитывает тип, чтобы не было коллизий)
    local registry_key="${type}:${name}"
    [[ -n "${_LOADED_RESOURCES_[$registry_key]:-}" ]] && return 0

    # Проверка физического наличия файла
    if [[ ! -f "$path" ]]; then
        if [[ "$strict" == "true" ]]; then
            log_error "Критическая ошибка компонент не найден: [${type}]: ${name}"
            exit 1
        else
            log_warn "Компонент [${type}]: ${name} не найден. Применяются настройки по умолчанию."
            return 1 # Мягкий отказ для приложений
        fi
    fi
    
    # Для шаблонов (.tpl) выполнение через source НЕ требуется, только фиксация наличия
    if [[ "$type" == "tpl" ]]; then
        _LOADED_RESOURCES_["$registry_key"]="$path" # Сохраняем путь к шаблону как значение
        
        log_debug "Шаблон [${name}] успешно зарегистрирован: $path"
        return 0
    fi

    # Если тип env 'set -a' помечает все последующие переменные как export
    if [[ "$type" == "env" ]]; then set -a; fi

    # Попытка загрузки (source)
    local source_status=0
    source "$path" || source_status=$?

    # Отключаем автоэкспорт
    if [[ "$type" == "env" ]]; then set +a; fi

    if [[ "$source_status" -eq 0 ]]; then
        _LOADED_RESOURCES_["$registry_key"]=1
        
        log_debug "Успешно импортирован компонент: [${type}]: ${name}"
        return 0
    else
        log_error "Синтаксический сбой внутри компонента: [${type}]: ${name}"
        [[ "$strict" == "true" ]] && exit 1 || return 1
    fi

}

import_lib() {
    local name="$1"
    local type="lib"
    local strict="true"
    local path="${ROOT_DIR}/lib/${name}.sh"

    _import_core "$type" "$name" "$path" "$strict"
}

import_config() {
    local name="$1"
    local type="conf"
    local strict="false"
    local path="${ROOT_DIR}/config/${name}.conf"

    _import_core "$type" "$name" "$path" "$strict"
}

import_module() {
    local name="$1"
    local type="app"
    local strict="true"
    local path="${ROOT_DIR}/apps.d/${name}/${name}.sh"

    _import_core "$type" "$name" "$path" "$strict"
}

load_env() {
    local name="$1"
    local type="env"
    local strict="false"
    local path="${ROOT_DIR}/apps.d/${name}/config/${name}.env"

    _import_core "$type" "$name" "$path" "$strict"
}

load_tpl() {
    local file_name="$1"
    local type="tpl"
    local strict="false"
    local path=$(resolve_template_path "$file_name")

    _import_core "$type" "$app_name" "$path" "$strict"

    return "$path"
}

# Функция разрешения пути к шаблону на основе разделителя '//'
# Аргументы: tpl_inline (из таблицы)
resolve_template_path() {
    local tpl_inline="${1:-}"
    
    # Если шаблон не указан или равен none (для директорий/ссылок), возвращаем none
    [[ -z "$tpl_inline" || "$tpl_inline" == "none" ]] && { echo "none"; return 0; }

    local absolute_tpl_path=""

    # Проверяем, содержит ли строка двойной слеш
    if [[ "$tpl_inline" == *//* ]]; then
        # Вариант 1: Шаблон приложения (найден разделитель //)
        # Извлекаем все, что ДО двойного слеша (имя приложения)
        local app_context="${tpl_inline%%//*}"
        # Извлекаем все, что ПОСЛЕ двойного слеша (имя файла шаблона)
        local file_name="${tpl_inline##*//}"
        
        absolute_tpl_path="${ROOT_DIR}/apps.d/${app_context}/template/${file_name}.tpl"
    else
        # Вариант 2: Глобальный системный шаблон (двойного слеша нет)
        absolute_tpl_path="${ROOT_DIR}/template/${tpl_inline}.tpl"
    fi

    return "$absolute_tpl_path"
}
