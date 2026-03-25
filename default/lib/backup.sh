#!/bin/bash
# [backup.sh] - Профессиональный модуль ротации и архивации

[[ -n "${_BACKUP_SH_}" ]] && return
readonly _BACKUP_SH_=1

# --- 1. Инициализация переменных ---
# Используем безопасную инициализацию с возможностью переопределения
# Мягкие дефолты: если в settings.conf пусто, берем эти значения
: "${PROJECT_NAME:=default}"

: "${BACKUP_ENABLE:=false}"
: "${BACKUP_DIST:=${ROOT_DIR}/var/backups}"
: "${BACKUP_COMPRESSION:=tar -I 'zstd -T0'}"
: "${BACKUP_EXT:=tar.zst}"
: "${BACKUP_KEEP_DAYS:=7}"

# Инициализация временной директории (атомарно)
# readonly BACKUP_TEMP="${BACKUP_TEMP:-$(mktemp -d -p "${ROOT_DIR}/var/tmp" tmp_dir.XXXXXXXXX)}"
# Временную директорию объявляем, но не создаем сразу
: "${BACKUP_TEMP:=""}"

# Автоматическая очистка временных данных при любом выходе из скрипта
# trap '[[ -d "$BACKUP_TEMP" ]] && rm -rf "$BACKUP_TEMP"' EXIT
# Очистка (улучшена проверка)
_cleanup_backup_tmp() {
    [[ -n "$BACKUP_TEMP" && -d "$BACKUP_TEMP" ]] && rm -rf "$BACKUP_TEMP"
}
trap _cleanup_backup_tmp EXIT

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

# --- 4. Инициализация работы модуля ---
init_backup() {
    log_info "=== ЗАПУСК BACKUP ==="

    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0

    # ЛОГИКА ОПРЕДЕЛЕНИЯ ПУТИ:
    if [[ -n "$BACKUP_TEMP" ]]; then
        # СИТУАЦИЯ А: Путь задан в settings.conf
        log_debug "Используется кастомный путь для временной дирректории: $BACKUP_TEMP"
        mkdir -p "$BACKUP_TEMP" || { log_error "Не удалось создать $BACKUP_TEMP"; return 1; }
    else
        # СИТУАЦИЯ Б: В settings.conf пусто, генерируем временный
        log_debug "Путь не задан, создаю временную директорию..."
        mkdir -p "${ROOT_DIR}/var/tmp"
        BACKUP_TEMP=$(mktemp -d -p "${ROOT_DIR}/var/tmp" backup_stage.XXXXXXXXX) || return 1
    fi
    
    # mkdir -p "${BACKUP_DIST}"
    # ЛОГИКА ОПРЕДЕЛЕНИЯ И СОЗДАНИЯ BACKUP_DIST:
    if [[ -d "$BACKUP_DIST" ]]; then
        log_debug "Используется существующее хранилище бэкапов: $BACKUP_DIST"
    else
        log_info "Создание целевой директории бэкапов: $BACKUP_DIST"
        # -p гарантирует создание всей цепочки папок и не выдает ошибку, если путь уже есть
        if ! mkdir -p "$BACKUP_DIST" 2>/dev/null; then
            log_error "Критическая ошибка: невозможно создать директорию $BACKUP_DIST (проверьте права)"
            return 1
        fi
    fi

    # Проверка на доступность записи (важно для внешних монтирований/NFS)
    if [[ ! -w "$BACKUP_DIST" ]]; then
        log_error "Ошибка: Директория $BACKUP_DIST защищена от записи!"
        return 1
    fi

    # Настраиваем архивирующую утилиту
    _init_backup_compression

    log_info "=== Инициализация бэкапа завершена ==="
}

# --- 5. Постепенное добавление файлов ---
# Функция принимает путь к файлу или директории
add_to_staging() {
    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0

    # local source_item="$1"
    # Преобразуем в абсолютный путь для корректной работы --parents
    local source_item=$(readlink -f "$1")

    if [[ ! -e "$source_item" ]]; then
        log_warn "Объект не найден: $source_item. Пропуск."
        return 1
    fi

    log_info "Добавление в набор: $source_item"

    # --parents: воссоздает полную структуру путей внутри BACKUP_TEMP
    # --archive (-a): сохраняет права, владельца, время и символьные ссылки
    # if ! cp --archive --parents "$source_item" "$BACKUP_TEMP/"; then
    #    log_error "Ошибка при копировании $source_item во временный каталог."
    #    return 1
    # fi
    # Копируем в BACKUP_TEMP, сохраняя структуру
    if cp -a --parents "$source_item" "$BACKUP_TEMP/"; then
        return 0
    else
        log_error "Ошибка копирования $source_item"
        return 1
    fi

}

# --- 6. Финализация и архивирование ---
finalize_backup() {
    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0

    local timestamp=$(date +%Y%m%d%H%M%S)
    # Путь вида: /var/backups/project_name
    local target_dir="${BACKUP_DIST}/${PROJECT_NAME}"
    # Файл вида: backup_20260109172135.$BACKUP_EXT
    local archive_file="${target_dir}/backup_${timestamp}.${BACKUP_EXT}"

    # Создаем папку, если её нет
    log_info "Создание целевой директории: $target_dir"
    mkdir -p "$target_dir"

    # Проверка на наличие данных (более быстрый способ через find)
    if [[ -z $(find "$BACKUP_TEMP" -mindepth 1 -print -quit) ]]; then
        log_warn "Временный каталог пуст. Бэкап не будет создан."
        return 1
    fi

    log_info "Архивирование в: $archive_file"

    # Используем подоболочку (subshell) для смены директории, чтобы не менять $PWD скрипта
    # ВАЖНО: переменная BACKUP_COMPRESSION должна содержать команду целиком (напр. "tar -cz")
    # Поэтому вызываем её как $BACKUP_COMPRESSION, а не tar $BACKUP_COMPRESSION
    if (cd "$BACKUP_TEMP" && $BACKUP_COMPRESSION -cf "$archive_file" .); then
        chmod 600 "$archive_file"
        log_ok "Бэкап успешно создан."
    else
        log_error "Ошибка при создании архива."
        return 1
    fi
}

# --- 7. Удаление старых версий бэкапов ---
cleanup_old_backups() {
    # Проверяем, разрешен ли бэкап в настройках
    _check_backup_status || return 0
    
    local target_dir="${BACKUP_DIST}/${PROJECT_NAME}"
    
    # Если папки нет (первый запуск), удалять нечего
    [[ ! -d "$target_dir" ]] && return 0

    log_info "Ротация: поиск архивов старше ${BACKUP_KEEP_DAYS} дней..."
    
    # Исправлен -type f и добавлена защита от ошибок find
    local deleted_files
    deleted_files=$(find "$target_dir" -type f -name "backup_*" -mtime +"${BACKUP_KEEP_DAYS}" -print)
    
    if [[ -n "$deleted_files" ]]; then
        echo "$deleted_files" | xargs rm -f
        local count=$(echo "$deleted_files" | wc -l)
        log_ok "Ротация завершена. Удалено копий: $count"
    else
        log_info "Устаревших бэкапов не обнаружено."
    fi
}

