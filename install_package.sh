#!/bin/bash

# Позиционные параметры
# Каждое слово после имени скрипта становится переменной:
# $0 — имя самого скрипта.
# $1 — первый аргумент.
# $2 — второй аргумент.
# $# — общее количество переданных аргументов.
# $* или $@ — все переданные аргументы одной строкой.

# --- ПАРАМЕТРЫ УСТАНОВКИ ---

PACKAGE=$1

# APP=$@
# ---------------------------

echo "--- Проверка прав суперпользователя ---"

if [ "$(id -u)" -ne 0 ]; then
    echo "[?] Ошибка. Скрипт запущен без прав суперпользователя"
    exit 1
fi

echo "[✓] Права суперпользователя проверены успешно"

echo "--- Обновление списка пакетов ---"

apt update -y
apt upgrade -y

echo "--- Получаем статус пакета: $PACKAGE ---"

# installed (установлен и обновлен), upgradeable (есть обновление), not-installed (не установлен)

STATUS=$(dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null | grep -q "ok installed" && \
         apt list --upgradable 2>/dev/null | grep -q "^$PACKAGE/" && echo "upgradeable" || \
        (dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null | grep -q "ok installed" && echo "installed" || echo "not-installed"))

echo "[✓] Статус пакета: $STATUS "

case "$STATUS" in
    "not-installed")
        echo "[+] $PACKAGE не обнаружен. Установка..."
        apt-get install -y $PACKAGE
	    if [ $? -ne 0 ]; then
            echo "[?] Ошибка при установке $PACKAGE."
            exit 1
    	fi
        echo "[✓] $PACKAGE установлен успешно."
	    exit 0
        ;;
    "upgradeable")
        echo "[!] Для $PACKAGE доступно обновление. Обновляю..."
        apt-get install --only-upgrade -y $PACKAGE
	    if [ $? -ne 0 ]; then
            echo "[?] Ошибка при обновлении $PACKAGE."
            exit 1
    	fi
        echo "[✓] $PACKAGE обновлен успешно."
        exit 0
	;;
    "installed")
        echo "[✓] $PACKAGE уже установлен и актуален. Пропуск."
        exit 0
	;;
    *)
        echo "[?] Ошибка определения статуса для $PACKAGE"
        echo "Пакет имеет статус: $STATUS "
        exit 1
	;;
esac
