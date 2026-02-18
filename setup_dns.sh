#!/bin/bash

set -e  # Остановить скрипт при первой же ошибке

# =================================================================
# Скрипт автоматической настройки DNS-сервера (BIND9) на Debian 11
# =================================================================
# ВНИМАНИЕ: Запускать с правами ROOT (sudo ./setup_dns.sh)
# Замените плейсхолдеры YOUR_... на ваши значения.

# --- УСТАНАВЛИВАЕМЫЙ ПАКЕТ ---
PACKAGE="bind9"

# --- ПЕРЕМЕННЫЕ НАСТРОЙКИ ---
YOUR_DOMAIN="home.local"         # Ваш локальный домен (например, corp.local)
YOUR_SERVER_IP="10.10.100.1"     # IP-адрес вашего сервера
YOUR_NETWORK="10.10.100.0/24"    # Ваша локальная сеть (например, 192.168.1.0/24)
YOUR_REVERSE_OCTET="100.10.10"   # Обратный порядок октетов сети (например, 1.168.192 для 192.168.1.x)
FORWARDER_DNS1="8.8.8.8"         # Внешний DNS 1 (Google DNS)
FORWARDER_DNS2="8.8.4.4"         # Внешний DNS 2
FOLDER_RELEASE="release"         # Папка для текущей конфигурации
FOLDER_BACKUP="backup"           # Папка для backup
# ------------------------------

# --- ФОРМИРОВАНИЕ ПАПКИ BACKUP
# Форматируем текущую дату и время
# Пример вывода: 2025-12-16_21-31-00
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# --- ФОРМИРОВАНИЕ СЕРИЙНОГО НОМЕРА ВЕРСИИ ---
# Серийный номер версии файлов зон
SERIALNUMBER=$(date +"%Y%m%d")

# Функция проверяет существование папки и создает при необходимости
# В случае ошибки прерывает выполнение
ensure_dir_exists() {
  local dir_path="$1"
  if [[ ! -d "$dir_path" ]]; then
    echo "Папка '$dir_path' не найдена. Создаю..."
    mkdir -p "$dir_path"
    if [[ $? -eq 0 ]]; then
      echo "Папка '$dir_path' успешно создана."
    else
      echo "Не удалось создать папку '$dir_path'. Проверьте права."
      exit 1 # Выход из скрипта в случае ошибки
    fi
  else
    echo "Папка '$dir_path' уже существует."
  fi
}


if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка скрипт запущен не от имени root. Требуются права суперпользователя."
    exit 1 # Выход из скрипта, если не root
fi

./install_package.sh $PACKAGE
if [ $? -ne 0 ]; then
    echo "Ошибка при установке пакета(ов) $PACKAGE"
    exit 1
fi

echo "--- Создаем все необходимые каталоги ---"

ensure_dir_exists "/etc/bind/$FOLDER_RELEASE"
ensure_dir_exists "/etc/bind/$FOLDER_BACKUP"
ensure_dir_exists "/etc/bind/$FOLDER_BACKUP/$TIMESTAMP"
ensure_dir_exists "/etc/bind/$FOLDER_RELEASE/zones"
ensure_dir_exists "/etc/bind/$FOLDER_BACKUP/$TIMESTAMP/zones"

echo "--- Создание главного файла конфигурации named.conf ---"

# Резераное копирование оригинального файла
cp "/etc/bind/named.conf" "/etc/bind/$FOLDER_BACKUP/$TIMESTAMP/named.conf.bak"

# Создание главного файла конфигурации
cat <<EOF > /etc/bind/named.conf
// Главный файл конфигурации

include "/etc/bind/$FOLDER_RELEASE/named.conf.options";
include "/etc/bind/$FOLDER_RELEASE/named.conf.logging";

include "/etc/bind/$FOLDER_RELEASE/named.conf.local";
include "/etc/bind/$FOLDER_RELEASE/named.conf.zones";

EOF

# Обход всех файлов в папке
# /* — выбирает все объекты
# /*.txt — выберет только текстовые файлы
for FILE_PATH in "/etc/bind/"*; do
    # Пропускаем, если это директория (на всякий случай)
    if [ -d "$FILE_PATH" ]; then
        echo ">> Пропуск исключения: $FILE_PATH"
        continue
    fi

    # Извлекаем только имя файла из пути
    FILE_NAME=$(basename "$FILE_PATH")

    case $FILE_NAME in
        named.conf|rndc.key|bind.keys)
            # Ничего не делаем для этих файлов
            echo ">> Пропуск исключения: $FILE_NAME"
            continue
            ;;
        *)
            # Для всех остальных файлов (если это файл)
            if [[ -f "$FILE_NAME" ]]; then
                echo "Обработка файла: $FILE_NAME"
		cp "/etc/bind/$FILE_NAME" "/etc/bind/$FOLDER_BACKUP/$TIMESTAMP/${FILE_NAME}.bak"
		rm "/etc/bind/$FILE_NAME"
            fi
            ;;
    esac
