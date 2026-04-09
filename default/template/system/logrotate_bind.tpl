# /etc/logrotate.d/named
# [logrotate_bind.tpl] - Шаблон выделенного лога (Rsyslog)
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

${RSYSLOG_DNS} {
    daily
    rotate 7
    # ВАЖНО: Создавать новый файл с правами владелец bind, группа adm
    create 0640 bind adm
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}