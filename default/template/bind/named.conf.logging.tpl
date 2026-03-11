// /etc/bind/
// [named.conf.logging] - файл конфигурации логирования bind
// Author: [${AUTHOR}]
// Last Modified: ${LAST_MODIFIED}

// Определяем каналы логирования
logging {
    # Канал для записи запросов в файл
    channel queries_file {
        file "/var/log/named/queries.log" versions 3 size 5m;
        severity info;
        print-time yes;
        print-category yes;
    };

    # Канал для системных уведомлений и ошибок
    channel syslog_errors {
        syslog local6;
        severity info;
        print-category yes;
        print-severity yes;
    };

    # Запросы направляем в файл
    category queries { queries_file; };
    
    # Все системные сообщения (старт, ошибки, уведомления) в syslog
    category default { syslog_errors; };
    category config { syslog_errors; };
    category security { syslog_errors; };
};