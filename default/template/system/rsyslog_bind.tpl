# /etc/rsyslog.d/named.conf
# [rsyslog_bind.tpl] - Шаблон настроек логирования bind 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Направляем сообщения с меткой local6 в отдельный файл
local6.*    /var/log/named/named.log
# Остановка дальнейшей обработки, чтобы не дублировать в syslog
& stop
