#!/bin/sh

CERT_DIR=/opt/podman/cert
DNS=
GITHUB_TOKEN=
REPOS=

# 从 GitHub 私有仓库下载证书
curl -s -L \
  -H "Accept: application/vnd.github.raw+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPOS/contents/certificates/$DNS.crt?ref=main -o $CERT_DIR/$DNS.crt
curl -s -L \
  -H "Accept: application/vnd.github.raw+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPOS/contents/certificates/$DNS.key?ref=main -o $CERT_DIR/$DNS.key

if grep -q "BEGIN CERTIFICATE" $CERT_DIR/$DNS.crt; then
  # 重新加载Nginx配置文件
  podman exec -it nginx nginx -s reload
  echo "已下载"
else
  echo -e "\033[31m没有找到证书，请检查Git仓库。\033[0m"
  exit 1
fi