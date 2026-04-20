; /etc/bind/zones/master/
; [db.rev6.$LOCAL_DOMAIN] - Обратная зона IPv6 $REVERSE_OCTET_V6.ip6.arpa
; Author: [$AUTHOR]
; Last Modified: $LAST_MODIFIED
;
; BIND reverse data file for domain interface
;
\$TTL    604800
; ORIGIN должен содержать инвертированную сетевую часть IPv6
\$ORIGIN $REVERSE_OCTET_V6.ip6.arpa.

@       IN      SOA     ns1.$LOCAL_DOMAIN. root.$LOCAL_DOMAIN. (
                        $SERIALNUMBER       ; Serial (YYYYMMDDNN)
                        600                 ; Refresh
                        86400               ; Retry
                        2419200             ; Expire
                        600 )               ; Negative Cache TTL
;
; --- СЕРВЕРЫ ИМЕН (NS) ---
@       IN      NS      ns1.$LOCAL_DOMAIN.

; --- ЗАПИСИ УКАЗАТЕЛЕЙ (PTR) IPv6 --- 
; Используем переменную LAST_OCTET_V6 (инвертированная часть хоста)
$LAST_OCTET_V6 IN PTR ns1.$LOCAL_DOMAIN.

; --- СТАТИЧЕСКИЕ УЗЛЫ (хост-часть адреса инвертирована) ---
2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR gw.$LOCAL_DOMAIN.
3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR devsrv.$LOCAL_DOMAIN.
4.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR srv1c.$LOCAL_DOMAIN.

; --- ДИНАМИЧЕСКИЙ ПУЛ (::100 - ::1FF) ---
;$DNS_REV6_POOL
