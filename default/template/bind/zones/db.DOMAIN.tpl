; /etc/bind/zones/
; [db.${YOUR_DOMAIN}] - Файл прямой зоны ${YOUR_DOMAIN}
; Author: [${AUTHOR}]
; Last Modified: ${LAST_MODIFIED}
;
; BIND data file for domain interface
;

$TTL    604800
$ORIGIN ${YOUR_DOMAIN}.

@       IN      SOA     ns1.${YOUR_DOMAIN}. root.${YOUR_DOMAIN}. (
                        ${SERIAL_NUMBER}   ; Serial YYYYMMDDNN
                        600        ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        600 )      ; Negative Cache TTL
;
; Записи для корня домена NS (основной IPv4 сервера)
@       IN      NS      ns1.${YOUR_DOMAIN}.
; Запись для корня домена NS (основной IPv6 сервера)
@       IN      AAAA    fc00:db9:aaaa::1

; Записи хостов (A)
ns1     IN      A       ${YOUR_SERVER_IP}
@       IN      A       ${YOUR_SERVER_IP}
debsrv  IN      A       ${YOUR_SERVER_IP}
gw      IN      A       10.10.100.2
devsrv  IN      A       10.10.100.3
srv1C   IN      A       10.10.100.4

; Записи псевдонимов (CNAME)
www     IN      CNAME   debsrv
ftp     IN      CNAME   debsrv

; Записи почтовых серверов (MX)
@       IN      MX 10   mail.${YOUR_DOMAIN}.
mail    IN      A       ${YOUR_SERVER_IP}

; Записи SPF (TXT)
@       IN      TXT     "v=spf1 ip4:10.10.100.0/24 mx -all"

; Записи для конкретных сервисов (SRV)
; ВАЖНО: точка в конце целевого хоста обязательна!
_ldap._tcp IN    SRV 0 100 389 debsrv.${YOUR_DOMAIN}.

; Записи для  IPv6 (AAAA)
ns1     IN      AAAA    fc00:db9:aaaa::1
debsrv  IN      AAAA    fc00:db9:aaaa::1
gw      IN      AAAA    fc00:db9:aaaa::4
devsrv  IN      AAAA    fc00:db9:aaaa::3
srv1C   IN      AAAA    fc00:db9:aaaa::4