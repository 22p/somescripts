#!/bin/bash
# 修改为你的mark值，使用16进制
FWMARK=0x440
if [ "$1" = "add" ]; then 
  if ! ip rule | grep $FWMARK >/dev/null 2>&1; then 
  nft -f /etc/nftables/proxy/tproxy.nft
  ip rule add fwmark $FWMARK table 100
  ip route add local default dev lo table 100
  ip -6 rule add fwmark $FWMARK table 100
  ip -6 route add local default dev lo table 100
  echo "ip rule has been added"
  fi
elif [ "$1" = "del" ]; then
  if ip rule | grep $FWMARK >/dev/null 2>&1; then
  nft delete table inet proxy
  ip route del local default dev lo table 100
  ip rule del table 100
  ip -6 route del local default dev lo table 100
  ip -6 rule del table 100
  echo "ip rule has been deleted"
  fi
else
  echo "Invalid argument"
  echo ""
  echo "Usage: $0 [add|del]"
  exit 1
 fi
