#!/bin/bash
# [bind.sh] файл установки редактора bind9

# Инициализация переменных
PROJECT_NAME="bind9"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
export YOUR_DOMAIN="home.local"         # Ваш локальный домен (например, corp.local)
export YOUR_SERVER_IP="10.10.100.1"     # IP-адрес вашего сервера
export YOUR_NETWORK="10.10.100.0/24"    # Ваша локальная сеть (например, 192.168.1.0/24)
export YOUR_REVERSE_OCTET="100.10.10"   # Обратный порядок октетов сети (например, 1.168.192 для 192.168.1.x)
export YOUR_NETWORK_V6="fd00:0db9:aaaa::/64" # Ваша локальная сеть IPv6 (например, fd00:0db9:aaaa::/64)
export YOUR_REVERSE_V6_OCTET="a.a.a.a.9.b.d.0.0.0.d.f" # Обратный порядок октетов сети IPv6 (например, a.a.a.a.9.b.d.0.0.0.c.f для fc00:0db9:aaaa::/48)
export FORWARDER_DNS1="8.8.8.8"         # Внешний DNS 1 (Google DNS)
export FORWARDER_DNS2="8.8.4.4"         # Внешний DNS 2
#FOLDER_RELEASE="release"         # Папка для текущей конфигурации
#FOLDER_BACKUP="backup"           # Папка для backup
export AUTHOR=$(id -un) #Имя текущего пользователя системы
export LAST_MODIFIED=$(date '+%Y-%m-%d') #Текущая дата изменения
# --- ФОРМИРОВАНИЕ СЕРИЙНОГО НОМЕРА ВЕРСИИ ---
# Серийный номер версии файлов зон
export SERIALNUMBER=$(get_next_serial "/etc/bind/zones/db.localhost")
# Извлекаем последний октет IP для PTR записи
export LAST_OCTET=$(echo "$YOUR_SERVER_IP" | cut -d. -f4)
# Хостовая часть (для PTR конкретного сервера ::1)
# Это 16 нибблов (64 бита) в обратном порядке
export LAST_OCTET_V6="1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0" # ------------------------------

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

# Функция отключения служб
disable_dns_managers() {
    log_info "--- Отключение системных менеджеров DNS ---"

    # 1. Останавливаем и маскируем systemd-resolved (самый частый виновник)
    if systemctl is-active --quiet systemd-resolved; then
        log_info "Остановка systemd-resolved..."
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        systemctl mask systemd-resolved # Маскировка защищает от случайного запуска
    fi

    # 2. Удаляем пакет resolvconf, если он установлен
    if dpkg -l | grep -q "^ii  resolvconf"; then
        log_info "Удаление пакета resolvconf..."
        apt-get purge -y resolvconf
    fi

    # 3. Если используется NetworkManager, запрещаем ему трогать resolv.conf
    if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
        log_info "Настройка NetworkManager: main.dns=none"
        sed -i '/\[main\]/a dns=none' /etc/NetworkManager/NetworkManager.conf
        systemctl reload NetworkManager 2>/dev/null
    fi

    # 4. Удаляем символическую ссылку (если resolv.conf указывает на /run/...)
    # Это критично: часто /etc/resolv.conf — это просто ссылка
    if [ -L /etc/resolv.conf ]; then
        log_info "Удаление символической ссылки /etc/resolv.conf"
        rm /etc/resolv.conf
    fi
}

