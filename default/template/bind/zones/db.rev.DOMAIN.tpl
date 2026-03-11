; /etc/bind/zones/
; [db.${YOUR_REVERSE_OCTET}] - Файл обратной зоны db.${YOUR_REVERSE_OCTET}
; Author: [${AUTHOR}]
; Last Modified: ${LAST_MODIFIED}
;
; BIND reverse data file for domain interface
;
$TTL    604800
$ORIGIN ${YOUR_REVERSE_OCTET}.in-addr.arpa.

@       IN      SOA     ns1.${YOUR_DOMAIN}. root.${YOUR_DOMAIN}. (
                        ${SERIALNUMBER} ; Serial (Генерируется скриптом)
                        600              ; Refresh
                        86400            ; Retry
                        2419200          ; Expire
                        600 )            ; Negative Cache TTL
;
@       IN      NS      ns1.${YOUR_DOMAIN}.

; Записи указателей (PTR)
; Используем переменную LAST_OCTET, подготовленную в core.sh
${LAST_OCTET} IN PTR ns1.${YOUR_DOMAIN}.
${LAST_OCTET} IN PTR debsrv.${YOUR_DOMAIN}.

2       IN      PTR     gw.${YOUR_DOMAIN}.
3       IN      PTR     devsrv.${YOUR_DOMAIN}.
4       IN      PTR     srv1c.${YOUR_DOMAIN}.
;
; Записи для динамических обновлений (если используются)
; $GENERATE 104-199 $ PTR host-$.${YOUR_DOMAIN}.
