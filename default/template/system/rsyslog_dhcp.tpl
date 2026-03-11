# /etc/rsyslog.d/dhcpd.conf
# [rsyslog_dhcp.tpl] - Шаблон настроек логирования dhcp 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Направляем сообщения с меткой local7 в отдельный файл
local7.*    /var/log/dhcp/dhcpd.log
# Остановка дальнейшей обработки, чтобы не дублировать в syslog
& stop