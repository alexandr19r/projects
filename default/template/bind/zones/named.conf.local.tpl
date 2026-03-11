// /etc/bind/zones/
// [named.conf.local] - Файл описания зон прямого просмотра local
// Author: [${AUTHOR}]
// Last Modified: ${LAST_MODIFIED}

// Зона прямого просмотра для localhost
zone "localhost" {
    type master;
    file "/etc/bind/zones/db.localhost";
    // Ограничение передачи зоны для безопасности
    allow-transfer {none; };
};

// Зона обратного просмотра для loopback (127.0.0.1)
zone "0.0.127.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.0.0.127";
    allow-transfer {none; };
};

// Зона обратного просмотра для loopback IPv6 (::1)
zone "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"{
    type master;
    file "/etc/bind/zones/db.ip6.0";
    allow-transfer {none; };
};