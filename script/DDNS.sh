#!/bin/bash
FILE=/opt/script/ip_address.txt
CF_TOKEN=
CF_ZONE_ID=
CF_RECORD_ID_A=
CF_RECORD_ID_AAAA=
DNS=

OLD_IP=`cat $FILE`
IPv4=`ip a s ppp0 | grep global | grep -oP 'inet \K[\da-f.:]+'`
IPv6=`ip a s ppp0 | grep global | grep -oP 'inet6 \K[\da-f.:]+'`
#IPV4=`ip addr show  ppp0 | grep "global ppp0" | awk '{print $2}'`
#IPv6=`ip addr show  ppp0 | grep "global dynamic" | awk '{print $2}'`

if [ "$IPv6" != "$OLD_IP" ]
then
  echo "Renew IPv4: $IPv4, IPv6: $IPv6"
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID_A" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'$DNS'","content":"'$IPv4'","ttl":60,"proxied":false}' | jq '.'

  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID_AAAA" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"AAAA","name":"'$DNS'","content":"'$IPv6'","ttl":60,"proxied":false}' | jq '.'

  curl -s "https://api.day.app/***secret***/Renew%20IP/IPv4：$IPv4，IPv6：$IPv6?sound=minuet"
  echo $IPv6 > $FILE
else
  echo "No change"
fi
