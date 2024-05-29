#/bin/sh

if [ `id -u` -lt 1000 ]; then
  echo "请使用用户账户运行"
  exit 1
fi

################################################
#               Variable header                #
################################################
# Podman 目录
PODMAN_DIR=/opt/podman
# Github Token
GITHUB_TOKEN=
# 私有Github 仓库
REPOS=
# 获取用户输入
read -p "请输入域名：" DNS
read -p "请输入要监听的端口号：" LISTENPORT
read -p "请输入服务器标签：" TAG

UUID=$(podman run --rm ghcr.io/sagernet/sing-box:latest generate uuid)
X25519=$(podman run --rm ghcr.io/sagernet/sing-box:latest generate reality-keypair)
SHORTID=$(podman run --rm ghcr.io/sagernet/sing-box:latest generate rand --hex 8)
PASSWORD=$(podman run --rm ghcr.io/sagernet/sing-box:latest generate rand --base64 12)

echo "创建podmam运行目录 可能需要sudo密码"
sudo mkdir -p $PODMAN_DIR
sudo chown -R `id -u`:`id -g` $PODMAN_DIR
sudo mkdir -p /opt/script
sudo chown -R `id -u`:`id -g` /opt/script

#User Quadlet 目录
mkdir -p ~/.config/containers/systemd
# User systemd 目录
mkdir -p ~/.config/systemd/user
# 设置SELinux标签
chcon -R -t container_file_t $PODMAN_DIR >/dev/null 2>&1
# sing-box 目录
mkdir -p $PODMAN_DIR/sing-box
################################################
#                 Header end                   #
################################################

ssl_operation() {
# SSL 目录
mkdir -p $PODMAN_DIR/cert

cat >/opt/script/.config <<-EOF
PODMAN_DIR=$PODMAN_DIR
DNS=$DNS 
GITHUB_TOKEN=$GITHUB_TOKEN
REPOS=$REPOS
EOF

curl -Lso /opt/script/update-cert.sh https://raw.githubusercontent.com/22p/somescripts/main/script/update-cert.sh
curl -Lso ~/.config/systemd/user/update-cert.service https://raw.githubusercontent.com/22p/somescripts/main/systemd/update-cert.service
curl -Lso ~/.config/systemd/user/update-cert.timer https://raw.githubusercontent.com/22p/somescripts/main/systemd/update-cert.timer
chmod +x /opt/script/update-cert.sh
systemctl --user daemon-reload
systemctl --user --now enable update-cert.service
systemctl --user --now enable update-cert.timer
exit

}

nginx_operation(){
# Nginx 目录
mkdir -p $PODMAN_DIR/www/nginx_conf
mkdir -p $PODMAN_DIR/www/wwwroot/default
mkdir -p $PODMAN_DIR/www/wwwlogs
curl https://ssl-config.mozilla.org/ffdhe2048.txt > /opt/podman/cert/dhparams.pem
curl -Lso $PODMAN_DIR/www/nginx_conf/default.conf https://raw.githubusercontent.com/22p/somescripts/main/nginx/default.conf
curl -Lso $PODMAN_DIR/www/nginx_conf/default.ssl https://raw.githubusercontent.com/22p/somescripts/main/nginx/default.ssl
curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/Quadlet/nginx.container | sed "s,/opt/podman,$PODMAN_DIR,g" > ~/.config/containers/systemd/nginx.container

systemctl --user daemon-reload
sleep 3
systemctl --user --now enable nginx.service
}

sb_tuic_operation (){
# 通用
curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/Quadlet/sing-box.container | sed "s,/opt/podman,$PODMAN_DIR,g" > ~/.config/containers/systemd/sing-box.container
curl -Lso $PODMAN_DIR/sing-box/00-log.json https://raw.githubusercontent.com/22p/somescripts/main/sing-box/server/00-log.json
# TUIC
curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/sing-box/server/02-inbounds-tuic.json \
  | jq ".inbounds[0].listen_port = $LISTENPORT \
  | .inbounds[0].users[0].uuid = \"$UUID\" \
  | .inbounds[0].users[0].password = \"$PASSWORD\"" > "$PODMAN_DIR/sing-box/02-inbounds-tuic.json"

curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/sing-box/client/03-outbounds-tuic.json \
  | jq ".outbounds[0].tag =  \"$TAG\" \
  | .outbounds[0].server =  \"`curl -s4 ip.sb`\" \
  | .outbounds[0].server_port = $LISTENPORT \
  | .outbounds[0].uuid = \"$UUID\" \
  | .outbounds[0].password = \"$PASSWORD\" \
  | .outbounds[0].tls.server_name = \"$DNS\"" \
  | tee 03-outbounds-tuic.json
echo "客户端配置文件保存在当前目录下"

systemctl --user daemon-reload
systemctl --user restart sing-box.service
}

