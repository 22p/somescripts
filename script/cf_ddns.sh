#!/bin/bash

# 用于更新 Cloudflare DNS 记录的脚本

# source .env
ROOT_DOMAIN=$(echo $FULL_DOMAIN | cut -d '.' -f2-)
OLD_IP=$(cat /tmp/last_ip.txt 2>/dev/null)
IPv4=$(ip addr show $NIC scope global | grep -oP 'inet \K[\da-f.:]+' | head -n 1)
IPv6=$(ip -6 addr show $NIC scope global | grep -v deprecated | grep -oP 'inet6 \K[\da-f:]+' | head -n 1)
#IPv4=$(ip -4 addr show $NIC scope global | awk '/inet / {sub(/\/.*/, "", $2); print $2; exit}')
#IPv6=$(ip -6 addr show $NIC scope global | awk '/inet6 / && !/deprecated/ {sub(/\/.*/, "", $2); print $2; exit}')
#IPv4=$(curl -s -4 ip.sb)
#IPv4=$(curl -s -6 ip.sb)

# send_notifications "标题" "内容" [消息分组] [通知铃声]
send_notifications() {
  local group="${3:-default}"
  local sound="${4:-bell}"

  # 将输入的字符串进行 URL 编码
  url_encode() {
    jq -nr --arg v "$1" '$v|@uri'
  }

  # 发送 Bark 通知
  curl -s -o /dev/null "https://api.day.app/$BARK_TOKEN/$(url_encode "$1")/$(url_encode "$2")?group=$(url_encode "$3")&sound=$4"

  # 发送 Telegram 通知
  # https://core.telegram.org/bots/api#markdownv2-style
  curl -s -o /dev/null "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&parse_mode=MarkdownV2&text=%2A$(url_encode "$1")%2A%0A$(url_encode "$2")"

}

# 获取Zone ID和DNS记录ID的函数
get_zone_and_record_id() {
  ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].id')

  if [ "$ZONE_ID" == "null" ]; then
    echo "无法获取Zone ID，请检查域名和 API 令牌是否正确。"
    exit 1
  fi

  RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$FULL_DOMAIN" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $CF_TOKEN")

  RECORD_ID_A=$(echo $RECORDS | jq -r '.result[] | select(.type == "A") | .id' | head -n 1)
  RECORD_ID_AAAA=$(echo $RECORDS | jq -r '.result[] | select(.type == "AAAA") | .id' | head -n 1)
  RECORD_ID_HTTPS=$(echo $RECORDS | jq -r '.result[] | select(.type == "HTTPS") | .id' | head -n 1)
  RECORD_ID_SVCB=$(echo $RECORDS | jq -r '.result[] | select(.type == "SVCB") | .id' | head -n 1)
}

# 定义更新DNS记录的函数
update_dns_record() {
  local record_id="$1" ip="$2" record_type="$3"
  local data_json=$(jq -n \
    --arg type "$record_type" \
    --arg name "$FULL_DOMAIN" \
    --arg content "$ip" \
    '{type: $type, name: $name, content: $content, ttl: 60, proxied: false}')

  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$data_json" | jq -r '.success'
}

# 定义更新DNS HTTPS记录的函数
update_dns_https_record() {
  local record_id="$1" record_type="$2"
  local value_params=""

  [[ -n "$HTTPS_ALPN" ]] && value_params+="alpn=$HTTPS_ALPN "
  [[ -n "$HTTPS_PORT" ]] && value_params+="port=$HTTPS_PORT "
  [[ -n "$ECH" ]] && value_params+="ech=$ECH "
  [[ -n "$IPv4" ]] && value_params+="ipv4hint=$IPv4 "
  [[ -n "$IPv6" ]] && value_params+="ipv6hint=$IPv6 "
  value_params="${value_params%% }"

  local data_json=$(jq -n \
    --arg type "$record_type" \
    --arg name "$FULL_DOMAIN" \
    --arg value "$value_params" \
    '{
      type: $type,
      name: $name,
      data: {
        priority: 1,
        target: ".",
        value: $value
      },
      ttl: 1,
      proxied: false
    }')

  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$data_json" | jq -r '.success'
}

if [ "$IPv6" != "$OLD_IP" ]; then
  get_zone_and_record_id
  # 更新IPv4记录
  SUCCESS_A=$(update_dns_record "$RECORD_ID_A" "$IPv4" "A")
  # 更新IPv6记录
  SUCCESS_AAAA=$(update_dns_record "$RECORD_ID_AAAA" "$IPv6" "AAAA")
  # 更新HTTPS记录
  SUCCESS_HTTPS=$(update_dns_https_record "$RECORD_ID_HTTPS" "HTTPS")
  # 更新SVCB记录
  # SUCCESS_SVCB=$(update_dns_https_record "$RECORD_ID_SVCB" "SVCB")

  if [ "$SUCCESS_A" == "true" ] && [ "$SUCCESS_AAAA" == "true" ]; then
    echo "Renew IPv4: $IPv4, IPv6: $IPv6"
    send_notifications "⟦Renew IP⟧⟦$SRV_NAME⟧" "IPv4: \`$IPv4\`
IPv6: \`$IPv6\`" "$SRV_NAME" minuet
    echo "$IPv6" >/tmp/last_ip.txt
  else
    echo "Update ERROR :-C"
    send_notifications "⟦Renew IP⟧⟦$SRV_NAME⟧" "Update ERROR" "$SRV_NAME" minuet
    exit 1
  fi
else
  echo "No change"
fi
