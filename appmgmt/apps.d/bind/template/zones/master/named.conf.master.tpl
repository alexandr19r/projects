// /etc/bind/zones/master/
// [named.conf.master] - Описание рабочих зон сети $LOCAL_DOMAIN
// Author: [$AUTHOR]
// Last Modified: $LAST_MODIFIED

// Прямая зона (Имена -> IP) для $LOCAL_DOMAIN
zone "$LOCAL_DOMAIN" {
    type master;
    file "/etc/bind/zones/master/db.$LOCAL_DOMAIN";
    allow-transfer { none; };
};

// Обратная зона IPv4 (IP -> Имена) для $LOCAL_NETWORK_V4
zone "$REVERSE_OCTET_V4.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/master/db.rev4.$LOCAL_DOMAIN";
    allow-transfer { none; };
};

// Обратная зона IPv6 (IP -> Имена) для $LOCAL_NETWORK_V6
zone "$REVERSE_OCTET_V6.ip6.arpa" {
    type master;
    file "/etc/bind/zones/master/db.rev6.$LOCAL_DOMAIN";
    allow-transfer { none; };
};
