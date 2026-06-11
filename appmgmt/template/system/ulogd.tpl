[global]
logfile="stdout"
loglevel=3
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_inppkt_NFLOG.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_BASE.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_output_JSON.so"

stack=input_log:NFLOG,base1:BASE,json1:JSON
stack=forward_log:NFLOG,base2:BASE,json2:JSON

[input_log]
group=10

[forward_log]
group=20

[json1]
file="stdout"

[json2]
file="stdout"