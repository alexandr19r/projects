# /etc/default/isc-dhcp-server
# [isc-dhcp-server] - Главный файл настроек dhcp server 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Defaults for isc-dhcp-server (sourced by /etc/init.d/isc-dhcp-server)

# Path to dhcpd's config file (default: /etc/dhcp/dhcpd.conf).
DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
DHCPDv6_CONF=/etc/dhcp/dhcpd6.conf

# Path to dhcpd's PID file (default: /run/dhcp-server/dhcpd.pid).
DHCPDv4_PID=/run/dhcp-server/dhcpd.pid
DHCPDv6_PID=/run/dhcp-server/dhcpd6.pid

# Additional options to start dhcpd with.
#       Don't use options -cf or -pf here; use DHCPD_CONF/ DHCPD_PID instead
#OPTIONS=""

# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
#       Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACESv4="${DHCP_INTERFACE}"
INTERFACESv6="${DHCP_INTERFACE}"