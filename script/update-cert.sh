#!/bin/bash

REPO_SSH="git@github.com:22p/ssl-automation"
REPO_DIR="$HOME/.cache/ssl-automation"
CERT_DIR="$HOME/containers/cert"
DOMAIN="example.com"

reload_service() {
  # 这里添加需要重新加载的服务
  podman exec -i nginx nginx -s reload
}

if [ -d "$REPO_DIR/.git" ]; then
  OLD_COMMIT=$(git -C "$REPO_DIR" rev-parse HEAD)

  git -C "$REPO_DIR" fetch origin
  git -C "$REPO_DIR" reset --hard origin/HEAD 
  NEW_COMMIT=$(git -C "$REPO_DIR" rev-parse HEAD)

  if [ "$OLD_COMMIT" != "$NEW_COMMIT" ]; then
    cp $REPO_DIR/certificates/"$DOMAIN".{crt,key} $CERT_DIR/
    reload_service
  fi
else
  git clone "$REPO_SSH" "$REPO_DIR"
  if [ $? -ne 0 ]; then
    echo "[!] Git clone failed."
    exit 1
  fi
  cp $REPO_DIR/certificates/"$DOMAIN".{crt,key} $CERT_DIR/
fi