# Определяем список файлов для настройки
# Формат: "имя_файла|доп_переменные|описание"
BIND_CONFIG_MAP=(
    "system/rsyslog_bind|/etc/rsyslog.d/named.conf|Настройка логов BIND9 (local6)|\
AUTHOR|LAST_MODIFIED"
    "system/logrotate_bind|/etc/logrotate.d/named|Ротация логов BIND9|\
AUTHOR|LAST_MODIFIED"
    "system/resolv.conf|/etc/resolv.conf|Системный резолвер|\
AUTHOR|LAST_MODIFIED|YOUR_DOMAIN"
    "bind/named.conf|/etc/bind/named.conf|Главный файл конфигурации|\
AUTHOR|LAST_MODIFIED"
    "bind/named.conf.options|/etc/bind/named.conf.options|Настройка ACL trusted|\
AUTHOR|LAST_MODIFIED|YOUR_NETWORK|FORWARDER_DNS1|FORWARDER_DNS2"
    "bind/named.conf.logging|/etc/bind/named.conf.logging|Настройка логирования|\
AUTHOR|LAST_MODIFIED"
    "bind/zones/named.conf.local|/etc/bind/zones/named.conf.local|Описание локальных зон|\
AUTHOR|LAST_MODIFIED"
    "bind/zones/named.conf.zones|/etc/bind/zones/named.conf.zones|Описание зон ${YOUR_DOMAIN}|\
AUTHOR|LAST_MODIFIED|YOUR_DOMAIN|YOUR_NETWORK|YOUR_REVERSE_OCTET|YOUR_NETWORK_V6|YOUR_REVERSE_V6_OCTET"
    "bind/zones/db.localhost|/etc/bind/zones/db.local|Локальная зона прямого просмотра|\
AUTHOR|LAST_MODIFIED|SERIALNUMBER"
    "bind/zones/db.0.0.127|/etc/bind/zones/db.127|Локальная зона IPv4 реверс|\
AUTHOR|LAST_MODIFIED|SERIALNUMBER"
    "bind/zones/db.ip6.0|/etc/bind/zones/db.ip6.arpa|Локальная зона IPv6 реверс|\
AUTHOR|LAST_MODIFIED|SERIALNUMBER"
    # Файлы пользовательских зон (используем метку DOMAIN для подстановки в пути)
    "bind/zones/db.DOMAIN|/etc/bind/zones/db.DOMAIN|Зона прямого просмотра ${YOUR_DOMAIN}|\
AUTHOR|LAST_MODIFIED|SERIALNUMBER|YOUR_DOMAIN|YOUR_SERVER_IP"
    "bind/zones/db.rev.DOMAIN|/etc/bind/zones/db.rev.DOMAIN|Зона IPv4 реверс ${YOUR_REVERSE_OCTET}|\
AUTHOR|LAST_MODIFIED|SERIALNUMBER|YOUR_REVERSE_OCTET|YOUR_DOMAIN|LAST_OCTET"
    "bind/zones/db.rev6.DOMAIN|/etc/bind/zones/db.rev6.DOMAIN|Зона IPv6 реверс ${YOUR_REVERSE_V6_OCTET}|\
AUTHOR|LAST_MODIFIED|SERIALNUMBER|YOUR_REVERSE_V6_OCTET|YOUR_DOMAIN|LAST_OCTET_V6"
)

