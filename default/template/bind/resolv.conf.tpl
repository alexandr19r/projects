# /etc/resolv.conf
# [resolv.conf] - Конфигурационный файл резольвер (DNS Resolver Configuration File) 
# Author: [$AUTHOR]
# Last Modified: $LAST_MODIFIED

# Приоритет: локальный BIND9 (Dual-Stack)
nameserver 127.0.0.1
nameserver ::1

# Резерв (только если BIND упал)
# ВАЖНО: Если BIND работает, он сам сделает форвард на эти адреса
nameserver 8.8.8.8 # FORWARDER_DNS1
nameserver 2001:4860:4860::8888 #FORWARDER_DNS2

search $LOCAL_DOMAIN
options timeout:2
options attempts:2
options rotate