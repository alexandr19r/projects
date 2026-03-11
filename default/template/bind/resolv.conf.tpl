# /etc/resolv.conf
# [resolv.conf] - Конфигурационный файл резольвер (DNS Resolver Configuration File) 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Локальный IPv6 (аналог 127.0.0.1)
nameserver ::1

# Резервный публичный IPv6 (Google DNS)
nameserver 2001:4860:4860::8888

# Локальный IPv4
nameserver 127.0.0.1

# Резервный публичный IPv4 (Google DNS)
nameserver 8.8.8.8

search ${YOUR_DOMAIN}
options timeout:2
options attempts:3
options rotate