done

echo "--- Создание ACL 'trusted' в named.conf.options ---"

# Резервное копирование оригинального файла
if [ -f "/etc/bind/$FOLDER_RELEASE/named.conf.options" ]; then
	cp /etc/bind/$FOLDER_RELEASE/named.conf.options /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/named.conf.options.bak
        rm -r /etc/bind/$FOLDER_RELEASE/named.conf.options
fi
touch /etc/bind/$FOLDER_RELEASE/named.conf.options

cat <<EOF > /etc/bind/$FOLDER_RELEASE/named.conf.options
# Начало файла named.conf.options

// Определяем локальную сеть как доверенную
acl "trusted" {
            $YOUR_NETWORK;
            localhost;
};

options {
        directory "/var/cache/bind";
        dnssec-validation auto; 	# DNSSEC
        auth-nxdomain no;    		# conform to RFC1035
	#blackhole {192.168.1.200; }	# Блокировка IP


        // Разрешаем рекурсивные запросы только для доверенных клиентов
        allow-query { trusted; };
        forward first;			# Сначала пытаемся форвардить
	recursion yes;

        // Перенаправляем внешние запросы на публичные DNS
        forwarders {
            $FORWARDER_DNS1;
            $FORWARDER_DNS2;
        };

        // Слушаем все интерфейсы (IPv4)
        listen-on { any; };
	// Слушаем все интерфейсы (IPv6)
	#listen-on-v6 {any; };
};
EOF

echo "--- Создание логирования в named.conf.logging ---"

# Резервное копирование оригинального файла
if [ -f "/etc/bind/$FOLDER_RELEASE/named.conf.logging" ]; then
	cp /etc/bind/$FOLDER_RELEASE/named.conf.logging /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/named.conf.logging.bak
        rm -r /etc/bind/$FOLDER_RELEASE/named.conf.logging
fi
touch /etc/bind/$FOLDER_RELEASE/named.conf.logging

# Создадим файл логирования при необходимости
if [ -f "/var/log/bind/queries.log" ]; then
	touch /var/log/bind/queries.log
fi

# Использование ACL для разрешения запросов из локальной сети и перенаправления
cat <<EOF > /etc/bind/$FOLDER_RELEASE/named.conf.logging
# Начало файла named.conf.logging
logging {
        channel queries_log {
		file "/var/log/bind/queries.log" versions 3 size 5m;
		severity info;
		print-time yes;
		print-category yes;
	};
	category queries {queries_log; };
};
EOF

echo "--- Настройка зоны прямого просмотра в named.conf.local ---"

# Резервное копирование
if [ -f "/etc/bind/$FOLDER_RELEASE/named.conf.local" ]; then
    cp /etc/bind/$FOLDER_RELEASE/named.conf.local /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/named.conf.local.bak
    rm -r /etc/bind/$FOLDER_RELEASE/named.conf.local
fi
touch /etc/bind/$FOLDER_RELEASE/named.conf.local

cat <<EOF >> /etc/bind/$FOLDER_RELEASE/named.conf.local
# Начало файла
// Зона прямого просмотра для localhost
zone "localhost" {
    type master;
    file "/etc/bind/$FOLDER_RELEASE/zones/db.localhost";
    // Ограничение передачи зоны для безопасности
    allow-transfer {none; };
};

// Зона обратного просмотра для loopback (127.0.0.1)
zone "0.0.127.in-addr.arpa" {
    type master;
    file "/etc/bind/$FOLDER_RELEASE/zones/db.0.0.127";
    allow-transfer {none; };
};

// Зона обратного просмотра для loopback IPv6 (::1)
zone "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"{
    type master;
    file "/etc/bind/FOLDER_RELEASE/zones/db.ip6.0";
    allow-transfer {none; };
};
EOF

echo "--- Настройка зоны прямого просмотра в named.conf.zones ---"

# Резервное копирование
if [ -f "/etc/bind/$FOLDER_RELEASE/named.conf.zones" ]; then
    cp /etc/bind/$FOLDER_RELEASE/named.conf.zones /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/named.conf.zones.bak
    rm -r /etc/bind/$FOLDER_RELEASE/named.conf.zones
fi
touch /etc/bind/$FOLDER_RELEASE/named.conf.zones

