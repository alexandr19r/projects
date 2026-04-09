// /etc/bind/
// [named.conf.logging] - Настройка логирования DNS
// Author: [$AUTHOR]
// Last Modified: $LAST_MODIFIED

// Определяем каналы логирования
logging {
    // Канал для детальной записи всех DNS-запросов клиентов
    channel queries_file {
        file "$QUERIESLOG_DNS" versions 3 size 5m;
        severity info;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    
    // Канал для системных событий (интеграция с rsyslog через local6)
    channel syslog_errors {
        syslog local6;
        severity info;
        print-category yes;
        print-severity yes;
    };

    // Направление потоков
    category queries { queries_file; };     // Все запросы клиентов
    category default { syslog_errors; };    // Общие события
    category config { syslog_errors; };     // Ошибки синтаксиса
    category security { syslog_errors; };   // Отказы в доступе (ACL)
    category lame-servers { null; };        // Игнорируем ошибки чужих серверов (чтобы не забивать лог)
};