#!/bin/bash
# Главный файл приложения

# 1. Инициализация ядра lib/core.sh
# Инициализация всей системы одной строкой
# source "$(dirname "$0")/lib/core.sh"
CORE_FILE="$(dirname "$0")/lib/core.sh"
if [[ -f "$CORE_FILE" ]]; then
    source "$CORE_FILE"
else
    echo "Ошибка: Ядро системы не найдено в $CORE_FILE" && exit 1
fi

# Пример изменения настроек логгера
DEBUG_MODE=true # Теперь log_debug будут видны
LOG_TO_FILE=true
#LOG_FILE="${HOME}/.backup.log"

# Загрузка зависимостей
import_lib "utils"
import_config "settings"
# import_config "backup"
# import_lib "backup"
# import_lib "network_tools"

main() {
    log_info "Начало работы программы..."
    
    log_debug "Проверка системных путей: $ROOT_DIR"
    
    if [[ -d "$HOME" ]]; then
        log_ok "Домашняя директория доступна."
    else
        log_error "Домашняя директория не найдена!"
        return 1
    fi

    log_info "=== ЗАПУСК ПЛАНОВОГО РЕЗЕРВНОГО КОПИРОВАНИЯ ==="
    
    # Проверка установленных утилит (zstd)
    if ! command -v zstd &> /dev/null; then
        log_warn "Утилита zstd не найдена. Переключаюсь на gzip."
        COMPRESSION_CMD="tar -cz"
        EXTENSION="tar.gz"
    fi

    # Выполнение задач
    create_archive || exit 1
    cleanup_old_backups
    
    log_ok "Процесс завершен успешно."

    log_info "Все операции завершены успешно."

#=========

    log_info "=== ЗАПУСК УМНОГО БЕКАПА (2025) ==="
    
    # 1. Проверка прав (если бекапим системные конфиги)
    check_root

    # 2. Подготовка файлов во временном каталоге
    # Если изменений нет — выходим красиво
    if ! prepare_staging; then
        log_info "Завершение работы: нечего бекапить."
        exit 0
    fi

    # 3. Архивация
    archive_staging || exit 1

    # 4. Очистка старых копий
    cleanup_old_backups
    
    log_ok "Бэкап успешно завершен."


}

main "$@"