cat <<EOF >> /etc/bind/$FOLDER_RELEASE/named.conf.zones
# Начало файла
// Зона прямого просмотра для $YOUR_DOMAIN
zone "$YOUR_DOMAIN" {
    type master;
    file "/etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_DOMAIN";
};

// Зона обратного просмотра для $YOUR_NETWORK
zone "$YOUR_REVERSE_OCTET.in-addr.arpa" {
    type master;
    file "/etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_REVERSE_OCTET";
};
EOF

echo "--- Создание файла зоны прямого просмотра db.localhost ---"

if [ -f "/etc/bind/$FOLDER_RELEASE/zones/db.localhost" ]; then
    cp /etc/bind/$FOLDER_RELEASE/zones/db.localhost /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/zones/db.localhost.bak
    rm -r /etc/bind/$FOLDER_RELEASE/zones/db.localhost
fi
touch /etc/bind/$FOLDER_RELEASE/zones/db.localhost

# Файл зоны для localhost
cat <<EOF > /etc/bind/$FOLDER_RELEASE/zones/db.localhost
;
; BIND data file for local loopback interface
;
\$TTL    604800
\$ORIGIN localhost.

@       IN      SOA     localhost. root.localhost. (
                        $SERIALNUMBER   ; Serial YYYYMMDDNN
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
; Запись для сервера имен (NS)
@       IN      NS      localhost.
; Запись хоста (A)
ns1     IN      A       127.0.0.1
; Запись хоста IPv6 (AAAA)
@       IN      AAAA    ::1
EOF

echo "--- Создание файла зоны обратного просмотра db.0.0.127 ---"

if [ -f "/etc/bind/$FOLDER_RELEASE/zones/db.0.0.127" ]; then
    cp /etc/bind/$FOLDER_RELEASE/zones/db.0.0.127 /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/zones/db.0.0.127.bak
    rm -r /etc/bind/$FOLDER_RELEASE/zones/db.0.0.127
fi
touch /etc/bind/$FOLDER_RELEASE/zones/db.0.0.127

# Файл обратной зоны для 127.0.0.1
cat <<EOF > /etc/bind/$FOLDER_RELEASE/zones/db.0.0.127
;
; BIND reverse data file for local loopback interface
;
\$TTL    604800
\$ORIGIN 0.0.127.in-addr.arpa.

@       IN      SOA     localhost. root.localhost. (
                        $SERIALNUMBER   ; Serial YYYYMMDDNN
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
; Запись для сервера имен (NS)
@       IN      NS        localhost.
; Записи указателей (PTR)
1       IN      PTR       localhost.
EOF

echo "--- Создание файла зоны обратного просмотра db.ip6.0 ---"

if [ -f "/etc/bind/$FOLDER_RELEASE/zones/db.ip6.0" ]; then
    cp /etc/bind/$FOLDER_RELEASE/zones/db.ip6.0 /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/zones/db.ip6.0.bak
    rm -r /etc/bind/$FOLDER_RELEASE/zones/db.ip6.0
fi
touch /etc/bind/$FOLDER_RELEASE/zones/db.ip6.0

# Файл обратной зоны для ::1
cat <<EOF > /etc/bind/$FOLDER_RELEASE/zones/db.ip6.0
;
; BIND reverse data file for local loopback IPv6 interface
;
\$TTL    604800
\$ORIGIN 0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa

@       IN      SOA     localhost. root.localhost. (
                        $SERIALNUMBER   ; Serial YYYYMMDDNN
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
; Запись для сервера имен (NS)
@       IN      NS        localhost.
; Записи указателей (PTR)
1       IN      PTR       localhost.
EOF

echo "--- Создание файла зоны прямого просмотра db.$YOUR_DOMAIN ---"

if [ -f "/etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_DOMAIN" ]; then
    cp /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_DOMAIN /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/zones/db.$YOUR_DOMAIN.bak
    rm -r /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_DOMAIN
fi
touch /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_DOMAIN

# Файл зоны для вашего домена
cat <<EOF > /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_DOMAIN
;
; BIND data file for domain interface
;
\$TTL    604800
\$ORIGIN $YOUR_DOMAIN.

@       IN      SOA     ns1.$YOUR_DOMAIN. root.$YOUR_DOMAIN. (
                        $SERIALNUMBER   ; Serial YYYYMMDDNN
                        600        ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        600 )      ; Negative Cache TTL
;
; Записи для серверов имен (NS)
@       IN      NS      ns1.$YOUR_DOMAIN.
;@      IN      AAAA    ::1
;
; Записи хостов (A)
ns1     IN      A       $YOUR_SERVER_IP
;@       IN      A       $YOUR_SERVER_IP
debsrv  IN      A       $YOUR_SERVER_IP
gw      IN      A       10.10.100.2
devsrv  IN      A       10.10.100.3
srv1C   IN      A       10.10.100.4
;
; Записи псевдонимов (CNAME)
;www     IN      CNAME   debsrv
;ftp     IN      CNAME   debsrv
;
; Записи почтовых серверов (MX)
@        IN      MX 10   mail.$YOUR_DOMAIN.
mail     IN      A       $YOUR_SERVER_IP
;
; Записи SPF для защиты от спама
@        IN      TXT     "v=spf1 ip4:10.10.100.0/24 mx -all"
;
; Записи для конкретных сервисов (SRV)
_ldap._tcp IN    SRV 0 100 389 debsrv.$YOUR_DOMAIN.
;
; Записи для  IPv6 (AAAA)
;ns1     IN      AAAA    fc00:db9:aaaa::1
;debsrv  IN      AAAA    fc00:db9:aaaa::1
;gw      IN      AAAA    fc00:db9:aaaa::4
;devsrv  IN      AAAA    fc00:db9:aaaa::3
;srv1C   IN      AAAA    fc00:db9:aaaa::4
;
EOF

echo "--- Создание файла зоны обратного просмотра db.$YOUR_REVERSE_OCTET ---"
if [ -f "/etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_REVERSE_OCTET" ]; then
    cp /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_REVERSE_OCTET /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/zones/db.$YOUR_REVERSE_OCTET.bak
    rm -r /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_REVERSE_OCTET
fi
touch /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_REVERSE_OCTET

# Файл обратной зоны
cat <<EOF > /etc/bind/$FOLDER_RELEASE/zones/db.$YOUR_REVERSE_OCTET
;
; BIND reverse data file for domain interface
;
\$TTL    604800
\$ORIGIN 100.10.10.in-addr.arpa.

@       IN      SOA     ns1.$YOUR_DOMAIN. root.$YOUR_DOMAIN. (
                        $SERIALNUMBER   ; Serial
                        600        ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        600 )      ; Negative Cache TTL
;
; Записи для серверов имен (NS)
@       IN      NS      ns1.$YOUR_DOMAIN.
;
; Записи указателей (PTR)
$(echo $YOUR_SERVER_IP | cut -d. -f4) IN PTR ns1.$YOUR_DOMAIN.
$(echo $YOUR_SERVER_IP | cut -d. -f4) IN PTR debsrv.$YOUR_DOMAIN.
2       IN      PTR     gw.$YOUR_DOMAIN.
3       IN      PTR     devsrv.$YOUR_DOMAIN.
4       IN      PTR     srv1c.$YOUR_DOMAIN.
;
; Записи для динамических обновлений (если используются)
; $GENERATE 104-199 $ PTR host-$.$YOUR_DOMAIN.
EOF

echo "--- Проверка конфигурационных файлов BIND9 ---"
named-checkconf
named-checkconf /etc/bind/$FOLDER_RELEASE/named.conf.options
named-checkconf /etc/bind/$FOLDER_RELEASE/named.conf.logging
named-checkconf /etc/bind/$FOLDER_RELEASE/named.conf.local
named-checkconf /etc/bind/$FOLDER_RELEASE/named.conf.zones

echo "--- Перезапуск службы BIND9 ---"
systemctl restart named
systemctl enable named
systemctl status named | grep Active

echo "--- Тестирование DNS-сервера (nslookup) ---"
nslookup $YOUR_DOMAIN $YOUR_SERVER_IP
nslookup $YOUR_SERVER_IP $YOUR_SERVER_IP

echo "====================================================="
echo "Настройка DNS-сервера завершена. Проверьте вывод выше."
echo "Не забудьте обновить /etc/resolv.conf на ваших клиентах или на этом сервере"
echo "для использования IP-адреса $YOUR_SERVER_IP в качестве единственного DNS."
echo "====================================================="


echo "--- Создание файла /etc/resolv.conf ---"

if [ -f "/etc/resolv.conf" ]; then
    cp /etc/resolv.conf /etc/bind/$FOLDER_BACKUP/$TIMESTAMP/resolv.conf.bak
fi

# Файл resolv.conf
cat <<EOF > /etc/resolv.conf
# /etc/resolv.conf
# Сгенерировано вручную $(date +"%Y-%m-%d %H:%M")
# Локальный DNS сервер
nameserver 127.0.0.1
# Резервный DNS
nameserver 8.8.8.8
# nameserver 2001:db8::53   # Локальный IPv6 DNS-сервер (резервный)
# nameserver ::1
search $YOUR_DOMAIN
options timeout:2
options attempts:3
options rotate
EOF
