// /etc/bind/
// [named.conf.options] - конфигурационный файл настроек bind
// Author: [${AUTHOR}]
// Last Modified: ${LAST_MODIFIED}

// Определяем локальную сеть как доверенную
acl "trusted" {
            ${YOUR_NETWORK};
            localhost;
};

options {
        directory "/var/cache/bind";
        dnssec-validation auto; 	    # DNSSEC
        auth-nxdomain no;    		    # conform to RFC1035
	    //blackhole {192.168.1.200; }	# Блокировка IP


        // Разрешаем рекурсивные запросы только для доверенных клиентов
        allow-query { trusted; };
        forward first;			# Сначала пытаемся форвардить
	    recursion yes;

        // Перенаправляем внешние запросы на публичные DNS
        forwarders {
            ${FORWARDER_DNS1};
            ${FORWARDER_DNS2};
        };

        // Слушаем все интерфейсы (IPv4)
        listen-on { any; };
	    // Слушаем все интерфейсы (IPv6)
	    listen-on-v6 {any; };
};