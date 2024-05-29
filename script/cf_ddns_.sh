#!/bin/bash
FILE=/opt/script/ip_address.txt
# 用法: cf_ddns.sh ***cf_token***
CF_TOKEN=$1
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

# 定义更新DNS记录的函数
update_dns_record() {
  local RECORD_ID="$1"
  local IP="$2"
  local RECORD_TYPE="$3"

    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"'$RECORD_TYPE'","name":"'$DNS'","content":"'$IP'","ttl":60,"proxied":false}' | jq -r '.success'
}
# 定义更新DNS HTTPS记录的函数
update_dns_https_record() {
  local RECORD_ID="$1"
  local RECORD_TYPE="$2"

  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"'$RECORD_TYPE'","name":"'$DNS'","data":{"priority": 1,"target": ".","value":"alpn=\"h3\" port=\"443\" ipv4hint=\"'$IPv4'\" ipv6hint=\"'$IPv6'\""},"ttl":1,"proxied":false}' | jq -r '.success'
}

if [ "$IPv6" != "$OLD_IP" ]; then
  # 更新IPv4记录
  CF_SUCCESS_A=$(update_dns_record "$CF_RECORD_ID_A" "$IPv4" "A")
  # 更新IPv6记录
  CF_SUCCESS_AAAA=$(update_dns_record "$CF_RECORD_ID_AAAA" "$IPv6" "AAAA")
  # 更新HTTPS记录
  # update_dns_https_record "$CF_RECORD_ID_HTTPS" "HTTPS"
  # 更新SVCB记录
  # update_dns_https_record "$CF_RECORD_ID_SVCB" "SVCB"

     if [ "$CF_SUCCESS_A" == "true" ] && [ "$CF_SUCCESS_AAAA" == "true" ]
    then
      echo "Renew IPv4: $IPv4, IPv6: $IPv6"
      curl -s "https://api.day.app/***secret***/Renew%20IP/IPv4：$IPv4，IPv6：$IPv6?sound=minuet"
      echo $IPv6 > $FILE
    else
      echo "Update ERROR :-C"
      exit 1
    fi
else
  echo "No change"
fi
