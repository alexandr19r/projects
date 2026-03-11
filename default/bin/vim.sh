#!/bin/bash
# [vim.sh] файл установки редактора vim

# Инициализация переменных
PROJECT_NAME="vim"

# Инициализируем ядро системы lib/core.sh
# source "$(dirname "$0")/lib/core.sh"
# Профессиональное безопасное подключение без переменных
#if ! source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/core.sh" 2>/dev/null; then
#    printf "\033[0;31m[CRITICAL]\033[0m Core system failure: Cannot locate or load kernel from source.\n" >&2
#    exit 1
#fi
# Профессиональный стандарт 2026 с использование readlink -f
# shellcheck source=../lib/core.sh
if ! source "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")/lib/core.sh" 2>/dev/null; then
    printf "\033[0;31m[FATAL]\033[0m Ядро системы не найдено в корне проекта..\n" >&2
    exit 1
fi

# Далее код может использовать функции ядра, например log_info
main_vim() {

    log_info "--- Проверка наличия прав root ---"

    check_root || return 1

    log_info "--- Устанавливаем полную версию vim ---"

    # Устанавливаем полную версию vim (в Debian часто стоит vim-tiny без подсветки)
    install_package $PROJECT_NAME

    log_info "--- Создаем backup текущей конфигурации ~/.vimrc ---"
    add_to_staging ~/.vimrc
    finalize_backup
 
    log_info "--- Создаем новый файл конфигурации ~/.vimrc ---"
    #deploy_vim_config
    export AUTHOR=$(id -un) #Имя текущего пользователя системы
    export LAST_MODIFIED=$(date '+%Y-%m-%d') #Текущая дата изменения
    #envsubst '$AUTHOR $LAST_MODIFIED' < "${ROOT_DIR}/template/vim/vimrc.tpl" > "$HOME/.vimrc"
    update_configs \
        "${ROOT_DIR}/template/vim/vimrc.tpl" \
        "$HOME/.vimrc" \
        "AUTHOR|LAST_MODIFIED"  # Список переменных через ИЛИ

    log_info "--- Устанавливаем права доступа ---"
    chmod 644 ~/.vimrc

    # Отключаем заморозку терминала по Ctrl+S для корректной работы сохранения
    #if ! grep -q "stty -ixon" ~/.bashrc; then
    #    echo "stty -ixon" >> ~/.bashrc
    #fi

    log_info "--- Перезапускаем терминал 'source ~/.bashrc'."
    source ~/.bashrc

    log_info "Настройка завершена!"

}

main_vim "$@"