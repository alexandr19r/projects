#!/bin/bash
# [transaction.sh] - Модуль атомарных изменений системы

[[ -n "${_TRANSACTION_SH_:-}" ]] && return 0
readonly _TRANSACTION_SH_=1

TRANSACTION_ACTIVE=false
# Пути синхронизированы с ROOT_DIR системы
: "${TRANSACTION_LOG:=${ROOT_DIR}/var/log/transaction.log}"
: "${STAGING_DIR:=${ROOT_DIR}/var/tmp/staging}"
: "${BACKUP_DIR:=${ROOT_DIR}/var/tmp/backup}"

begin_transaction() {
    log_info "=== ИНИЦИАЛИЗАЦИЯ ТРАНЗАКЦИИ ==="
    TRANSACTION_ACTIVE=true
    # Создаем структуру, если её нет
    mkdir -p "$STAGING_DIR" "$BACKUP_DIR" "$(dirname "$TRANSACTION_LOG")"
    # Очищаем старые следы (атомарно)
    rm -rf "${STAGING_DIR:?}"/* "${BACKUP_DIR:?}"/*
    : > "$TRANSACTION_LOG"
}

# Регистрация: тип(file/dir) | куда_ставим | откуда_взяли(опционально)
register_in_tx() {
    # Используем :- для защиты от пустых аргументов
    local type="${1:-}" 
    local dest="${2:-}" 
    local src="${3:-}"
    local stage_name="${dest//\//_}" # Безопасное имя файла
    
    # ЗАЩИТА: Если транзакция не была начата через begin_transaction, 
    # мы не имеем права писать в лог или staging.
    if [[ "${TRANSACTION_ACTIVE:-false}" != "true" ]]; then
        log_warn "Попытка регистрации в TX без активной транзакции ($dest). Пропуск."
        return 0
    fi

    case "$type" in
        "file")
            # Если файл существует — бэкапим оригинал для Rollback
            if [[ -f "$dest" ]]; then
                cp -p "$dest" "${BACKUP_DIR}/${stage_name}.bak"
                echo "update|$dest|${stage_name}.bak" >> "$TRANSACTION_LOG"
            else
                echo "new|$dest" >> "$TRANSACTION_LOG"
            fi
            # Если передали исходник — копируем его в staging
            [[ -n "$src" && -f "$src" ]] && cp -p "$src" "${STAGING_DIR}/${stage_name}.tmp"
            ;;
        "dir")
            echo "dir|$dest" >> "$TRANSACTION_LOG"
            ;;
    esac
}

rollback_transaction() {
    log_warn "!!! ОТКАТ ИЗМЕНЕНИЙ (ROLLBACK) !!!"
    [[ ! -f "$TRANSACTION_LOG" ]] && return 0

    # Разворот стека (LIFO) через sed, если нет tac
    local reverse_cmd=$(command -v tac || echo "sed -n '1!G;h;\$p'")
    
    $reverse_cmd "$TRANSACTION_LOG" | while IFS='|' read -r action dest extra; do
        case "$action" in
            "update")
                log_info "Восстановление оригинала: $dest"
                [ -e "$dest" ] && chattr -i "$dest" 2>/dev/null
                cp -p "${BACKUP_DIR}/$extra" "$dest"
                ;;
            "new"|"dir")
                log_info "Удаление созданного объекта: $dest"
                rm -rf "$dest"
                ;;
        esac
    done
    TRANSACTION_ACTIVE=false
    rm -f "$TRANSACTION_LOG"
}

commit_transaction() {
    log_info "=== ФИКСАЦИЯ ИЗМЕНЕНИЙ (COMMIT) ==="
    [[ ! -f "$TRANSACTION_LOG" ]] && return 0

    while IFS='|' read -r action dest extra; do
        local stage_file="${STAGING_DIR}/${dest//\//_}.tmp"
        
        if [[ -f "$stage_file" ]]; then
            # Снимаем защиту, если файл системный
            [ -e "$dest" ] && chattr -i "$dest" 2>/dev/null
            mkdir -p "$(dirname "$dest")"
            
            # Атомарное перемещение
            mv "$stage_file" "$dest"
            log_debug "Зафиксирован объект: $dest"
        fi
    done < "$TRANSACTION_LOG"

    TRANSACTION_ACTIVE=false
    # Финальная очистка
    rm -rf "$STAGING_DIR"/* "$BACKUP_DIR"/* "$TRANSACTION_LOG"
    log_ok "=== ТРАНЗАКЦИЯ ЗАВЕРШЕНА УСПЕШНО ==="
}