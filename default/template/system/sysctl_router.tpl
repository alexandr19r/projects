# /etc/sysctl.d/99-nftables-router.conf
# [nftables-router.conf] - Доработка ядра Linux для роутинга
# Author: [$AUTHOR]
# Last Modified: $LAST_MODIFIED

# --- [ IPv4 Forwardings ] ---
# Включить пересылку пакетов
net.ipv4.ip_forward=1

# --- [ IPv4 Redirects ] ---
# Отключаем отправку редиректов (чтобы не выдавать присутствие роутера)
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.$DHCP_INTERFACE.send_redirects=0

# Отключаем прием редиректов (защита от MITM атак)
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.$DHCP_INTERFACE.accept_redirects=0

# --- [ IPv6 Forwardings ] ---
# Включить пересылку пакетов
net.ipv6.conf.all.forwarding=1

# --- [ IPv6 Redirects ] ---
# В IPv6 это настраивается через accept_redirects (отправка регулируется самим стеком forwarding)
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.$DHCP_INTERFACE.accept_redirects=0
