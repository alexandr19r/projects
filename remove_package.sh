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

echo "--- Получаем статус пакета: $PACKAGE ---"

# installed (установлен и обновлен), upgradeable (есть обновление), not-installed (не установлен)

STATUS=$(dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null | grep -q "ok installed" && \
         apt list --upgradable 2>/dev/null | grep -q "^$PACKAGE/" && echo "upgradeable" || \
        (dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null | grep -q "ok installed" && echo "installed" || echo "not-installed"))

echo "[✓] Статус пеката: $STATUS "

echo "--- Очистка установленных пакетов ---"

case "$STATUS" in
    "not-installed")
        echo "[✓] $PACKAGE не установлен."
	    exit 0
        ;;
    "upgradeable")
        echo "Удаление $PACKAGE"
        apt purge -y $PACKAGE
        apt autoremove -y
        echo "[✓] $PACKAGE удален успешно."
	    exit 0
	;;
    "installed")
        echo "Удаление $PACKAGE"
        apt purge -y $PACKAGE
        apt autoremove -y
        echo "[✓] $PACKAGE удален успешно."
	    exit 0
	;;
    *)
        echo "[?] Ошибка определения статуса для $PACKAGE."
        echo "Пакет имеет статус: $STATUS"
        exit 1
	;;
esac
