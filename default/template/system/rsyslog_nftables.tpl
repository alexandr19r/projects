# /etc/rsyslog.d/nftables.conf
# [rsyslog_nftables.tpl] - Шаблон настроек логирования dhcp 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Направляем сообщения с меткой local0 в отдельный файл
local0.*    ${RSYSLOG_NFTABLES}
# Остановка дальнейшей обработки, чтобы не дублировать в syslog
& stop
