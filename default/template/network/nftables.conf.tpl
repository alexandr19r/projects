#!/usr/sbin/nft -f
# /etc/nftables.conf
# [nftables.conf] - Конфигурационный файл NFTables (Firewall/NAT/Forwarding)
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

flush ruleset

table inet filter {
    # Пакеты, входящие на сам сервер
    chain input {
        type filter hook input priority 0; policy drop;

        # Разрешаем установленные соединения (ответы на наши запросы)
        ct state established,related accept

        # Разрешаем локальный трафик (loopback)
        iif "lo" accept

        # Разрешаем ICMP (Ping) для диагностики (v4 и v6)
        icmp type echo-request accept
        icmpv6 type { echo-request, nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept

        # --- Разрешаем SSH (при необходимости ограничь по IP) ---
        tcp dport 22 accept

        # --- Разрешаем DNS (BIND9) ---
        udp dport 53 accept
        tcp dport 53 accept

        # --- Разрешаем DHCPv4 ---
        udp dport 67 accept

        # --- Разрешаем DHCPv6 ---
        udp dport 547 accept
        
        # Логируем пакеты, которые не прошли на сервер
        log prefix "NFT_INPUT_DROP: " level info facility local0
    }

    # Пакеты, проходящие СКВОЗЬ сервер (Routing/Forwarding)
    chain forward {
        type filter hook forward priority 0; policy drop;
        
        # Разрешаем проход трафика из локальной сети во внешний мир
        iif "${DHCP_INTERFACE}" accept
        oif "${DHCP_INTERFACE}" ct state established,related accept

        # Логируем пакеты, которые не прошли сквозь шлюз
        log prefix "NFT_FORWARD_DROP: " level info facility local0
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# Секция NAT (Маскарадинг)
table inet nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        
        # Маскируем весь исходящий трафик с интерфейса
        oif "${DHCP_INTERFACE}" masquerade
    }
}

