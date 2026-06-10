// /etc/bind/
// [named.conf.options] -  - Конфигурация DNS (IPv4 + IPv6)
// Author: [$AUTHOR]
// Last Modified: $LAST_MODIFIED

// Определяем локальную сеть как доверенную
acl "trusted" {
    $LOCAL_NETWORK_V4;     // IPv4 сеть (например, 10.10.100.0/24)
    $LOCAL_NETWORK_V6;     // IPv6 сеть (например, fd00:db9:aaaa::/64)
    localhost;
    localnets;
};

options {
    directory "/var/cache/bind";
        
    // Безопасность и DNSSEC
    dnssec-validation auto; 	    // Автоматическая проверка trust-anchors DNSSEC 
    auth-nxdomain no;    		    // conform to RFC1035
	//blackhole {192.168.1.200; }	// Блокировка IP


    // Рекурсия и доступ
    recursion yes;
    allow-query { trusted; };      // Кто может спрашивать сервер
    allow-recursion { trusted; };  // Кому сервер будет искать ответы в интернете
    allow-query-cache { trusted; }; // Кто может видеть закэшированные ответы
    
    // Настройка пересылки (Forwarding)
    forward first;
    forwarders {
        $FORWARDER_DNS1;      // Обычно Google или Cloudflare (IPv4)
        $FORWARDER_DNS2;      // IPv6 DNS провайдера или публичный
    };

    // Прослушивание интерфейсов
    listen-on { any; };       // Слушать все IPv4
    listen-on-v6 { any; };    // Слушать все IPv6

    // Скрытие версии для безопасности
    version "not available";
};
