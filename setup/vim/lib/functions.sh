# Файл: functions.sh

# Функция для получения пути к папке скрипта
get_script_dir() {
    # 1. Получаем путь к самому файлу скрипта
    local SOURCE="$1"
    
    # 2. Обрабатываем ситуацию, если скрипт является симлинком (цепочкой ссылок)
    while [ -L "$SOURCE" ]; do
        local DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        # Если ссылка относительная, нужно разрешить её относительно DIR
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    
    # 3. Вычисляем финальный абсолютный путь
    echo "$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
}
# Подключаем конфиг (проверяем существование файла)
# SCRIPT_DIR=$(get_script_dir ${BASH_SOURCE[0]})
# CONFIG_FILE="$SCRIPT_DIR/config/settings.conf"

# Функция проверки папки
check_dir() {
    if [[ -d "$1" ]]; then
        echo "[OK] Папка $1 найдена."
        return 0
    else
        echo "[ERROR] Папка $1 отсутствует."
        return 1
    fi
}

# Функция для логов с датой
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Функция проверяет существование папки и создает при необходимости
# В случае ошибки прерывает выполнение
ensure_dir_exists () {
    
    local dir_path=$1
    
    if [ check_dir $dir_path ]; then
        echo "Папка '$dir_path' уже существует"
        return 0
    fi

    echo "Папка '$dir_path' не найдена. Создаю..."
    mkdir -p "$dir_path"


    if [[ $? -eq 0 ]]; then
        echo "Папка '$dir_path' успешно создана"
        return 0
    else
        echo "Не удалось создать папку '$dir_path'"
        return 1
    fi
}

# Проверка прав суперпользователя
check_root () {
    if [[ "$EUID" -ne 0 ]]; then
        return 1 
    fi
    return 0
}
