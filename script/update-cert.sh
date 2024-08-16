#!/bin/sh

SRV_NAME="Q"
GITHUB_TOKEN="github_pat_"
BARK_TOKEN=""
TG_BOT_TOKEN=""
TG_CHAT_ID=""
REPO_PATH=""
DOMAIN_NAME=""
CERTIFICATE_FILE="/opt/podman/cert/$DOMAIN_NAME.crt"
CERTIFICATE_KEY_FILE="/opt/podman/cert/$DOMAIN_NAME.key"

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

# 定义重新加载服务的函数
reload_service() {
  # 这里添加需要重新加载的服务
  podman exec -it nginx nginx -s reload
}

# 获取当前证书哈希值
OLD_HASH=$(sha256sum $CERTIFICATE_FILE 2>/dev/null)

# 从 GitHub 私有仓库下载证书
curl -s -L \
  -H "Accept: application/vnd.github.raw+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPO_PATH/contents/certificates/$DOMAIN_NAME.crt?ref=main -o $CERTIFICATE_FILE
curl -s -L \
  -H "Accept: application/vnd.github.raw+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPO_PATH/contents/certificates/$DOMAIN_NAME.key?ref=main -o $CERTIFICATE_KEY_FILE

# 获取新哈希值
NEW_HASH=$(sha256sum $CERTIFICATE_FILE 2>/dev/null)

if ! grep -q "BEGIN CERTIFICATE" $CERTIFICATE_FILE 2>/dev/null; then
  echo -e "\033[31m证书文件错误，请检查。\033[0m"
  send_bark_notification "❌[证书下载失败][$SRV_NAME]" "请检查" "$SRV_NAME" update
  send_telegram_notification "❌\[证书下载失败\]\[$SRV_NAME\]" "请检查"
  exit 1
fi

if [ "$OLD_HASH" != "$NEW_HASH" ]; then
  echo "已下载 重新加载服务"
  reload_service
  send_bark_notification "✅[证书更新成功][$SRV_NAME]" "已重新加载服务" "$SRV_NAME" update
  send_telegram_notification "✅\[证书更新成功\]\[$SRV_NAME\]" "已重新加载服务"
  exit 0
else
  echo "证书未变动"
  exit 0
fi
