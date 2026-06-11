[global]
logfile="stdout"
loglevel=3

plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_inppkt_NFLOG.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IFINDEX.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_filter_IP2STR.so"
plugin="/usr/lib/x86_64-linux-gnu/ulogd/ulogd_output_JSON.so"

stack=nft_input_log:NFLOG,idx1:IFINDEX,ip2str1:IP2STR,json1:JSON
stack=nft_forward_log:NFLOG,idx2:IFINDEX,ip2str2:IP2STR,json2:JSON

[nft_input_log]
group=10

[nft_forward_log]
group=20

[json1]
file="stdout"

[json2]
file="stdout"
