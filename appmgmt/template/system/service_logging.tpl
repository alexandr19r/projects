# /etc/systemd/system/service@.service.d/logging.conf
# [service_logging.tpl] - универсальный шаблон логирования
# Author: [${AUTHOR}]
# Last Modified: ${LAST_MODIFIED}

[Service]
# %I — это динамическая переменная systemd. 
# Она автоматически подставит имя, указанное после знака @
LogNamespace=%I
StandardOutput=journal
StandardError=journal