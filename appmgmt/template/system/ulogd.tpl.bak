# /etc/ulogd.conf
# [ulogd.conf] - Конфигурационный файл лщгирования ulogd
# Author: [$AUTHOR]
# Last Modified: $LAST_MODIFIED

# Перенаправляем внутренние логи ulogd в stdout
[global]
logfile="stdout"
loglevel=3

# Настройка стека для цепочки INPUT (группа 10)
stack=input_log:NFLOG,base1:BASE,json1:JSON

# Настройка стека для цепочки FORWARD (группа 20)
stack=forward_log:NFLOG,base2:BASE,json2:JSON

[input_log]
group=10

[forward_log]
group=20

# Перенаправляем логи пакетов INPUT в stdout юнита systemd
[json1]
file="stdout"

# Перенаправляем логи пакетов FORWARD в stdout юнита systemd
[json2]
file="stdout"