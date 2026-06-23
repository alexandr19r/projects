#!/bin/bash
# [installer.sh] - Профессиональный менеджер пакетов v2026

[[ -n "${_INSTALLER_SH_:-}" ]] && return
readonly _INSTALLER_SH_=1

# Настройки модуля
# export PKG_MANAGER="apt-get"
# export PKG_OPTS="-y -qq" # Тихий режим и авто-подтверждение
# Настройки модуля (лучше без export, если не нужно дочерним процессам)
: "${PKG_MANAGER:="apt-get"}"
: "${PKG_OPTS:="-y -qq"}"
# Проверяем, определен ли уже массив PKG_OPTS
#if [[ -z "${PKG_OPTS[*]:-}" ]]; then
#    # Если массив пуст или не существует, инициализируем его
#    declare -ga PKG_OPTS=(-y -qq)
#fi

# Проверка наличия пакета в системе
_is_installed() {
    local pkg_name="${1:-}"
    [[ -z "$pkg_name" ]] && return 1
    # Стандарт 2026: dpkg-query быстрее и надежнее grep
    # dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "ok installed"
    # Добавлен || return 1, чтобы не триггерить set -e при отсутствии пакета
    dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "ok installed" || return 1
}

# Одиночная установка (враппер над install_list)
install_package() {
    install_list "${1:-}"
}

# Пакетная установка (install function)
install_list() {
    local raw_pkgs="${1:-}"
    [[ -z "$raw_pkgs" ]] && return 0

    # Превращаем строку в массив (делим по пробелам)
    local -a pkgs=($raw_pkgs)
    local to_install=()

    log_info "Анализ зависимостей ${pkgs[*]}"

    # Собираем только то, чего реально нет
    for pkg in "${pkgs[@]}"; do
        # Используем if, чтобы не триггерить set -e
        if ! _is_installed "$pkg"; then
            to_install+=("$pkg")
        else
            log_debug "Пакет [$pkg] уже присутствует в системе."
        fi
    done

    # Если список пуст — выходим
    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_ok "Все зависимости уже удовлетворены."
        return 0
    fi

    # Проверка прав доступа
    if ! check_root; then
        log_error "Права root необходимы для установки: ${to_install[*]}"
        return 1
    fi

    # Проверка наличия пакетного менеджера
    if ! command -v "$PKG_MANAGER" >/dev/null 2>&1; then
        log_error "Пакетный менеджер $PKG_MANAGER не найден в системе."
        return 1
    fi

    log_info "Выполнение установки: ${to_install[*]}..."

    # Обновление кэша (только если нужно) и установка
    # Используем блоки if вместо && для чистого логирования ошибок
    # Обернутый вызов обновления кэша репозиториев
    if ! _exec "Обновление кэша пакетов ..." env DEBIAN_FRONTEND=noninteractive $PKG_MANAGER update $PKG_OPTS; then
        log_warn "Не удалось обновить кэш пакетов, пробуем установить так..."
    fi

    if _exec "Установка пакетов..." env DEBIAN_FRONTEND=noninteractive $PKG_MANAGER install $PKG_OPTS "${to_install[@]}"; then
        log_ok "Пакеты успешно установлены: ${to_install[*]}"
        return 0
    else
        log_error "Критический сбой при установке пакетов."
        return 1
    fi
}

# Одиночное удаление (враппер над uninstall_list)
uninstall_package() {
    uninstall_list "${1:-}"
}

# Пакетное удаление (purge + auto-remove)
uninstall_list() {
    local raw_pkgs="${1:-}"
    [[ -z "$raw_pkgs" ]] && return 0

    # Превращаем строку в массив
    local -a pkgs=($raw_pkgs)
    local to_purge=()

    log_info "Анализ установленных компонентов для удаления..."

    # Собираем только те пакеты, которые реально есть в системе
    for pkg in "${pkgs[@]}"; do
        if _is_installed "$pkg"; then
            to_purge+=("$pkg")
        else
            log_debug "Пакет [$pkg] отсутствует, удаление не требуется."
        fi
    done

    # Если удалять нечего — выходим
    if [[ ${#to_purge[@]} -eq 0 ]]; then
        log_ok "Целевые пакеты не найдены в системе."
        return 0
    fi

    # Проверка прав доступа
    if ! check_root; then
        log_error "Нужны права root для удаления: ${to_purge[*]}"
        return 1
    fi
    
    # Проверка наличия пакетного менеджера
    if ! command -v "$PKG_MANAGER" >/dev/null 2>&1; then
        log_error "Пакетный менеджер $PKG_MANAGER не найден в системе."
        return 1
    fi

    log_warn "ВНИМАНИЕ: Массовое удаление пакетов и конфигов: ${to_purge[*]}"

    # Удаление одной командой
    # purge — удаляет конфиги в /etc
    # --auto-remove — чистит ставшие ненужными зависимости
    if _exec "Удаление пакетов..." env DEBIAN_FRONTEND=noninteractive $PKG_MANAGER purge $PKG_OPTS --auto-remove "${to_purge[@]}"; then
        log_ok "Пакеты успешно удалены и зачищены: ${to_purge[*]}"
        
        # Очистка кэша .deb файлов для освобождения места
        _exec "Очистка локального архива пакетов (autoclean)..." env DEBIAN_FRONTEND=noninteractive $PKG_MANAGER autoclean $PKG_OPTS || true
        return 0
    else
        log_error "Критический сбой при удалении пакетов."
        return 1
    fi
}

# Одиночное обновление (враппер над update_list)
update_package() {
    update_list "${1:-}"
}

# Пакетное обновление (update function)
update_list() {
    local raw_pkgs="${1:-}"
    [[ -z "$raw_pkgs" ]] && return 0

    # Превращаем строку в массив (делим по пробелам)
    local -a pkgs=($raw_pkgs)
    local to_upgrade=()

    log_info "Анализ пакетов для обновления: ${pkgs[*]}"

    # Собираем только те пакеты, которые РЕАЛЬНО установлены в системе
    for pkg in "${pkgs[@]}"; do
        if _is_installed "$pkg"; then
            to_upgrade+=("$pkg")
        else
            log_debug "Пакет [$pkg] отсутствует в системе. Обновление невозможно (используйте установку)."
        fi
    done

    # Если обновлять нечего — выходим
    if [[ ${#to_upgrade[@]} -eq 0 ]]; then
        log_ok "Нет установленных пакетов для обновления."
        return 0
    fi

    # Проверка прав доступа
    if ! check_root; then
        log_error "Права root необходимы для обновления: ${to_upgrade[*]}"
        return 1
    fi

    # Проверка наличия пакетного менеджера
    if ! command -v "$PKG_MANAGER" >/dev/null 2>&1; then
        log_error "Пакетный менеджер $PKG_MANAGER не найден в системе."
        return 1
    fi

    if ! _exec "Обновление кэша пакетов ..." env DEBIAN_FRONTEND=noninteractive $PKG_MANAGER update $PKG_OPTS; then
        log_warn "Не удалось обновить кэш пакетов, пробуем запустить обновление так..."
    fi

    # Флаг --only-upgrade передается через PKG_OPTS или явно, гарантируя безопасность
    if _exec "Установка обновленных версий пакетов ..." env DEBIAN_FRONTEND=noninteractive $PKG_MANAGER install --only-upgrade $PKG_OPTS "${to_upgrade[@]}"; then
        log_ok "Пакеты успешно обновлены: ${to_install[*]}"
        return 0
    else
        log_error "Критический сбой при обновлении пакетов."
        return 1
    fi
}