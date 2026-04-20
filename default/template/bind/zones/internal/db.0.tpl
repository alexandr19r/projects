; /etc/bind/zones/internal/
; [db.0] - Системная зона для широковещательных адресов (0.0.0.0)
; Author: [$AUTHOR]
; Last Modified: $LAST_MODIFIED
;
; BIND reverse data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     localhost. root.localhost. (
                        $SERIALNUMBER     ; Serial YYYYMMDDNN
                        604800            ; Refresh
                        86400             ; Retry
                        2419200           ; Expire
                        604800 )          ; Negative Cache TTL
;
@       IN      NS      localhost.
