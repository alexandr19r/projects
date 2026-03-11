; /etc/bind/zones/
; [db.localhost]
; Author: [${AUTHOR}]
; Last Modified: ${LAST_MODIFIED}
;
; BIND data file for local loopback interface
;
\$TTL    604800
\$ORIGIN localhost.

@       IN      SOA     localhost. root.localhost. (
                        ${SERIALNUMBER}   ; Serial YYYYMMDDNN
                        604800          ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        604800 )        ; Negative Cache TTL
;
; Запись для сервера имен (NS)
@       IN      NS      localhost.
; Запись хоста (A)
ns1     IN      A       127.0.0.1
; Запись хоста IPv6 (AAAA)
@       IN      AAAA    ::1
