# /etc/dhcp/dhcpd.conf
# [dhcpd.conf] - Файл настроек dhcp server IPv4 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Sample configuration file for ISC dhcpd

pid-file-name "/var/run/dhcpd/dhcpd.pid";

# Глобальные настройки (Сервер сам является DNS)
option domain-name-servers ${SERVER_IP_V4}, ${GOOGLE_DNS};
option domain-name "${LOCAL_DOMAIN}";

default-lease-time 86400;
max-lease-time 604800;

# Динамическое обновление DNS (если не настроен TSIG, оставляем none)
ddns-update-style none;
# Сервер является единственным/главным в этой сети
authoritative;
# Логирование в /var/log/dhcp/dhcpd.log (обычно попадает в /var/log/syslog)
log-facility local7;

subnet ${LOCAL_SUBNET_V4} netmask ${LOCAL_NETMASK} {
  range ${DHCP_RANGE_START} ${DHCP_RANGE_END};
  option routers ${ROUTER_IP_V4};
  option subnet-mask ${LOCAL_NETMASK};
  option broadcast-address ${LOCAL_BROADCAST};
}

# Резервирование для внешних узлов (исключаем сам сервер, так как он Static)
host gw {
  hardware ethernet ${GW_MAC};
  fixed-address ${GW_IP_V4};
}

host devsrv {
  hardware ethernet ${DEVSRV_MAC};
  fixed-address ${DEVSRV_IP_V4};
}

host srv1C {
  hardware ethernet ${SRV1C_MAC};
  fixed-address ${SRV1C_IP_V4};
}