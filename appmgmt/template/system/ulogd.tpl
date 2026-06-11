[global]
logfile="stdout"
loglevel=3

# Правильные пути к плагинам в Debian
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_inppkt_NFLOG.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_PRINTPKT.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_output_JSON.so"

# Меняем BASE на PRINTPKT внутри описания стеков
stack=input_log:NFLOG,base1:PRINTPKT,json1:JSON
stack=forward_log:NFLOG,base2:PRINTPKT,json2:JSON

[input_log]
group=10

[forward_log]
group=20

[json1]
file="stdout"

[json2]
file="stdout"