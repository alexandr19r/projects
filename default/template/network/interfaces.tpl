# /etc/network/interfaces
# [interfaces] - Конфигурационный файл сетевых настроек
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
#IPv4
iface lo inet loopback
#IPv6
iface lo inet6 loopback

# Auto start network interface
auto eth0

# IPv4
# The primary network interface
# (DHCP)
#iface eth0 inet dhcp
# (STATIC)
iface eth0 inet static
    address 10.10.100.1
    netmask 255.255.255.0
    gateway 10.10.100.2
    # Закомментируйте, если используете свой шаблон /etc/resolv.conf
    # dns-nameservers 127.0.0.1 8.8.8.8

# IPv6
# The primary network interface v6
# (DHCP)
#iface eth0 inet6 dhcp
# (STATIC)
iface eth0 inet6 static
    address fc00:db9:aaaa::1
    netmask 64
    gateway fc00:db9:aaaa::2
    # Закомментируйте, чтобы система не лезла в /etc/resolv.conf
    # dns-nameservers ::1 2001:4860:4860::8888