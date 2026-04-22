#!/usr/sbin/nft -f
# /etc/nftables.conf
# [nftables.conf] - Конфигурационный файл NFTables (Firewall/NAT/Forwarding)
# Author: [$AUTHOR]
# Last Modified: $LAST_MODIFIED

# --- ГЛОССАРИЙ СИНТАКСИСА ---
# iif/oif     — Привязка по индексу ядра (рекомендуется для 'lo').
# iifname/oifname — Привязка по имени интерфейса (оптимально для 'DHCP_INTERFACE' (eth0)).
# meta nfproto  — Строгая проверка протокола (ipv4/ipv6) в семействе 'inet'.

# --- ГЛОССАРИЙ СЕАНСОВ И ПРОТОКОЛОВ ---
# ct state invalid — Пакеты вне контекста (не принадлежат ни одному сеансу).
# limit rate 5/s  — Ограничение частоты (защита от DoS-атак и Flood).
# ip protocol icmp — Строгая привязка к IPv4 ICMP.
# ip6 nexthdr icmpv6 — Глубокая проверка заголовка IPv6 (гарантия типа протокола).

# --- ГЛОССАРИЙ NAT И МАСКАРАДИНГА ---
# masquerade   — Автоматическая подмена IP отправителя на IP интерфейса (SNAT).
# postrouting  — Цепочка обработки пакетов ПОСЛЕ принятия решения о маршруте.
# priority 100 — Стандартный приоритет для NAT (выполняется после фильтрации).

# --- ЭВОЛЮЦИЯ ПРАВИЛ ВХОДЯЩЕГО ТРАФИКА ---

# УРОВЕНЬ 1: СЕТЕВАЯ ГИГИЕНА (Фильтрация мусора)
# [+] Обязательно: отсекает 90% сетевого шума и попыток подделки сессий.
# ct state invalid drop

# УРОВЕНЬ 2: БАЗОВАЯ ДИАГНОСТИКА (ICMP/Ping)
# [!] Опасно: позволяет любому количеству пингов перегрузить канал и CPU.
# icmp type echo-request accept

# УРОВЕНЬ 3: ЗАЩИЩЕННАЯ ДИАГНОСТИКА (IPv4/IPv6 Rate Limit)
# [+] Профессионально: разрешает пинг, но ставит "лимит-заслонку" от флуда.
# ip protocol icmp icmp type echo-request limit rate 5/second accept
# ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 5/second accept

# УРОВЕНЬ 4: КРИТИЧЕСКАЯ СЛУЖБА IPv6 (Neighbor Discovery)
# [!] Жизненно важно: без этих правил IPv6-устройства не увидят сервер в сети.
# ip6 nexthdr icmpv6 icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept

# --- ЭВОЛЮЦИЯ ПРАВИЛ FORWARDING (ПРИМЕРЫ) ---

# УРОВЕНЬ 1: БАЗОВЫЙ (Пропуск любого трафика через интерфейс)
# [!] Опасно: позволяет внешнему миру бесконтрольно входить в локальную сеть.
# iifname "DHCP_INTERFACE" accept
# oifname "DHCP_INTERFACE" ct state established,related accept

# УРОВЕНЬ 2: СЕГМЕНТИРОВАННЫЙ (Фильтрация по подсети)
# [!] Безопаснее: ограничивает круг лиц, имеющих право на транзит. 
# Для IPv6 изменяется ip -> ip6
# ip saddr LOCAL_SUBNET_V4 iifname "DHCP_INTERFACE" accept
# oifname "DHCP_INTERFACE" ip daddr LOCAL_SUBNET_V4 ct state established,related accept
# ip6 saddr LOCAL_SUBNET_V6 iifname "DHCP_INTERFACE" accept
# oifname "DHCP_INTERFACE" ip6 daddr LOCAL_SUBNET_V6 ct state established,related accept

# УРОВЕНЬ 3: ПРОФЕССИОНАЛЬНЫЙ (Строгий контроль источника и назначения)
# [!] Идеально для шлюза: исключает петли трафика и "лишние" обращения к роутеру. 
# Для IPv6 изменяется ipv4 -> ipv6 и ip -> ip6
# ipv4 ip saddr LOCAL_SUBNET_V4 ip daddr != ROUTER_IP_V4 iifname "DHCP_INTERFACE" accept
# ipv4 ip saddr ROUTER_IP_V4 ip daddr LOCAL_SUBNET_V4 oifname "DHCP_INTERFACE" ct state established,related accept
# ipv6 ip6 saddr LOCAL_SUBNET_V6 ip6 daddr != ROUTER_IP_V6 iifname "DHCP_INTERFACE" accept
# ipv6 ip6 saddr ROUTER_IP_V6 ip6 daddr LOCAL_SUBNET_V6 oifname "DHCP_INTERFACE" ct state established,related accept

# УРОВЕНЬ 4: АТОМАРНЫЙ (Dual-Stack MITM Router)
# [!] Максимальная защита: разделение потоков IPv4/IPv6 и строгая проверка "Клиент <-> Роутер". 
# Для IPv6 изменяется ipv4 -> ipv6 и ip -> ip6
# meta nfproto ipv4 ip saddr LOCAL_SUBNET_V4 ip daddr != ROUTER_IP_V4 iifname "DHCP_INTERFACE" accept
# meta nfproto ipv4 ip saddr ROUTER_IP_V4 ip daddr LOCAL_SUBNET_V4 oifname "DHCP_INTERFACE" ct state established,related accept
# meta nfproto ipv6 ip6 saddr LOCAL_SUBNET_V6 ip6 daddr != ROUTER_IP_V6 iifname "DHCP_INTERFACE" accept
# meta nfproto ipv6 ip6 saddr ROUTER_IP_V6 ip6 daddr LOCAL_SUBNET_V6 oifname "DHCP_INTERFACE" ct state established,related accept

