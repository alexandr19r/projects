// /etc/bind/zones/internal/
// [named.conf.internal] - Системные зоны (RFC 1912)
// Author: [$AUTHOR]
// Last Modified: $LAST_MODIFIED

// --- СИСТЕМНЫЕ ЗОНЫ (Loopback & Hints) ---

// Корневые серверы (Root Hints)
zone "." {
	type hint;
	file "/usr/share/dns/root.hints";
};

// Зона прямого просмотра для localhost
zone "localhost" {
    type master;
    file "/etc/bind/zones/internal/db.localhost";
    // Ограничение передачи зоны для безопасности
    allow-transfer {none; };
};

// Зона обратного просмотра для loopback IPv4 (127.0.0.1)
zone "127.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/internal/db.127";
    allow-transfer {none; };
};

// Зона обратного просмотра для loopback IPv6 (::1)
zone "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"{
    type master;
    file "/etc/bind/zones/internal/db.ip6.0";
    allow-transfer {none; };
};

// Системные зоны для широковещательных запросов (RFC 1912)
zone "0.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/internal/db.0";
};

zone "255.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/internal/db.255";
};
