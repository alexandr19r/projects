#!/bin/bash
# [lib/deploy_engine.sh] - Модульный полиморфный движок жизненного цикла приложений

[[ -n "${_DEPLOY_ENGINE_SH_:-}" ]] && return 0
readonly _DEPLOY_ENGINE_SH_=1

# ======================================================================
# СИСТЕМНЫЕ ПРИВАТНЫЕ УТИЛИТЫ ДВИЖКА (CORE UTILS)
# ======================================================================

# Внутренний парсер табличных файлов реестра .list
_deploy_manager() {
    local list_file="$1"
    local -A processed_paths=()

    log_info "--- Обработка реестра инфраструктуры (.list) ---"

    while IFS='|' read -r type tpl dest mode owner dep attr desc vars || [[ -n "$type" ]]; do
        # Удаляем любые пробелы по краям (Совместимо со всеми версиями Bash)
        type="${type##*[[:space:]]}"; type="${type%%*[[:space:]]}"
        [[ -z "$type" || "$type" =~ ^# ]] && continue

        # Атомарная зачистка всех полей строки
        tpl="${tpl##+([[:space:]])}"; tpl="${tpl%%+([[:space:]])}"
        dest="${dest##+([[:space:]])}"; dest="${dest%%+([[:space:]])}"
        mode="${mode##+([[:space:]])}"; mode="${mode%%+([[:space:]])}"
        owner="${owner##+([[:space:]])}"; owner="${owner%%+([[:space:]])}"
        dep="${dep##+([[:space:]])}"; dep="${dep%%+([[:space:]])}"
        attr="${attr##+([[:space:]])}"; attr="${attr%%+([[:space:]])}"
        desc="${desc##+([[:space:]])}"; desc="${desc%%+([[:space:]])}"
        vars="${vars##+([[:space:]])}"; vars="${vars%%+([[:space:]])}"
        
        # Защита от дублирования путей в рамках одной сессии
        if [[ -n "${processed_paths[$dest]:-}" ]]; then
            log_error "Критическая ошибка в реестре: путь назначения [$dest] дублируется!"
            return 1
        fi
        processed_paths["$dest"]=1
        
        # Автоматический превентивный staging-бэкап существующих файлов перед изменением
        if [[ "$type" == "file" && -f "$dest" ]]; then
            log_debug "Staging бэкап существующего файла: $dest"
            add_to_staging "$dest"
        fi

        # Передача данных в атомарный установщик системы (lib/core.sh)
        if ! add_item "$type" "$tpl" "$dest" "$mode" "$owner" "$dep" "$attr" "$desc" "$vars"; then
            log_error "Сбой настройки компонента: $desc."
            return 1
        fi
    done < "$list_file"
    return 0
}

# Внутренний триггер управления системными демонами (Health-Check)
_deploy_control_services() {
    local services_array_ref="$1"
    local -n TargetServices="$services_array_ref"

    log_info "--- Активация и запуск системных служб ---"
    for svc in "${TargetServices[@]}"; do
        systemctl enable "$svc" 2>&1 | log_debug || true
        if systemctl restart "$svc" && systemctl is-active --quiet "$svc"; then
            log_ok "Служба [$svc] успешно запущена и работает стабильно."
        else
            log_error "Критический сбой запуска службы: $svc"
            return 1
        fi
    done
    return 0
}

# ======================================================================
# ПУБЛИЧНЫЙ ПОЛИМОРФНЫЙ ИНТЕРФЕЙС (ООП МЕТОДЫ)
# ======================================================================

# 1. ФУНКЦИОНАЛ УСТАНОВКИ ПРИЛОЖЕНИЯ
deploy_install() {
    local app_name="$1"
    local packages="$2"
    local list_file="$3"
    local services_array_ref="$4"
    local pre_clean_callback="$5"

    log_info ">>> [INSTALL] Начало развертывания компонента: [${app_name^^}] <<<"
    check_root || return 1

    # Вызов предварительного очистителя (если объявлен в приложении)
    if [[ "$pre_clean_callback" != "none" ]] && declare -f "$pre_clean_callback" >/dev/null; then
        "$pre_clean_callback"
    fi

    log_info "--- Установка бинарных пакетов и зависимостей ---"
    install_list "${packages}" || return 1

    if [[ ! -f "$list_file" ]]; then
        log_error "Критический файл реестра инфраструктуры не найден: $list_file"
        return 1
    fi

    # Атомарная транзакция деплоя структуры файлов/папок
    begin_transaction
    init_backup

    if ! _deploy_manager "$list_file"; then
        log_error "Сбой обработки структуры файлов. Выполняю ROLLBACK."
        rollback_transaction
        return 1
    fi

    # Валидация через полиморфный метод приложения перед фиксацией
    if ! deploy_validate "$app_name"; then
        rollback_transaction
        return 1
    fi

    finalize_backup
    commit_transaction

    _deploy_control_services "$services_array_ref" || return 1
    log_ok ">>> [INSTALL] Компонент [${app_name^^}] успешно установлен и запущен <<<"
}

# 2. ФУНКЦИОНАЛ ВЫПОЛНЕНИЯ БЭКАПОВ КОНФИГУРАЦИИ
# не доработан
deploy_backup() {
    local app_name="$1"
    local config_dir="$2"

    log_info ">>> [BACKUP] Создание резервной копии конфигурации для: [${app_name^^}] <<<"
    check_root || return 1

    if [[ ! -d "$config_dir" ]]; then
        log_error "Каталог конфигурации не найден, бэкап невозможен: $config_dir"
        return 1
    fi

    # Вызов универсального движка бэкапов ядра системы
    if core_create_backup "$app_name" "$config_dir"; then
        log_ok ">>> [BACKUP] Резервная копия для [${app_name^^}] успешно сохранена <<<"
        return 0
    else
        log_error "Ошибка при архивации конфигурационных файлов."
        return 1
    fi
}

# 3. ФУНКЦИОНАЛ ОБНОВЛЕНИЯ КОНФИГУРАЦИИ
# не доработан
deploy_update_config() {
    local app_name="$1"
    local dest_config_file="$2"
    local new_config_source="$3"
    local services_array_ref="$4"

    log_info ">>> [UPDATE-CONFIG] Обновление конфигурации для: [${app_name^^}] <<<"
    check_root || return 1

    if [[ ! -f "$new_config_source" ]]; then
        log_error "Новый файл конфигурации-источника не найден: $new_config_source"
        return 1
    fi

    # Шаг А: Автоматическое создание превентивной точки отката (Rollback-бэкап)
    log_info "Создание превентивной точки отката перед обновлением файлов..."
    begin_transaction
    init_backup

    if [[ -f "$dest_config_file" ]]; then
        add_to_staging "$dest_config_file"
    fi

    # Шаг Б: Замена конфигурационного файла
    log_info "Применение нового конфигурационного файла: $dest_config_file"
    mkdir -p "$(dirname "$dest_config_file")"
    if ! cp -f "$new_config_source" "$dest_config_file"; then
        log_error "Не удалось скопировать новый конфигурационный файл. Отмена."
        rollback_transaction
        return 1
    fi

    # Шаг В: Валидация синтаксиса ДО применения изменений
    if ! deploy_validate "$app_name"; then
        log_error "Новый конфигурационный файл содержит синтаксические ошибки! Выполняю ROLLBACK."
        rollback_transaction
        return 1
    fi

    # Шаг Г: Фиксация изменений и перезапуск демонов
    finalize_backup
    commit_transaction

    _deploy_control_services "$services_array_ref" || return 1
    log_ok ">>> [UPDATE-CONFIG] Конфигурация [${app_name^^}] успешно обновлена <<<"
}

# 4. ФУНКЦИОНАЛ ОБНОВЛЕНИЯ ПРИЛОЖЕНИЯ
deploy_update_app() {
    local app_name="$1"
    local packages="$2"
    local list_file="$3"
    local services_array_ref="$4"

    log_info ">>> [UPDATE] Начало обновления компонента: [${app_name^^}] <<<"
    check_root || return 1

    log_info "--- Обновление бинарных пакетов и зависимостей ---"
    update_list "${packages}" || return 1

    if [[ ! -f "$list_file" ]]; then
        log_error "Критический файл реестра инфраструктуры не найден: $list_file"
        return 1
    fi

    # Атомарная транзакция деплоя структуры файлов/папок
    begin_transaction
    init_backup

    if ! _deploy_manager "$list_file"; then
        log_error "Сбой обработки структуры файлов. Выполняю ROLLBACK."
        rollback_transaction
        return 1
    fi

    # Валидация через полиморфный метод приложения перед фиксацией
    if ! deploy_validate "$app_name"; then
        rollback_transaction
        return 1
    fi

    finalize_backup
    commit_transaction

    _deploy_control_services "$services_array_ref" || return 1
    log_ok ">>> [INSTALL] Компонент [${app_name^^}] успешно установлен и запущен <<<"
}

# 5. ФУНКЦИОНАЛ ВАЛИДАЦИИ КОНФИГУРАЦИИ (ПОЛИМОРФНЫЙ ДИСПЕТЧЕР)
deploy_validate() {
    local app_name="$1"
    
    # Динамический поиск кастомного метода валидации синтаксиса внутри модуля приложения
    local validate_callback="${app_name}_validate"
    
    log_info "--- Запуск верификации конфигурационных файлов [${app_name^^}] ---"
    if declare -f "$validate_callback" >/dev/null; then
        if "$validate_callback"; then
            log_ok "Валидация синтаксиса для [${app_name}] завершена успешно."
            return 0
        else
            log_error "Критическая ошибка синтаксиса! Проверка через ${validate_callback} провалена."
            return 1
        fi
    else
        log_warn "Кастомная функция проверки синтаксиса (${validate_callback}) не объявлена. Тест пропущен."
        return 0
    fi
}

# 6. ФУНКЦИОНАЛ УДАЛЕНИЯ ПРИЛОЖЕНИЯ И КОНФИГУРАЦИИ
deploy_uninstall() {
    local app_name="$1"
    local packages="$2"
    local list_file="$3"
    # Локальный ассоциативный массив для быстрой дедупликации
    local -A processed_paths=()
    # Локальный индексированный массив для сохранения хронологического порядка путей
    local -a dest_list=()

    log_info ">>> [UNINSTALL] Деинсталляция и полная очистка приложения: [${app_name^^}] <<<"
    check_root || return 1

    # Полная остановка и деактивация всех связанных служб
    log_info "--- Остановка системных демонов и служб ---"
    # Извлекаем имена служб на основе переданных пакетов (упрощенно)
    for pkg in ${packages}; do
        systemctl disable --now "$pkg" 2>&1 | log_debug || true
    done

    log_info "--- Удаление бинарных пакетов и зависимостей (Purge) ---"
    uninstall_list "${packages}" || return 1

    if [[ ! -f "$list_file" ]]; then
        log_error "Критический файл реестра инфраструктуры не найден: $list_file"
        return 1
    fi

    log_info "--- Удаление остаточных файлов конфигураций и логов ---"

    while IFS='|' read -r type tpl dest mode owner dep attr desc vars || [[ -n "$type" ]]; do
        # Высокоскоростное удаление пробелов из поля типа
        type="${type##+([[:space:]])}"; type="${type%%+([[:space:]])}"
        
        # Пропускаем пустые строки и комментарии
        [[ -z "$type" || "$type" =~ ^# ]] && continue

        # Высокоскоростное очищение только поля dest (остальные поля нам не нужны)
        dest="${dest##+([[:space:]])}"; dest="${dest%%+([[:space:]])}"
        
        # Защита от дублирования путей в рамках одной сессии
        if [[ -n "${processed_paths[$dest]:-}" ]]; then
            log_warn "В реестре обнаружен дублирующийся путь назначения: [$dest]. Пропускаем дубль."
            continue
        fi
        
        # Фиксируем путь как обработанный и добавляем в итоговый список
        processed_paths["$dest"]=1
        dest_list+=("$dest")

    done < "$list_file"
    
    # Обходим список и удаляем
    for path in "${dest_list[@]}"; do
       if [[ -e "$path" ]]; then
            rm -rfv "$path" 2>&1 | log_debug
            log_info "Удалено физическое расположение: $path"
        fi
    done
    
    log_ok ">>> [UNINSTALL] Приложение [${app_name^^}] и все его данные полностью удалены <<<"
}
