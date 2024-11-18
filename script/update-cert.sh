#!/bin/bash

# source .env

# 定义重新加载服务的函数
reload_service() {
  # 这里添加需要重新加载的服务
  podman exec -it nginx nginx -s reload
}

# 获取当前证书哈希值
OLD_HASH=$(sha256sum $CERTIFICATE_DIR/$FULL_DOMAIN.crt 2>/dev/null)

for FILE in $FULL_DOMAIN.crt $FULL_DOMAIN.key; do
  curl -sfL \
    -H "Accept: application/vnd.github.raw+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$GITHUB_REPO/contents/certificates/$FILE?ref=main -o $CERTIFICATE_DIR/$FILE

  if [ $? -ne 0 ]; then
    echo -e "\033[31m下载错误，请检查。\033[0m"
    exit 1
  fi
done

# 获取新哈希值
NEW_HASH=$(sha256sum $CERTIFICATE_DIR/$FULL_DOMAIN.crt 2>/dev/null)

if [ "$OLD_HASH" != "$NEW_HASH" ]; then
  echo "已下载 重新加载服务"
  reload_service
  exit 0
else
  echo "证书未变动"
  exit 0
fi
