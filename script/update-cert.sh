#!/bin/sh

source /opt/script/.config
# 从 GitHub 私有仓库下载证书
curl -s -L \
  -H "Accept: application/vnd.github.raw+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPOS/contents/$DNS/fullchain.pem?ref=certs -o $PODMAN_DIR/cert/fullchain.pem
curl -s -L \
  -H "Accept: application/vnd.github.raw+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPOS/contents/$DNS/private.key?ref=certs -o $PODMAN_DIR/cert/private.key

if grep -q "BEGIN CERTIFICATE" $PODMAN_DIR/cert/fullchain.pem; then
  # 重新加载Nginx配置文件
  podman exec -it nginx nginx -s reload
  echo "已下载"
else
  echo -e "\033[31m没有找到证书，请检查Git仓库。\033[0m"
  exit 1
fi
