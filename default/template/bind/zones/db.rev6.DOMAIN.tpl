; /etc/bind/zones/
; [db.${YOUR_REVERSE_V6_OCTET}] - Файл обратной зоны db.${YOUR_REVERSE_V6_OCTET}
; Author: [${AUTHOR}]
; Last Modified: ${LAST_MODIFIED}
;
; BIND reverse data file for domain interface
;

$TTL    604800
; ORIGIN должен содержать инвертированную сетевую часть IPv6
$ORIGIN ${YOUR_REVERSE_V6_OCTET}.ip6.arpa.

@       IN      SOA     ns1.${YOUR_DOMAIN}. root.${YOUR_DOMAIN}. (
                        ${SERIALNUMBER} ; Serial (YYYYMMDDNN)
                        600              ; Refresh
                        86400            ; Retry
                        2419200          ; Expire
                        600 )            ; Negative Cache TTL
;
@       IN      NS      ns1.${YOUR_DOMAIN}.

; Записи указателей (PTR) для IPv6
; Используем переменную LAST_OCTET_V6 (инвертированная часть хоста)
${LAST_OCTET_V6} IN PTR ns1.${YOUR_DOMAIN}.
${LAST_OCTET_V6} IN PTR debsrv.${YOUR_DOMAIN}.

; Примеры для других хостов (адреса ::2, ::3, ::4)
2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR gw.${YOUR_DOMAIN}.
3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR devsrv.${YOUR_DOMAIN}.
4.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR srv1c.${YOUR_DOMAIN}.

; Динамический диапазон для клиентских IPv6 (::100 - ::1FF)
;$GENERATE 256-511 $/16.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 PTR host-$.${YOUR_DOMAIN}.