#!/bin/bash
# [provisioner.sh] - Высокоуровневая настройка инфраструктуры

[[ -n "${_PROVISIONER_SH_:-}" ]] && return 0
readonly _PROVISIONER_SH_=1

# Основная функция развертывания элемента
# Рекомендуется вызывать внутри блока begin_transaction / commit_transaction
# Аргументы: $1-тип, $2-шаблон, $3-назначение, $4-права, $5-владелец, $6-зависимость, $7-атрибут, 
# $8-описание, $9-переменные 
add_item() {
    # Защищаем все входящие аргументы
    local type="${1:-}" tpl="${2:-}" dest="${3:-}" perms="${4:-}" \
          owner="${5:-}" dep="${6:-}" attr="${7:-}" desc="${8:-}" vars="${9:-}"

    log_info ">>> Настройка: $desc [$dest]"

    # 1. Регистрация в транзакции (если модуль загружен)
    if [[ $(type -t register_in_tx) == "function" ]]; then
        register_in_tx "$type" "$dest"
    fi

    # 2. Подготовка объекта (используем ранее созданный utils.sh)
    # ensure_path_exists берет на себя mkdir, touch, chown и chmod
    ensure_path_exists "$dest" "$type" "$owner" "$perms" || return 1

    # 3. Обработка шаблона (только для файлов)
    if [[ "$type" == "file" && "$tpl" != "none" ]]; then
        local tpl_path="${ROOT_DIR}/template/${tpl}.tpl"
        update_configs "$tpl_path" "$dest" "$vars" || return 1
    fi

    # 4. Групповые зависимости (usermod)
    if [[ "$dep" != "none" && "$dep" != "" ]]; then
        local target_group="${owner#*:}"
        if getent group "$target_group" >/dev/null && id "$dep" >/dev/null; then
            log_debug "Добавление $dep в группу $target_group"
            usermod -aG "$target_group" "$dep"
        else
            log_warn "Не удалось привязать $dep к $target_group (объекты не найдены)"
        fi
    fi

    # 5. Спец-атрибуты (immutable)
    if [[ "$attr" == "+i" ]]; then
        log_debug "Установка immutable флага на $dest"
        chattr +i "$dest" 2>/dev/null || log_warn "chattr +i не поддерживается ФС"
    fi

    return 0
}