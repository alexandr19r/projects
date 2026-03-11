# /etc/dhcp/dhcpd6.conf
# [dhcpd6.conf] - Файл настроек dhcp server IPv6 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Server configuration file example for DHCPv6
# From the file used for TAHI tests - addresses chosen
# to match TAHI rather than example block.

# Настройки для логов IPv6 (также используем local7)
log-facility local7;

# Глобальные настройки времени аренды
default-lease-time 2592000;
preferred-lifetime 604800;
option dhcp-renewal-time 3600;
option dhcp-rebinding-time 7200;

# Настройки DNS для IPv6
option dhcp6.name-servers ${YOUR_SERVER_IPV6}, 2001:4860:4860::8888;
option dhcp6.domain-search "${YOUR_DOMAIN}";
option dhcp6.info-refresh-time 21600;

allow leasequery;

# Описание подсети
subnet6 ${YOUR_NETWORK_IPV6} {
    # Динамический диапазон (смещаем, чтобы не занять статические IP)
    range6 ${DHCP6_RANGE_START} ${DHCP6_RANGE_END};
}

host gw {
    # Идентификатор клиента (DUID). В IPv6 это заменяет MAC-адрес.
    host-identifier option dhcp6.client-id ${GW_DUID};
    
    # Фиксированный IPv6 адрес
    fixed-address6 ${GW_IPV6};
}

host devsrv {
    host-identifier option dhcp6.client-id ${DEVSRV_DUID};
    fixed-address6 ${DEVSRV_IPV6};
}

host srv1C {
    host-identifier option dhcp6.client-id ${SRV1C_DUID};
    fixed-address6 ${SRV1C_IPV6};
}