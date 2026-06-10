#!/bin/bash
# [vim.sh] файл установки редактора vim

# Инициализация переменных проекта
PROJECT_NAME="vim"
PACKAGES="vim"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
# см. [nftables.env]

# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

main_vim() {
    
    log_info ">>> НАЧАЛО РАЗВЕРТЫВАНИЯ VIM  <<<-"
    
    # --- ОБРАБОТКА АРГУМЕНТОВ ---
    local TARGET_USER=""
    export DRY_RUN=false # Значение по умолчанию

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user) TARGET_USER="$2"; shift 2 ;;
            --dry-run) export DRY_RUN=true; shift ;;
            *) shift ;;
        esac
    done

    # Определяем пользователя: из аргумента или текущий (SUDO_USER или USER)
    export USER_NAME="${TARGET_USER:-${SUDO_USER:-$USER}}"
    export USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "!!! РЕЖИМ DRY-RUN: ИЗМЕНЕНИЯ В СИСТЕМУ ВНЕСЕНЫ НЕ БУДУТ !!!"
    fi

    # Проверка прав и зависимостей
    log_info "--- Проверка наличия прав root ---"
    check_root || return 1

    # Загружаем переменные окружения
    log_info "--- Загрузка переменных из настроек приложения ---"
    load_env "vim/vim"

    # Установка пакета
    log_info "--- Установка редактора (vim) и зависимостей ---"
    install_list "${PACKAGES}" || return 1
    
    # Запуск начала транзакции
    begin_transaction
    
    # Инициализируем модуль бэкапа (создаем временные папки)
    init_backup

    # Загрузка списка инфраструктуры vim
    local vim_list
    vim_list="${ROOT_DIR}/config/vim/vim.list"

    # Поверяем корректность загрузки списка инфраструктуры vim
    if [[ ! -f "$vim_list" ]]; then
        log_warn "Реестр $vim_list не найден, бэкап конфигураций пропущен."
        return 1
    fi

    # Читаем только строки с типом 'file', извлекаем путь (3-я колонка)
    # Добавляем в бэкап все файлы, которые прописаны в массиве как цели (dest_path)
    local files_to_back
    files_to_back=$(grep -vE '^(#|$)' "$vim_list" | awk '$1 == "file" {print $3}')

    log_info "--- Создаем backup версию ---"
    for file_path in $files_to_back; do
        if [[ -f "$file_path" ]]; then
            log_debug "Добавление в бэкап: $file_path"
            add_to_staging "$file_path"
        fi
    done
    
    # Читаем реестр и вызываем add_item для каждой строки
    log_info "--- Настройка инфраструктуры VIM ---"
    grep -vE '^(#|$)' "$vim_list" | while read -r type tpl dest mode owner dep attr desc vars; do
        if ! add_item "$type" "$tpl" "$dest" "$mode" "$owner" "$dep" "$attr" "$desc" "$vars"; then
            log_error "Сбой при настройке: $desc"
            rollback_transaction
            return 1
        fi
    done || return 1 # Выход из main если цикл вернул ошибку
 
    # --- ВАЛИДАЦИЯ VIM ---
    log_info "Валидация конфигурации Vim..."

    # Проверка синтаксиса vim перед фиксацией (Commit)
    local HAS_ERROR=false
    local tmp_vimrc=$(eval echo "$USER_HOME/.vimrc")

    # Проверка синтаксиса (Vim загружает конфиг и выходит)
    # Используем -u NONE -S для проверки только что созданного конфига
    if ! vim -u "$tmp_vimrc" -e -c "q" >/dev/null 2>&1; then
        log_error "Синтаксическая ошибка в сгенерированном .vimrc"
        HAS_ERROR=true
    fi

    # --- ОТКАТ ТРАНЗАКЦИИ ---
    if [[ "$HAS_ERROR" == "true" ]]; then
        log_error "Тестирование провалено. Инициирую ROLLBACK..."
        # Выполняем откат изменений
        rollback_transaction
        return 1
    fi

    log_ok "Все тесты пройдены. Фиксация изменений..."
    # Финализируем бекап
    finalize_backup
    # Применяем изменения
    commit_transaction

    # Отключаем заморозку терминала по Ctrl+S для корректной работы сохранения
    #if ! grep -q "stty -ixon" ~/.bashrc; then
    #    echo "stty -ixon" >> ~/.bashrc
    #fi

    log_info "--- Перезапускаем терминал 'source ~/.bashrc'."
    source ~/.bashrc

    log_info "Настройка завершена!"

}

main_vim "$@"