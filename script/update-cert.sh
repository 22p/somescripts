#!/bin/bash
set -euo pipefail

# 配置项
REPO_SSH="git@github.com:22p/ssl-automation"
REPO_DIR="$HOME/.cache/ssl-automation"
CERT_DIR="$HOME/containers/cert"
DOMAIN="example.com"

reload_service() {
  # 这里添加需要重新加载的服务
  podman exec -i nginx nginx -s reload
}

if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" fetch origin
  git -C "$REPO_DIR" reset --hard origin/HEAD
else
  git clone "$REPO_SSH" "$REPO_DIR"
fi

if ! cmp -s "$REPO_DIR/certificates/$DOMAIN.crt" "$CERT_DIR/$DOMAIN.crt"; then
  echo "Certificate updated, copying..."
  cp "$REPO_DIR/certificates/$DOMAIN".{crt,key} "$CERT_DIR/"
  reload_service
else
  echo "No changes in certificate."
fi
