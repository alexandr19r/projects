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

# Создаем конфигурационный файл
deploy_vim_config() {

    cat << 'VIMRC' > ~/.vimrc
    " --- ОСНОВНЫЕ НАСТРОЙКИ ---
    syntax on            " Включить подсветку синтаксиса
    set number           " Показывать номера строк
    "set relativenumber   " Относительные номера (удобно для прыжков по коду)
    set cursorline       " Подсветка строки, на которой находится курсор
    set showmatch        " Подсвечивать парные скобки
    set visualbell       " Использовать визуальный сигнал вместо звукового
    set laststatus=2     " Всегда показывать статусную строку
    set termguicolors    " Поддержка 24-битных цветов (TrueColors)

    " --- ТАБУЛЯЦИЯ И ОТСТУПЫ ---
    set tabstop=4        " Ширина таба — 4 пробела
    set shiftwidth=4     " Ширина автоотступа
    set expandtab        " Превращать табы в пробелы
    set smarttab         " Умная работа с табами
    set autoindent       " Автоматический отступ
    set smartindent      " Умный отступ для кода
    set backspace=indent,eol,start  " Разрешить Backspace везде

    " --- ПОИСК ---
    set hlsearch         " Подсвечивать совпадения при поиске
    set incsearch        " Поиск по мере ввода
    set ignorecase       " Игнорировать регистр при поиске
    set smartcase        " Но учитывать регистр, если есть заглавные буквы

    " --- СИСТЕМНЫЕ НАСТРОЙКИ ---
    set encoding=utf-8          " Кодировка внутри Vim
    set fileencoding=utf-8      " Кодировка сохраняемого файла
    set noswapfile              " Не создавать .swp файлы (бесят в папках проекта)
    set nobackup                " Не создавать бекап-файлы
    set undofile                " Сохранять историю изменений даже после закрытия файла
    set undodir=~/.vim/undodir  " Директория для истории изменений
    set mouse=a                 " Включить поддержку мыши во всех режимах
    set hidden                  " Разрешить переключение между буферами без сохранения

    " --- ГОРЯЧИЕ КЛАВИШИ ---
    " Лидер-клавиша (основной модификатор для своих команд)
    "let mapleader = " "

    " Быстрое сохранение и выход
    "nnoremap <leader>w :w<CR>
    "nnoremap <leader>q :q<CR>

    " Очистка подсветки поиска нажатием Esc
    "nnoremap <esc> :noh<return><esc>

    " Навигация между окнами (разрезами экрана) через Ctrl + стрелки
    "nnoremap <C-Left> <C-W>h
    "nnoremap <C-Down> <C-W>j
    "nnoremap <C-Up> <C-W>k
    "nnoremap <C-Right> <C-W>l

    " Перемещение блоков текста в визуальном режиме (как в IDE)
    "vnoremap J :m '>+1<CR>gv=gv
    "vnoremap K :m '<-2<CR>gv=gv

    " --- ГОРЯЧИЕ КЛАВИШИ (Windows-style) ---
    " Ctrl + S для сохранения (нужно stty -ixon в bashrc)
    "nmap <C-s> :w<CR>
    "imap <C-s> <Esc>:w<CR>a

    " Ctrl + Z для отмены
    "nmap <C-z> u
    "imap <C-z> <Esc>u

    " Копирование/Вставка через системный буфер (если есть xclip)
    "vmap <C-c> "+y
    "nmap <C-v> "+p
    "imap <C-v> <Esc>"+pa

    " --- СТАТУСНАЯ СТРОКА (ИНФО-ПАНЕЛЬ) ---
    set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]
    set statusline+=\ %{mode()}

    " --- Нижняя панель с подсказками клавиш ---
    set showmode
    set cmdheight=2

    " --- Вывод подсказки в командной строке при запуске ---
    autocmd VimEnter * echo "ГОРЯЧИЕ КЛАВИШИ: :w - сохр | :q - выход | i - режим ввода | Esc - режим команд | u - отмена | / - поиск"

VIMRC
}

# Далее код может использовать функции ядра, например log_info
main_vim() {
    
    

    #echo "--- Проверка наличия прав root ---"

    #if ! check_root; then
    #    echo "[?] Ошибка прав доступа"
    #fi

    log_info "--- Устанавливаем полную версию vim ---"

    # Устанавливаем полную версию vim (в Debian часто стоит vim-tiny без подсветки)
    install_package $PROJECT_NAME

    log_info "--- Создаем backup текущей конфигурации ~/.vimrc ---"
    add_to_staging ~/.vimrc
    finalize_backup
 
    log_info "--- Создаем новый файл конфигурации ~/.vimrc ---"
    #deploy_vim_config
    envsubst < "${ROOT_DIR}/template/vim/vimrc.tpl" > ~/.vimrc

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