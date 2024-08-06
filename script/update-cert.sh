#!/bin/sh

GITHUB_TOKEN="github_pat_"
BARK_TOKEN=""
REPO_PATH=""
DOMAIN_NAME=""
CERTIFICATE_FILE="/opt/podman/cert/$DOMAIN_NAME.crt"
CERTIFICATE_KEY_FILE="/opt/podman/cert/$DOMAIN_NAME.key"
RELOAD_CMD="podman exec -it nginx nginx -s reload"

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
  # 发送失败通知到Bark
  curl -s -o /dev/null "https://api.day.app/$BARK_TOKEN/SSL%20Download%20Failed/SSL%20download%20has%20failed%20at%20$(date "+%Y-%m-%d%%20%H:%M:%S%%20%Z")?sound=update"
  exit 1
fi

if [ "$OLD_HASH" != "$NEW_HASH" ]; then
  echo "已下载 重新加载服务"
  $RELOAD_CMD
  exit 0
else
  echo "证书未变动"
  exit 0
fi
