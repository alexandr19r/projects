#!/bin/bash

# Определяем путь к папке со скриптом
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
echo $SCRIPT_DIR

exit 1

# Подключаем конфиг (проверяем существование файла)
CONFIG_FILE="$SCRIPT_DIR/config/settings.conf"


PACKAGE="nano"

# 1. Проверяем, установлена ли вообще
if ! dpkg -s "$PACKAGE" &> /dev/null; then
    echo "Пакет $PACKAGE не установлен. Обновление невозможно."
    exit 1
fi

# 2. Проверяем наличие обновлений в репозитории
# Обновляем кэш (требуются права sudo)
# sudo apt update -y &> /dev/null 

# Сравниваем установленную версию с версией в кандидатах на установку
INSTALLED_VER=$(dpkg-query -W -f='${Version}' "$PACKAGE")
CANDIDATE_VER=$(apt-cache policy "$PACKAGE" | grep "Candidate" | awk '{print $2}')

if [ "$INSTALLED_VER" == "$CANDIDATE_VER" ]; then
    echo "Программа $PACKAGE актуальна (версия $INSTALLED_VER)."
else
    echo "Доступно обновление для $PACKAGE!"
    echo "Установлено: $INSTALLED_VER"
    echo "Доступно:    $CANDIDATE_VER"
fi
