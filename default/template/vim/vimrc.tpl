" ~/.vimrc - индивидуальные настройки Vim
" Автор: [Aleksandr]
" Last Modified: 2026-02-19

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
