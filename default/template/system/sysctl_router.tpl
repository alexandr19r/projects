# /etc/sysctl.d/99-nftables-router.conf
# [nftables-router.conf] - Доработка ядра Linux для роутинга
# Author: [$AUTHOR]
# Last Modified: $LAST_MODIFIED

net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.$DHCP_INTERFACE.send_redirects=0