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

# Проверка наличия пакета в системе
_is_installed() {
    local pkg_name="$1"
    # Стандарт 2026: dpkg-query быстрее и надежнее grep
    # dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "ok installed"
    # Добавлен || return 1, чтобы не триггерить set -e при отсутствии пакета
    dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "ok installed" || return 1
}

# Основная функция установки
install_package() {
    local pkg_name="$1"

    # Проверка на пустую строку
    [[ -z "$pkg_name" ]] && return 0

    if _is_installed "$pkg_name"; then
        log_debug "Пакет [$pkg_name] уже установлен."
        return 0
    fi
    
    # Проверка прав root
    if ! is_root; then
        log_error "Недостаточно прав для установки $pkg_name. Используйте sudo."
        return 1
    fi

    log_info "Установка пакета: $pkg_name..."

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
    local -n pkgs=$1
    local to_install=()

    log_info "Анализ зависимостей..."

    # 1. Собираем только то, чего реально нет
    for pkg in "${pkgs[@]}"; do
        # Используем if, чтобы не триггерить set -e
        if ! _is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    # 2. Если список пуст — выходим
    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_ok "Все зависимости уже удовлетворены."
        return 0
    fi

    # 3. Установка одной командой
    log_info "Необходимо установить: ${to_install[*]}"
    
    if ! is_root; then
        log_error "Нужны права root для установки пакетов."
        return 1
    fi

    log_info "Обновление кэша и установка..."
    # Обновляем кэш и устанавливаем всё разом
    if $PKG_MANAGER update $PKG_OPTS && \
       $PKG_MANAGER install $PKG_OPTS "${to_install[@]}"; then
        log_ok "Все пакеты успешно установлены."
    else
        log_error "Сбой при пакетной установке."
        return 1
    fi
}

# Функция полной очистки пакета
uninstall_package() {
    local pkg_name="$1"

    # Проверка на пустую строку
    [[ -z "$pkg_name" ]] && return 0

    if ! _is_installed "$pkg_name"; then
        log_debug "Пакет [$pkg_name] не найден в системе. Удаление не требуется."
        return 0
    fi
    
    # Проверка прав root
    if ! is_root; then
        log_error "Недостаточно прав для удаления $pkg_name."
        return 1
    fi

    log_warn "Удаление пакета и его конфигураций: $pkg_name..."

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

# Пакетное удаление из массива (Standard 2026)
uninstall_list() {
    local -n pkgs_to_remove=$1
    local to_purge=()

    log_info "Анализ установленных пакетов для удаления..."

    # 1. Собираем только те пакеты, которые реально установлены
    for pkg in "${pkgs_to_remove[@]}"; do
        if _is_installed "$pkg"; then
            to_purge+=("$pkg")
        fi
    done

    # 2. Если удалять нечего — выходим
    if [[ ${#to_purge[@]} -eq 0 ]]; then
        log_ok "Указанные пакеты в системе не найдены. Удаление не требуется."
        return 0
    fi

    # 3. Проверка прав
    if ! is_root; then
        log_error "Нужны права root для удаления: ${to_purge[*]}"
        return 1
    fi

    log_warn "Массовое удаление пакетов: ${to_purge[*]}"

    # 4. Удаление одной командой (purge + autoremove)
    if $PKG_MANAGER purge $PKG_OPTS --auto-remove "${to_purge[@]}"; then
        log_ok "Пакеты успешно удалены: ${to_purge[*]}"
        
        log_debug "Очистка локального кэша архивов..."
        $PKG_MANAGER autoclean $PKG_OPTS
        return 0
    else
        log_error "Ошибка при массовом удалении пакетов."
        return 1
    fi
}
