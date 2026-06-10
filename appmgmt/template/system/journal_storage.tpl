# /etc/systemd/journald@${SERVICE}.service.d/storage.conf
# [journal_storage.tpl] - Шаблон дисковых лимитов для Namespace 
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

[Journal]
Storage=persistent
# Лимит диска, определенный для конкретного сервиса
SystemMaxUse=${JOURNAL_MAX}
# Срок хранения, определенный для конкретного сервиса
MaxRetentionSec=${JOURNAL_RETENTION}