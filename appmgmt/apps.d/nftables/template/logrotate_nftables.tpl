# /etc/logrotate.d/nftables
# [logrotate_nftables.tpl] - Шаблон выделенного лога (Rsyslog)
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

${RSYSLOG_NFTABLES} {
    daily
    rotate 7
    # ВАЖНО: Создавать новый файл с правами владелец nftables, группа adm
    create 0640 syslog adm
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
