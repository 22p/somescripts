#!/bin/bash

SRV_NAME="Q"
CF_TOKEN=$1
BARK_TOKEN=
TG_BOT_TOKEN=
TG_CHAT_ID=
DNS=
CF_ZONE_ID=
CF_RECORD_ID_A=
CF_RECORD_ID_AAAA=

# Check if the argument is passed
if [ -z "$1" ]; then
  echo "Please provide an argument"
  echo ""
  echo "Usage: $0 <token>"
  echo -e "\ttoken - Your API token with zone permissions"
  exit 1
fi

# 将输入的字符串进行 URL 编码
url_encode() {
  jq -nr --arg v "$1" '$v|@uri'
}

# 定义发送 Bark 通知的函数
# send_bark_notification "标题" "内容" "消息分组" "通知铃声"
send_bark_notification() {
  local title=$(url_encode "$1")
  local message=$(url_encode "$2")
  local group=$(url_encode "$3")
  local sound=$4
  curl -s -o /dev/null "https://api.day.app/$BARK_TOKEN/$title/$message?group=$group&sound=$sound"
}

# 定义发送 Telegram 通知的函数
# https://core.telegram.org/bots/api#markdownv2-style
# send_telegram_notification "标题" "内容"
send_telegram_notification() {
  local title=$(url_encode "$1")
  local message=$(url_encode "$2")
  curl -s -o /dev/null "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&parse_mode=MarkdownV2&text=%2A$title%2A%0A$message"
}

OLD_IP=$(cat /tmp/last_ip.txt 2>/dev/null)
# 从此网卡获取IP
NIC=ppp0
IPv4=$(ip addr show $NIC scope global | grep -oP 'inet \K[\da-f.:]+')
IPv6=$(ip addr show $NIC scope global | grep -oP 'inet6 \K[\da-f.:]+')
#IPv4=$(ip -4 addr show $NIC scope global | grep inet | awk '{print $2}' | cut -d'/' -f1)
#IPv6=$(ip -6 addr show $NIC scope global | grep inet | awk '{print $2}' | cut -d'/' -f1)

# 定义更新DNS记录的函数
update_dns_record() {
  local record_id="$1"
  local ip="$2"
  local record_type="$3"

  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"'$record_type'","name":"'$DNS'","content":"'$ip'","ttl":60,"proxied":false}' | jq -r '.success'
}

# 定义更新DNS HTTPS记录的函数
update_dns_https_record() {
  local record_id="$1"
  local record_type="$2"

  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"'$record_type'","name":"'$DNS'","data":{"priority": 1,"target": ".","value":"alpn=\"h3\" port=\"443\" ipv4hint=\"'$IPv4'\" ipv6hint=\"'$IPv6'\""},"ttl":1,"proxied":false}' | jq -r '.success'
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

  if [ "$CF_SUCCESS_A" == "true" ] && [ "$CF_SUCCESS_AAAA" == "true" ]; then
    echo "Renew IPv4: $IPv4, IPv6: $IPv6"
    send_bark_notification "[Renew IP][$SRV_NAME]" "IPv4：$IPv4，IPv6：$IPv6" "$SRV_NAME" minuet
    send_telegram_notification "\[Renew IP\]\[$SRV_NAME\]" "IPv4: \`$IPv4\`
IPv6 \`$IPv6\`"
    echo $IPv6 >/tmp/last_ip.txt
  else
    echo "Update ERROR :-C"
    send_bark_notification "[Renew IP][$SRV_NAME]" "Update ERROR" "$SRV_NAME" minuet
    send_telegram_notification "\[Renew IP\]\[$SRV_NAME\]" "Update ERROR"
    exit 1
  fi
else
  echo "No change"
fi
