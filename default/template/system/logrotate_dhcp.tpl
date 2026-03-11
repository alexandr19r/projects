# /etc/logrotate.d/dhcpd
# [logrotate_dhcp.tpl] - Шаблон выделенного лога (Rsyslog)
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

/var/log/dhcp/dhcpd.log {
    daily
    rotate 7
    # ВАЖНО: Создавать новый файл с правами владелец syslog, группа adm
    create 0640 syslog adm
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}