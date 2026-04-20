#!/bin/bash
# [installer.sh] - Профессиональный менеджер пакетов v2026

[[ -n "${_INSTALLER_SH_:-}" ]] && return
readonly _INSTALLER_SH_=1

# Настройки модуля
# export PKG_MANAGER="apt-get"
# export PKG_OPTS="-y -qq" # Тихий режим и авто-подтверждение
# Настройки модуля (лучше без export, если не нужно дочерним процессам)
: "${PKG_MANAGER:="apt-get"}"
# : "${PKG_OPTS:="-y -qq"}"
# Проверяем, определен ли уже массив PKG_OPTS
if [[ -z "${PKG_OPTS[*]:-}" ]]; then
    # Если массив пуст или не существует, инициализируем его
    declare -ga PKG_OPTS=(-y -qq)
fi

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

# Пакетная установка (Основная рабочая лошадка)
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

    # Проверка DRY_RUN перед любыми действиями
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_warn "[DRY-RUN] Имитация установки: ${to_install[*]}"
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
    log_info "Обновление кэша..."
    log_info "$PKG_MANAGER update ${PKG_OPTS[@]}"
    if ! $PKG_MANAGER update ${PKG_OPTS[@]} >/dev/null 2>&1; then
        log_warn "Не удалось обновить кэш пакетов, пробуем установить так..."
    fi

    log_info "Установка пакетов..."
    log_info "$PKG_MANAGER install ${PKG_OPTS[@]} ${to_install[@]}"
    if "$PKG_MANAGER install ${PKG_OPTS[@]} ${to_install[@]}"; then
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

    # --- DRY_RUN CHECK ---
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_warn "[DRY-RUN] Имитация ПОЛНОГО удаления (purge): ${to_purge[*]}"
        return 0
    fi

    # Проверка прав доступа
    if ! check_root; then
        log_error "Нужны права root для удаления: ${to_purge[*]}"
        return 1
    fi

    log_warn "ВНИМАНИЕ: Массовое удаление пакетов и конфигов: ${to_purge[*]}"

    # Удаление одной командой
    # purge — удаляет конфиги в /etc
    # --auto-remove — чистит ставшие ненужными зависимости
    if $PKG_MANAGER purge $PKG_OPTS --auto-remove "${to_purge[@]}"; then
        log_ok "Пакеты успешно удалены и зачищены: ${to_purge[*]}"
        
        # Очистка кэша .deb файлов для освобождения места
        log_debug "Очистка локального архива пакетов (autoclean)..."
        $PKG_MANAGER autoclean $PKG_OPTS >/dev/null 2>&1 || true
        return 0
    else
        log_error "Критический сбой при удалении пакетов."
        return 1
    fi
}