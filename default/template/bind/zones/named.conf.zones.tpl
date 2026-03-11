// /etc/bind/zones/
// [named.conf.zones] - Файл описания зон прямого просмотра ${YOUR_DOMAIN}
// Author: [${AUTHOR}]
// Last Modified: ${LAST_MODIFIED}

// Зона прямого просмотра для ${YOUR_DOMAIN}
zone "${YOUR_DOMAIN}" {
    type master;
    file "/etc/bind/zones/db.${YOUR_DOMAIN}";
};

// Зона обратного просмотра для ${YOUR_NETWORK}
zone "${YOUR_REVERSE_OCTET}.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.${YOUR_REVERSE_OCTET}";
};

// Зона обратного просмотра для ${YOUR_NETWORK_V6}
zone "${YOUR_REVERSE_V6_OCTET}.ip6.arpa" {
    type master;
    file "/etc/bind/zones/db.rev6.${YOUR_DOMAIN}";
};