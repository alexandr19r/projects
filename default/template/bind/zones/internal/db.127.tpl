; /etc/bind/zones/internal/
; [db.127] - Обратная зона localhost IPv4 (Loopback)
; Author: [$AUTHOR]
; Last Modified: $LAST_MODIFIED
;
; BIND reverse data file for local loopback interface
;
$TTL    604800
; $ORIGIN 0.0.127.in-addr.arpa. ; Удалено для универсальности

@       IN      SOA     localhost. root.localhost. (
                        $SERIALNUMBER   ; Serial YYYYMMDDNN
                        604800          ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        604800 )        ; Negative Cache TTL
;
; Запись для сервера имен (NS)
@       IN      NS        localhost.
; Записи указателей (PTR)
1.0.0   IN      PTR       localhost.
