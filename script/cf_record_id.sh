#!/bin/bash

# Check if the argument is passed
if [ -z "$1" ]; then
    echo "Please provide an argument"
    echo ""
    echo "Usage: $0 <token> <hostname>"
    echo -e "\ttoken - Your API token with zone permissions"
    echo -e "\thostname - The domain name used for DDNS"
    exit 1
fi

CF_TOKEN=$1
# 要更新的主机名, 例如: home.example.com
DNS=$2
# 区域名称, 例如: example.com
ZONE_NAME=$(echo $DNS | cut -d '.' -f2-)

CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].id')

CF_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$DNS" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $CF_TOKEN")

echo "DNS=$DNS"
echo "CF_ZONE_ID=$CF_ZONE_ID"
echo "CF_RECORD_ID_A=$(echo $CF_RECORD | jq -r '.result[] | select(.type == "A") | .id')"
echo "CF_RECORD_ID_AAAA=$(echo $CF_RECORD | jq -r '.result[] | select(.type == "AAAA") | .id')"