# Далее код может использовать функции ядра, например log_info
main_bind9() {
    
    log_info "--- НАЧАЛО РАЗВЕРТЫВАНИЯ СЛУЖБ DNS (IPv4/IPv6) <<<"

    # Проверяем наличие прав
    log_info "--- Проверка наличия прав root ---"

    check_root || return 1 

    # Сначала убираем "умные" службы resolv
    log_info "--- Отключаем умные службы resolv ---"

    disable_dns_managers

    # Устанавливаем bind9 (в Debian это dns)
    log_info "--- Устанавливаем приложение ${PROJECT_NAME} ---"

    install_list "${PROJECT_NAME} rsyslog"

    # Создаем backup настроек
    log_info "--- Создаем backup версию ---"
    
    # Добавляем папку в backup
    add_to_staging "/etc/bind"
    add_to_staging "/etc/resolv.conf"
    add_to_staging "/etc/rsyslog.d/named.conf"
    add_to_staging "/etc/logrotate.d/named"
    # Финализируем процесс
    finalize_backup

    # Создание структуры (только один раз)
    log_info "--- Создаем все необходимые каталоги ---"

    # Создаем папку /etc/bind/zones
    ensure_path_exists "/etc/bind/zones" "dir" "root:bind" "2750"
    # Обеспечиваем членство в группе (выполняется один раз)
    usermod -aG adm syslog 2>/dev/null    
    # Создаем папку /var/log/named
    ensure_path_exists "/var/log/named" "dir" "bind:adm" "770"
    # Создаем файл /var/log/named/queries.log
    ensure_path_exists "/var/log/named/queries.log" "file" "bind:adm" "640"
    # Создаем файл /var/log/named/named.log
    ensure_path_exists "/var/log/named/named.log" "file" "syslog:adm" "640"
    
    log_info ">>> Начинаю массовую генерацию конфигураций BIND..."

    for entry in "${BIND_CONFIG_MAP[@]}"; do
        # Разрезаем строку на части по разделителю |
        # Используем IFS (Internal Field Separator) временно для этой команды
        IFS='|' read -r tpl_name dest_path description vars_list <<< "$entry"

        # 2. Магия подстановки для путей (заменяем метку DOMAIN на реальный домен)
        # Если в пути есть слово DOMAIN, оно заменится на значение переменной YOUR_DOMAIN
        local final_dest="${dest_path//DOMAIN/$YOUR_DOMAIN}"
        
        # 3. Получаем список переменных для envsubst (всё, что после 3-го разделителя)
        local target_vars=$(echo "$entry" | cut -d'|' -f4-)

        # 4. Снимаем блокировку chattr -i (актуально для /etc/resolv.conf)
        [ -f "$final_dest" ] && chattr -i "$final_dest" 2>/dev/null

        # 5. Генерация файла
        # Извлечь имя файла (аналог basename):
        # FILENAME="${FILE_PATH##*/}" (удалить всё ДО последнего /)
        log_info "--- $description (${dest_file##*/}) ---"
        update_configs \
            "${ROOT_DIR}/template/${tpl_name}.tpl" \
            "$final_dest" \
            "$target_vars"

        # 6. Установка прав доступа
        if [[ -f "$final_dest" ]]; then
            # Настраиваем права только на ФАЙЛ, не трогая ПАПКУ (она уже настроена)
            if [[ "$final_dest" == "/etc/bind/"* ]]; then
                chown root:bind "$final_dest"
                
                if [[ "$final_dest" == *"/db."* ]]; then
                    # Файлы зон: 660 или 664 (зависит от того, должны ли их видеть другие)
                    # Раз у папки 2750, логично поставить 660 или 640
                    chmod 660 "$final_dest" 
                else
                    chmod 644 "$final_dest"
                fi
            elif [[ "$final_dest" == "/etc/resolv.conf" ]]; then
                chown root:root "$final_dest" && chmod 644 "$final_dest"
                chattr +i "$final_dest" 2>/dev/null
            else
                chown root:root "$final_dest" && chmod 644 "$final_dest"
            fi
        fi
    done

    log_info "--- Проверка конфигурационных файлов BIND9 ---"

    # Проверка общей структуры (подтянет все include)
    if named-checkconf /etc/bind/named.conf; then
        log_info "[OK] Синтаксис конфигов корректен"
    else
        log_error "Ошибка в named.conf" && return 1
    fi

    # Проверка файлов зон (КРИТИЧНО)
    log_info "--- Проверка файлов зон ---"
    named-checkzone "${YOUR_DOMAIN}" "/etc/bind/zones/db.${YOUR_DOMAIN}" || return 1
    named-checkzone "${YOUR_REVERSE_OCTET}.in-addr.arpa" "/etc/bind/zones/db.rev.${YOUR_DOMAIN}" || return 1
    named-checkzone "${YOUR_REVERSE_V6_OCTET}.ip6.arpa" "/etc/bind/zones/db.rev6.${YOUR_DOMAIN}" || return 1

    # Перезапуск и проверка служб
    log_info "--- Перезапуск служб ---"
    local services=("rsyslog" "bind9")
    
    for svc in "${services[@]}"; do
        systemctl restart "$svc"
        systemctl enable "$svc"
        if systemctl is-active --quiet "$svc"; then
            log_info "[OK] Служба $svc запущена."
        else
            log_error "Ошибка запуска $svc. Проверь journalctl -u $svc"
        fi
    done

    log_info "--- Тестирование DNS-сервера (nslookup) ---"
    
    # Указываем сервер явно через IP, чтобы не зависеть от /etc/resolv.conf
    nslookup "${YOUR_DOMAIN}" "${YOUR_SERVER_IP}"
    nslookup "${YOUR_SERVER_IP}" "${YOUR_SERVER_IP}"

    log_info "====================================================="
    log_info "Настройка DNS-сервера завершена. Проверьте вывод выше."
    log_info "====================================================="

}

main_bind9 "$@"