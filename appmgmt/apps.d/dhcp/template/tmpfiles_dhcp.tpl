# /etc/tmpfiles.d/dhcpd.conf
# [tmpfiles_dhcp.tpl] - Шаблон создания папки для файлов PID, после перезагрузки
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

d /var/run/dhcpd 0755 root root -