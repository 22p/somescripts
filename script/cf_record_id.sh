#!/bin/bash

# 用法: cf_record_id.sh ***cf_token*** example.com home.example.com
CF_TOKEN=$1
# 区域名称, 例如: example.com
ZONE_NAME=$2
# 要更新的主机名, 例如: home.example.com
DNS=$3

CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].id')

RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$DNS" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $CF_TOKEN")

echo "DNS=$DNS"
echo "CF_ZONE_ID=$CF_ZONE_ID"
echo "CF_RECORD_ID_A=$(echo $RECORDS | jq -r '.result[] | select(.type == "A") | .id')"
echo "CF_RECORD_ID_AAAA=$(echo $RECORDS | jq -r '.result[] | select(.type == "AAAA") | .id')"
