; /etc/bind/zones/master/
; [db.rev4.$LOCAL_DOMAIN] - Обратная зона IPv4 $REVERSE_OCTET_V4.in-addr.arpa
; Author: [$AUTHOR]
; Last Modified: $LAST_MODIFIED
;
; BIND reverse data file for domain interface
;
$TTL    604800
$ORIGIN $REVERSE_OCTET_V4.in-addr.arpa.

@       IN      SOA     ns1.$LOCAL_DOMAIN. root.$LOCAL_DOMAIN. (
                        $SERIALNUMBER    ; Serial (Генерируется скриптом)
                        600              ; Refresh
                        86400            ; Retry
                        2419200          ; Expire
                        600 )            ; Negative Cache TTL
;
; --- СЕРВЕРЫ ИМЕН (NS) ---
@       IN      NS      ns1.$LOCAL_DOMAIN.

; --- ЗАПИСИ УКАЗАТЕЛЕЙ (PTR) ---
; Используем переменную LAST_OCTET, подготовленную в bind.env
$LAST_OCTET_V4 IN PTR ns1.$LOCAL_DOMAIN.

; --- СТАТИЧЕСКИЕ УЗЛЫ ---
2       IN      PTR     gw.$LOCAL_DOMAIN.
3       IN      PTR     devsrv.$LOCAL_DOMAIN.
4       IN      PTR     srv1c.$LOCAL_DOMAIN.
;
; --- ДИНАМИЧЕСКИЙ ДИАПАЗОН (Pool) ---
; Авто-генерация имен для DHCP-клиентов (например, host-104.home.local)
;\$GENERATE 100-200 \$ PTR host-\$.$LOCAL_DOMAIN.
