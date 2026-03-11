; /etc/bind/zones/
; [db.ip6.0] - Файл обратной зоны для ::1
; Author: [${AUTHOR}]
; Last Modified: ${LAST_MODIFIED}
;
; BIND reverse data file for local loopback IPv6 interface
;
\$TTL    604800
\$ORIGIN 0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa

@       IN      SOA     localhost. root.localhost. (
                        ${SERIALNUMBER}   ; Serial YYYYMMDDNN
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
; Запись для сервера имен (NS)
@       IN      NS        localhost.
; Записи указателей (PTR)
1       IN      PTR       localhost.