sb_vless_vision_reality_operation (){
# 通用
curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/Quadlet/sing-box.container | sed "s,/opt/podman,$PODMAN_DIR,g" > ~/.config/containers/systemd/sing-box.container
curl -Lso $PODMAN_DIR/sing-box/00-log.json https://raw.githubusercontent.com/22p/somescripts/main/sing-box/server/00-log.json
# VLESS+Vision+REALITY
curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/sing-box/server/02-inbounds-reality.json \
  | jq ".inbounds[0].listen_port = $LISTENPORT \
  | .inbounds[0].users[0].uuid = \"$UUID\" \
  | .inbounds[0].tls.server_name = \"$DNS\" \
  | .inbounds[0].tls.reality.private_key = \"`echo $X25519 | awk '{print $2}'`\" \
  | .inbounds[0].tls.reality.short_id = \"$SHORTID\"" \
  > "$PODMAN_DIR/sing-box/02-inbounds-reality.json"

curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/sing-box/client/03-outbounds-reality.json \
  | jq ".outbounds[0].tag =  \"$TAG\" \
  | .outbounds[0].server =  \"`curl -s4 ip.sb`\" \
  | .outbounds[0].server_port = $LISTENPORT \
  | .outbounds[0].uuid = \"$UUID\" \
  | .outbounds[0].tls.server_name = \"$DNS\" \
  | .outbounds[0].tls.reality.public_key = \"`echo $X25519 | awk '{print $4}'`\" \
  | .outbounds[0].tls.reality.short_id = \"$SHORTID\"" \
  | tee 03-outbounds-reality.json
echo "客户端配置文件保存在当前目录下"

systemctl --user daemon-reload
systemctl --user restart sing-box.service
}
sb_vless_http2_reality_operation (){ exit 1; }
sb_vless_grpc_reality_operation (){ exit 1; }
sb_vless_vision_tls_operation (){ exit 1; }
sb_vless_websocket_tls_operation (){ exit 1; }
sb_vless_grpc_tls_operation (){
# 通用
curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/Quadlet/sing-box.container | sed "s,/opt/podman,$PODMAN_DIR,g" > ~/.config/containers/systemd/sing-box.container
curl -Lso $PODMAN_DIR/sing-box/00-log.json https://raw.githubusercontent.com/22p/somescripts/main/sing-box/server/00-log.json
# VLESS+gRPC+TLS
curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/sing-box/server/02-inbounds-grpc.json \
  | jq ".inbounds[0].listen_port = $LISTENPORT \
  | .inbounds[0].users[0].uuid = \"$UUID\" \
  | .inbounds[0].transport.service_name = \"$SHORTID\"" \
  > "$PODMAN_DIR/sing-box/02-inbounds-grpc.json"

curl -Ls https://raw.githubusercontent.com/22p/somescripts/main/sing-box/client/03-outbounds-grpc.json \
  | jq ".outbounds[0].tag =  \"$TAG\" \
  | .outbounds[0].server =  \"`curl -s4 ip.sb`\" \
  | .outbounds[0].server_port = $LISTENPORT \
  | .outbounds[0].uuid = \"$UUID\" \
  | .outbounds[0].tls.server_name = \"$DNS\" \
  | .outbounds[0].transport.service_name = \"$SHORTID\"" \
  | tee 03-outbounds-grpc.json
echo "客户端配置文件保存在当前目录下"

systemctl --user daemon-reload
systemctl --user restart sing-box.service
}

echo "请选择一个选项 ："
echo "1. SSL"
echo "2. Nginx"
echo "3. sing-box TUIC"
echo "4. sing-box VLESS+Vision+REALITY"
echo "9. sing-box VLESS+gRPC+TLS"
read choice

case $choice in
  1) ssl_operation;;
  2) nginx_operation;;
  3) sb_tuic_operation;;
  4) sb_vless_vision_reality_operation;;
  5) sb_vless_http2_reality_operation;;
  6) sb_vless_grpc_reality_operation;;
  7) sb_vless_vision_tls_operation;;
  8) sb_vless_websocket_tls_operation;;
  9) sb_vless_grpc_tls_operation;;
  *) echo "无效的选项";;
esac
