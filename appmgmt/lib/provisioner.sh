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

    # Регистрация в транзакции (если модуль загружен)
    if [[ $(type -t register_in_tx) == "function" ]]; then
        register_in_tx "$type" "$dest"
    fi

    # Подготовка объекта (используем ранее созданный utils.sh)
    # ensure_path_exists берет на себя mkdir, touch, chown и chmod
    ensure_path_exists "$dest" "$type" "$owner" "$perms" "$tpl" || return 1

    # Обработка шаблона (только для файлов)
    if [[ "$type" == "file" && "$tpl" != "none" ]]; then
        # local tpl_path="${ROOT_DIR}/template/${tpl}.tpl"
        local tpl_path=$(load_tpl "$tpl")
        if ! update_configs "$tpl_path" "$dest" "$vars"; then
            log_error "Ошибка компиляции шаблона для файла: $dest"
            return 1
        fi
    fi

    # Групповые зависимости (usermod)
    if [[ "$dep" != "none" && "$dep" != "" ]]; then
        local target_group="${owner#*:}"
        # Переменная-флаг для валидации возможности привязки групп
        local can_bind=false

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            # В режиме имитации безусловно разрешаем шаг
            can_bind=true
        else
            # В боевом режиме строго проверяем наличие субъектов в ОС
            if getent group "$target_group" >/dev/null && id "$dep" >/dev/null; then
                can_bind=true
            fi
        fi
        
        if [[ "$can_bind" == "true" ]]; then
            if ! _exec "Привязка пользователя $dep к группе $target_group" usermod -aG "$target_group" "$dep"; then
                log_error "Не удалось добавить пользователя $dep в группу $target_group"
                return 1
            fi
        else
            log_warn "Пропущено: Не удалось привязать $dep к $target_group (объекты не найдены в системе)"
        fi
   fi

    # Спец-атрибуты (immutable)
    if [[ "$attr" == "+i" ]]; then
        if command -v chattr >/dev/null 2>&1; then
            # Используем || true, чтобы особенности ФС (например, контейнеры) не ломали боевой деплой
            if ! _exec "Установка флага защиты immutable (+i) на $dest" chattr +i "$dest" 2>/dev/null; then
                log_warn "Флаг chattr +i не смог примениться для $dest (возможно, ограничение контейнера/ФС)"
            fi
        else
            log_debug "Утилита chattr недоступна в системе, пропускаю установку атрибута +i"
        fi
    fi

    return 0
}