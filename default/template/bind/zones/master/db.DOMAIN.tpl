; /etc/bind/zones/master/
; [db.$LOCAL_DOMAIN] - Прямая зона $LOCAL_DOMAIN
; Author: [$AUTHOR]
; Last Modified: $LAST_MODIFIED
;
; BIND data file for domain interface
;
\$TTL    604800
\$ORIGIN $LOCAL_DOMAIN.

@       IN      SOA     ns1.$LOCAL_DOMAIN. root.$LOCAL_DOMAIN. (
                        $SERIALNUMBER   ; Serial
                        600             ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        600 )           ; Negative Cache TTL

; --- СЕРВЕРЫ ИМЕН (NS) ---
; NS-запись должна иметь и A, и AAAA записи для доступности по обоим протоколам
@       IN      NS      ns1.$LOCAL_DOMAIN.

; --- ГЛАВНЫЙ СЕРВЕР (Infrastructure Core) ---
@       IN      A       $SERVER_IP_V4
@       IN      AAAA    $SERVER_IP_V6
ns1     IN      A       $SERVER_IP_V4
ns1     IN      AAAA    $SERVER_IP_V6

; --- ХОСТЫ СЕТИ (Nodes) ---
debsrv  IN      A       $SERVER_IP_V4
debsrv  IN      AAAA    $SERVER_IP_V6

gw      IN      A       10.10.100.2
gw      IN      AAAA    fc00:db9:aaaa::2

devsrv  IN      A       10.10.100.3
devsrv  IN      AAAA    fc00:db9:aaaa::3

srv1c   IN      A       10.10.100.4
srv1c   IN      AAAA    fc00:db9:aaaa::4

; --- ПОЧТОВАЯ СЛУЖБА (Mail Stack) ---
; MX указывает на имя, которое имеет и A, и AAAA записи
@       IN      MX 10   mail.$LOCAL_DOMAIN.
mail    IN      A       $SERVER_IP_V4
mail    IN      AAAA    $SERVER_IP_V6
@       IN      TXT     "v=spf1 ip4:10.10.100.0/24 ip6:fc00:db9:aaaa::/64 mx -all"

; --- ПСЕВДОНИМЫ (Aliases) ---
; CNAME универсален: он вернет и A, и AAAA хоста debsrv
www     IN      CNAME   debsrv
ftp     IN      CNAME   debsrv

; --- СЛУЖЕБНЫЕ ЗАПИСИ (Service Discovery) ---
; Для SRV крайне важно использовать FQDN (с точкой на конце)
_ldap._tcp IN   SRV 0 100 389 debsrv.$LOCAL_DOMAIN.
_kerberos._udp IN SRV 0 100 88 debsrv.$LOCAL_DOMAIN.
