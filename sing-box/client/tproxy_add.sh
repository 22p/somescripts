#!/bin/bash

if [ "$1" = "add" ]; then 
  if ! ip rule | grep 0x440 >/dev/null 2>&1; then 
  nft -f /etc/nftables/tproxy/tproxy.nft
  ip rule add fwmark 1088 table 100
  ip route add local default dev lo table 100
  ip -6 rule add fwmark 1088 table 100
  ip -6 route add local default dev lo table 100
  echo "ip rule has been added"
  fi
elif [ "$1" = "del" ]; then
  if ip rule | grep 0x440 >/dev/null 2>&1; then
  nft delete table inet TProxy
  ip route del local default dev lo table 100
  ip rule del table 100
  ip -6 route del local default dev lo table 100
  ip -6 rule del table 100
  echo "ip rule has been deleted"
  fi
else
  echo "未知的操作: $1"
  echo "用法: tproxy_add.sh add|del"
 fi
