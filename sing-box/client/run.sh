#!/bin/bash

if ! ip rule | grep 0x440 >/dev/null 2>&1; then 
nft -f /etc/nftables/tproxy/tproxy.nft
ip rule add fwmark 1088 table 100
ip route add local default dev lo table 100
ip -6 rule add fwmark 1088 table 100
ip -6 route add local default dev lo table 100
echo "ip rule has been added"
fi
