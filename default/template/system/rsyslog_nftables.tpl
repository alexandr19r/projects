# /etc/rsyslog.d/nftables.conf
# [rsyslog_nftables.tpl] - Шаблон настроек логирования dhcp 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

# Направляем сообщения с меткой local0 в отдельный файл
# local0.*    ${RSYSLOG_NFTABLES}
# Ищем сообщения, содержащие наши префиксы NFT_
:msg, contains, "NFT_INPUT_DROP: "  ${RSYSLOG_NFTABLES}
:msg, contains, "NFT_FORWARD_DROP: " ${RSYSLOG_NFTABLES}
# Остановка дальнейшей обработки, чтобы не дублировать в syslog
# Остановка дальнейшей обработки этих сообщений, чтобы не забивать /var/log/syslog и kern.log
& stop