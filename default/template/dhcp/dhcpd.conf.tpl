# /etc/dhcp/dhcpd.conf
# [dhcpd.conf] - Файл настроек dhcp server IPv4 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Sample configuration file for ISC dhcpd

# Глобальные настройки (Сервер сам является DNS)
option domain-name-servers ${YOUR_SERVER_IP}, ${GOOGLE_DNS};
option domain-name "${YOUR_DOMAIN}";

default-lease-time 86400;
max-lease-time 604800;

# Динамическое обновление DNS (если не настроен TSIG, оставляем none)
ddns-update-style none;
# Сервер является единственным/главным в этой сети
authoritative;
# Логирование в /var/log/dhcp/dhcpd.log (обычно попадает в /var/log/syslog)
log-facility local7;

subnet ${YOUR_NETWORK_ADDR} netmask ${YOUR_NETMASK} {
  range ${DHCP_RANGE_START} ${DHCP_RANGE_END};
  option routers ${YOUR_GATEWAY};
  option subnet-mask ${YOUR_NETMASK};
  option broadcast-address ${YOUR_BROADCAST};
}

# Резервирование для внешних узлов (исключаем сам сервер, так как он Static)
host gw {
  hardware ethernet ${GW_MAC};
  fixed-address ${GW_IP};
}

host devsrv {
  hardware ethernet ${DEVSRV_MAC};
  fixed-address ${DEVSRV_IP};
}

host srv1C {
  hardware ethernet ${SRV1C_MAC};
  fixed-address ${SRV1C_IP};
}