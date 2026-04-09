// /etc/bind/
// [named.conf] - основной файл конфигурации bind
// Author: [$AUTHOR]
// Last Modified: $LAST_MODIFIED

// This is the primary configuration file for the BIND DNS server named.
//
// Please read /usr/share/doc/bind9/README.Debian.gz for information on the 
// structure of BIND configuration files in Debian, BEFORE you customize 
// this configuration file.
//
// If you are just adding zones, please do that in /etc/bind/named.conf.local

// Глобальные настройки (ACL, порты, форвардинг)
include "/etc/bind/named.conf.options";

// Настройка профессионального логирования (в /var/log/bind/)
include "/etc/bind/named.conf.logging";

// Стандартные зоны (RFC 1912, localhost, root hints)
// include "/etc/bind/named.conf.default-zones";

// Файл для динамических записей (заменяет default-zones)
include "/etc/bind/zones/internal/named.conf.internal";

// Локальные зоны (описания зон)
include "/etc/bind/zones/master/named.conf.master";