# --- ЭВОЛЮЦИЯ ПРАВИЛ NAT (МАСКАРАДИНГ) ---

# УРОВЕНЬ 1: ОБЩИЙ (Маскировка всего исходящего трафика)
# [!] Опасно: маскирует вообще всё, что выходит через интерфейс, включая ответы самого сервера.
# oifname "DHCP_INTERFACE" masquerade

# УРОВЕНЬ 2: СЕГМЕНТИРОВАННЫЙ (Маскировка по источнику)
# [+] Безопаснее: маскирует только трафик, пришедший из локальной сети $LOCAL_SUBNET. 
# Для IPv6 изменяется ipv4 -> ipv6 и ip -> ip6
# ip saddr LOCAL_SUBNET oifname "DHCP_INTERFACE" masquerade
# ip6 saddr LOCAL_SUBNET_V6 oifname "DHCP_INTERFACE" masquerade

# УРОВЕНЬ 3: ТАРГЕТИРОВАННЫЙ (Hairpin NAT / Маршрутизатор на одной "ноге")
# [+] Профессионально: маскирует только те пакеты клиентов, которые идут К РОУТЕРУ. 
# Для IPv6 изменяется ipv4 -> ipv6 и ip -> ip6
# [!] Идеально для твоей схемы: заставляет роутер возвращать ответы серверу, а не клиенту напрямую.
# ipv4 ip saddr LOCAL_SUBNET ip daddr ROUTER_IP oifname "DHCP_INTERFACE" masquerade
# ipv6 ip6 saddr LOCAL_SUBNET_V6 ip6 daddr ROUTER_IP_V6 oifname "DHCP_INTERFACE" masquerade

# УРОВЕНЬ 4: DUAL-STACK (IPv4 + IPv6 NAT66)
# [+] Максимально: зеркальная маскировка для обоих протоколов (если роутер не знает о твоей IPv6 подсети). 
# Для IPv6 изменяется ipv4 -> ipv6 и ip -> ip6
# meta nfproto ipv4 ip saddr LOCAL_SUBNET_V4 ip daddr ROUTER_IP_V4 oifname "DHCP_INTERFACE" masquerade
# meta nfproto ipv6 ip6 saddr LOCAL_SUBNET_V6 ip6 daddr ROUTER_IP_V6 oifname "DHCP_INTERFACE" masquerade

flush ruleset

table inet filter {
    # Пакеты, входящие на сервер (Input)
    chain input {
        type filter hook input priority 0; policy drop;

        # Разрешаем установленные соединения (ответы на наши запросы)
        ct state established,related accept

        # Разрешаем локальный трафик (loopback)
        iif "lo" accept
        ct state invalid drop

        # Разрешаем ICMP (Ping) для диагностики (v4 и v6)
        # IPv4 Input
        meta nfproto ipv4 icmp type echo-request limit rate 5/second accept
        # IPv6 Input
        # Служебный трафик (Neighbor Discovery) — БЕЗ лимита (критично для работы сети)
        ip6 nexthdr icmpv6 icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
        # Пинг — С лимитом
        ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 5/second accept

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
        # log prefix "NFT_INPUT_DROP: " level info facility local0
        # Убрали facility local0, так как он вызывает ошибку синтаксиса
        log prefix "NFT_INPUT_DROP: " level info
        drop
    }

    # Пакеты, проходящие СКВОЗЬ сервер (Routing/Forwarding)
    chain forward {
        type filter hook forward priority 0; policy drop;
        
        # Разрешает любые ответы на запросы, инициированные твоими клиентами.
        # Такие как  Google с IP (8.8.8.8) и др.
        ct state established,related accept

        # Разрешаем выход из локалки. Разделение потоков IPv4/IPv6 и строгая проверка "КЛИЕНТ -> МИР".
        # IPv4 Forwarding
        meta nfproto ipv4 ip saddr $LOCAL_SUBNET_V4 iifname "$DHCP_INTERFACE" accept
        # IPv6 Forwarding
        meta nfproto ipv6 ip6 saddr $LOCAL_SUBNET_V6 iifname "$DHCP_INTERFACE" accept
       
        # Разрешаем ICMP (Ping) для диагностики сквозь сервер
        meta nfproto ipv4 icmp type echo-request accept
        meta nfproto ipv6 ip6 nexthdr icmpv6 icmpv6 type echo-request accept

        # Логируем пакеты, которые не прошли сквозь шлюз
        # log prefix "NFT_FORWARD_DROP: " level info facility local0
        # Используем только префикс для фильтрации в rsyslog
        log prefix "NFT_FORWARD_DROP: " level info
        drop
    }

    # Пакеты, исходящие с сервера (Output)
    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# Секция NAT (Маскарадинг)
table inet nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        
        # Маскируем весь исходящий трафик с интерфейса
        meta nfproto ipv4 ip saddr $LOCAL_SUBNET_V4 oifname "$DHCP_INTERFACE" masquerade
        meta nfproto ipv6 ip6 saddr $LOCAL_SUBNET_V6 oifname "$DHCP_INTERFACE" masquerade
    }
}

