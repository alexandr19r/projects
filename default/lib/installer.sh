#!/bin/bash
# [installer.sh] - Профессиональный менеджер пакетов v2026

[[ -n "${_INSTALLER_SH_}" ]] && return
readonly _INSTALLER_SH_=1

# Настройки модуля
export PKG_MANAGER="apt-get"
export PKG_OPTS="-y -qq" # Тихий режим и авто-подтверждение

# Проверка наличия пакета в системе
is_installed() {
    local pkg_name="$1"
    # Стандарт 2026: dpkg-query быстрее и надежнее grep
    dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "ok installed"
}

# Основная функция установки
install_package() {
    local pkg_name="$1"

    if is_installed "$pkg_name"; then
        log_debug "Пакет [$pkg_name] уже установлен. Пропуск."
        return 0
    fi

    log_info "Установка пакета: $pkg_name..."
    
    # Проверка прав root
    if ! is_root; then
        log_error "Недостаточно прав для установки $pkg_name. Используйте sudo."
        return 1
    fi

    if $PKG_MANAGER install $PKG_OPTS "$pkg_name"; then
        log_ok "Пакет [$pkg_name] успешно установлен."
        return 0
    else
        log_error "Ошибка при установке [$pkg_name]."
        return 1
    fi
}

# Пакетная установка из массива
install_list() {
    local -n pkgs=$1 # Используем nameref для передачи массива
    log_info "Проверка списка зависимостей..."
    
    local needs_update=false
    
    # Сначала проверяем, нужно ли обновлять кэш
    for pkg in "${pkgs[@]}"; do
        if ! is_installed "$pkg"; then
            needs_update=true
            break
        fi
    done

    if [[ "$needs_update" == "true" ]]; then
        log_info "Обновление кэша пакетов..."
        $PKG_MANAGER update $PKG_OPTS
        
        for pkg in "${pkgs[@]}"; do
            install_package "$pkg"
        done
    else
        log_ok "Все зависимости уже удовлетворены."
    fi
}

# Функция полной очистки пакета
uninstall_package() {
    local pkg_name="$1"

    if ! is_installed "$pkg_name"; then
        log_debug "Пакет [$pkg_name] не найден в системе. Удаление не требуется."
        return 0
    fi

    log_warn "Удаление пакета и его конфигураций: $pkg_name..."
    
    if ! is_root; then
        log_error "Недостаточно прав для удаления $pkg_name."
        return 1
    fi

    # Использование purge удаляет конфиги в /etc/
    # --auto-remove удаляет неиспользуемые зависимости, установленные вместе с пакетом
    if $PKG_MANAGER purge $PKG_OPTS --auto-remove "$pkg_name"; then
        log_ok "Пакет [$pkg_name] полностью удален."
        return 0
    else
        log_error "Ошибка при удалении [$pkg_name]."
        return 1
    fi
}

# Пакетное удаление из массива (используем Nameref)
uninstall_list() {
    local -n pkgs_to_remove=$1
    log_info "Запуск процесса массовой деинсталляции..."

    for pkg in "${pkgs_to_remove[@]}"; do
        uninstall_package "$pkg"
    done
    
    # Очистка локального репозитория от скачанных архивов
    log_debug "Очистка кэша пакетов..."
    $PKG_MANAGER autoclean $PKG_OPTS
}
