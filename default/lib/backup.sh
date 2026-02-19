#!/bin/bash
# [backup.sh] - Профессиональный модуль ротации и архивации

[[ -n "${_BACKUP_SH_}" ]] && return
readonly _BACKUP_SH_=1

# --- 1. Инициализация переменных ---
# Используем безопасную инициализацию с возможностью переопределения
BACKUP_ENABLE="${BACKUP_ENABLE:-false}"
PROJECT_NAME="${PROJECT_NAME:-default}"
readonly BACKUP_DIST="${BACKUP_DIST:-${ROOT_DIR}/var/backups}"
BACKUP_COMPRESSION="${BACKUP_COMPRESSION:-tar -I 'zstd -T0'}"
BACKUP_EXT="{BACKUP_EXT:-tar.zst}"
BACKUP_KEEP_DAYS=7

# Инициализация временной директории (атомарно)
readonly BACKUP_TEMP="${BACKUP_TEMP:-$(mktemp -d -p "${ROT_DIR}/var/tmp" tmp_dir.XXXXXXXXX)}"

# Автоматическая очистка временных данных при любом выходе из скрипта
trap '[[ -d "$BACKUP_TEMP" ]] && rm -rf "$BACKUP_TEMP"' EXIT

# --- 2. Проверка состояния ---
_check_backup_status() {
    if [[ "$BACKUP_ENABLE" != "true" ]]; then
        log_warn "Модуль бэкапа отключен (BACKUP_ENABLE=$BACKUP_ENABLE). Пропуск."
        return 1
    fi

    log_debug "Модуль бэкапа готов. Проект: $PROJECT_NAME"
}

# --- 3. Функция проверяет возможность использования архиватора или устанавливает стандартный ---
_init_backup_compression() {
    local use_fallback=false
    # 1. Извлекаем имя самой утилиты (первое слово)
    local archiver_cmd=$(echo "$BACKUP_COMPRESSION" | awk '{print $1}')

    # 2. Проверяем наличие бинарного файла в системе
    if ! command -v "$archiver_cmd" &> /dev/null; then
        log_warn "Архиватор '$archiver_cmd' не найден в системе."
        use_fallback=true
    fi

    # 3. Тестовый запуск: пробуем создать пустой архив с заданными параметрами
    if [ "$use_fallback" != true ]; then
        # Создаем временный пустой файл для теста
        local test_file=$(mktemp)
        local test_archive=$(mktemp --suffix=."${BACKUP_EXT#.}")

        # Пытаемся сжать этот файл
        if ! $BACKUP_COMPRESSION -cf "$test_archive" "$test_file" &> /dev/null; then
            log_warn "Связка '$BACKUP_COMPRESSION' + '.$BACKUP_EXT' не работает (ошибка флагов)."
            use_fallback=true
        fi

        # Удаляем временные файлы
        rm -f "$test_file" "$test_archive"
    fi

    # 4. Если проверка провалилась — включаем безопасный режим (gzip)
    if [ "$use_fallback" = true ]; then
        log_info "Переключаюсь на стандартный gzip: tar -cz"
        BACKUP_COMPRESSION="tar -cz"
        BACKUP_EXT="tar.gz"
    fi
}

# --- 4. Постепенное добавление файлов ---
# Функция принимает путь к файлу или директории
add_to_staging() {
    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0

    local source_item="$1"

    if [[ ! -e "$source_item" ]]; then
        log_warn "Объект не найден: $source_item. Пропуск."
        return 1
    fi

    log_info "Добавление в набор: $source_item"

    # --parents: воссоздает полную структуру путей внутри BACKUP_TEMP
    # --archive (-a): сохраняет права, владельца, время и символьные ссылки
    if ! cp --archive --parents "$source_item" "$BACKUP_TEMP/"; then
        log_error "Ошибка при копировании $source_item во временный каталог."
        return 1
    fi
}

# --- 5. Финализация и архивирование ---
finalize_backup() {
    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0

    local timestamp=$(date +%Y%m%d%H%M%S)
    # Путь вида: /var/backups/project_name
    local target_dir="${BACKUP_DIST}/${PROJECT_NAME}"
    # Файл вида: backup_20260109172135.$BACKUP_EXT
    local archive_file="${target_dir}/backup_${timestamp}.${BACKUP_EXT}"

    log_info "Создание целевой директории: $target_dir"
    mkdir -p "$target_dir"

    # Проверка на наличие данных в staging
    if [[ -z "$(ls -A "$BACKUP_TEMP")" ]]; then
        log_warn "Временный каталог пуст. Бэкап не будет создан."
        return 1
    fi

    log_info "Архивирование с сохранением прав и путей..."

    # Переходим в корень backup_temp, чтобы пути в архиве начинались правильно
    # Используем BACKUP_COMPRESSION для архивации
    if (cd "$BACKUP_TEMP" && tar $BACKUP_COMPRESSION -cf "$archive_file" .); then
        log_ok "Бэкап завершен успешно: $archive_file"
        # Устанавливаем строгие права на архив
        chmod 600 "$archive_file"
    else
        log_error "Критическая ошибка при архивации."
        return 1
    fi
}

# --- 6. Инициализация работы модуля ---
init_backup() {
    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0

    # Настраиваем архивирующую утилиту
    _init_backup_compression

    mkdir -p "${BACKUP_DIST}"
    mkdir -p "${BACKUP_TEMP}"

    # Набираем файлы (постепенно)
    # add_to_staging "/etc/hosts"
    # add_to_staging "/var/www/html/config"
    # add_to_staging "$HOME/.ssh/config"

    # Финализируем процесс
    # finalize_backup

    # Очищаем устаревшие версии
    # cleanup_old_backup
}

# --- 7. Удаление старых версий бэкапов ---
cleanup_old_backups() {
    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0

    log_info "Поиск старых архивов (старше ${BACKUP_KEEP_DAYS} дней)..."
    local deleted_count=$(find "${BACKUP_DIST}/${PROJECT_NAME}" type f -name "backup_*" -mtime +"${BACKUP_KEEP_DAYS}" -delete -print | wc -l)

    if [[ $deleted_count -gt 0 ]]; then
        log_ok "Удалено старых копий: $deleted_count"
    else
        log_info "Старых копий для удаления не найдено."
    fi
}

# Инициализация (вызов)
init_backup
log_info "--- Backup успешно инициализирован. ---"
