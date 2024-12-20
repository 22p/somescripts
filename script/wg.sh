#!/bin/bash

# 检查WireGuard是否已安装
if ! command -v wg &>/dev/null; then
    echo "WireGuard未安装，请先安装WireGuard"
    exit 1
fi

# 获取设备数量
read -p "请输入需要配置的设备数量: " device_num

IPv4="192.168.255."
IPv6="fdff:cafe:"
port="51820"
mtu="1400"

# 创建存储配置文件的目录
nm_config_dir="NetworkManager_configs"
wg_config_dir="wireguard_configs"
mkdir -p "$nm_config_dir"
mkdir -p "$wg_config_dir"

# 生成预共享密钥
preshared_key=$(wg genpsk)

# 获取每个设备的Endpoint地址
for ((i = 1; i <= device_num; i++)); do
    read -p "请输入设备$i的Endpoint地址（格式：IP或主机名:端口）: " endpoint
    endpoints+=("$endpoint")
done

# 生成设备的私钥和公钥
for ((i = 1; i <= device_num; i++)); do
    private_key=$(wg genkey)
    public_key=$(echo "$private_key" | wg pubkey)

    # 创建nm配置文件
    nm_config_file="$nm_config_dir/device$i.nmconnection"
    cat >"$nm_config_file" <<EOF
[connection]
id=wg0
type=wireguard
interface-name=wg0

[wireguard]
listen-port=$port
mtu=$mtu
private-key=$private_key

[ipv4]
address1=$IPv4$i/32
method=manual

[ipv6]
address1=$IPv6$i::/64
addr-gen-mode=default
method=manual

[proxy]
EOF

    # 创建wg配置文件
    wg_config_file="$wg_config_dir/device$i.conf"
    cat >"$wg_config_file" <<EOF
[Interface]
PrivateKey = $private_key
Address = $IPv4$i/32
Address = $IPv6$i::/64
ListenPort = $port
MTU = $mtu

EOF

    # 将生成的公钥保存到一个数组中，用于后续配置Peer信息
    public_keys+=("$public_key")
done

# 配置Peer信息
for ((i = 1; i <= device_num; i++)); do
    nm_config_file="$nm_config_dir/device$i.nmconnection"
    wg_config_file="$wg_config_dir/device$i.conf"

    # 从第二个设备开始，每个设备都需要配置其他所有设备的Peer信息
    for ((j = 1; j <= device_num; j++)); do
        if [ "$i" -ne "$j" ]; then
            cat >>"$nm_config_file" <<EOF

[wireguard-peer.${public_keys[$j - 1]}]
preshared-key=$preshared_key
allowed-ips=$IPv4$j/32;$IPv6$j::/64
endpoint=${endpoints[$j - 1]}
persistent-keepalive=25
EOF
            # wg
            cat >>"$wg_config_file" <<EOF

[Peer]
PublicKey = ${public_keys[$j - 1]}
PresharedKey = $preshared_key
AllowedIPs = $IPv4$j/32, $IPv6$j::/64
Endpoint = ${endpoints[$j - 1]}
PersistentKeepalive = 25
EOF
        fi
    done
done

echo "配置文件已生成在$nm_config_dir $wg_config_dir目录下"
