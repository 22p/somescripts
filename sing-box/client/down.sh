#!/bin/bash

if ip rule | grep 0x440 >/dev/null 2>&1; then
nft delete table inet TProxy
ip route del local default dev lo table 100
ip rule del table 100
ip -6 route del local default dev lo table 100
ip -6 rule del table 100
echo "ip rule has been deleted"
fi
