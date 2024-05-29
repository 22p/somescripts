#!/bin/bash
FILE=/opt/script/ip_address.txt
# 用法: cf_ddns.sh ***cf_token***
CF_TOKEN=$1
BARK_TOKEN=
TG_BOT_TOKEN=
TG_CHAT_ID=
DNS=
CF_ZONE_ID=
CF_RECORD_ID_A=
CF_RECORD_ID_AAAA=

OLD_IP=$(cat $FILE)
# 从此网卡获取IP
NIC=ppp0
IPv4=$(ip a s $NIC | grep global | grep -oP 'inet \K[\da-f.:]+')
IPv6=$(ip a s $NIC | grep global | grep -oP 'inet6 \K[\da-f.:]+')
#IPv4=$(ip addr show  $NIC | grep "global $NIC" | awk '{print $2}')
#IPv6=$(ip addr show  $NIC | grep "global dynamic" | awk '{print $2}' | cut -d'/' -f1 | sed -n '1p')

if [ "$IPv6" != "$OLD_IP" ]
then
  # IPv4
  CF_SUCCESS_A=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID_A" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'$DNS'","content":"'$IPv4'","ttl":60,"proxied":false}' | jq -r '.success')
  # IPv6
  CF_SUCCESS_AAAA=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID_AAAA" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"AAAA","name":"'$DNS'","content":"'$IPv6'","ttl":60,"proxied":false}' | jq -r '.success')

    if [ "$CF_SUCCESS_A" == "true" ] && [ "$CF_SUCCESS_AAAA" == "true" ]
    then
      echo "Renew IPv4: $IPv4, IPv6: $IPv6"
      curl -s "https://api.day.app/$BARK_TOKEN/Renew%20IP/IPv4：$IPv4，IPv6：$IPv6?sound=minuet"
      curl -s "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&parse_mode=MarkdownV2&text=%5C%5BRenew%20IP%5C%5D%0AIPv4%3A%60$IPv4%60%0AIPv6%3A%60$IPv6%60"
      echo $IPv6 > $FILE
    else
      echo "Update ERROR :-C"
      exit 1
    fi
else
  echo "No change"
fi
