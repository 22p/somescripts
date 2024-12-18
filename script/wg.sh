#!/bin/bash

# 检查WireGuard是否已安装
if ! command -v wg &>/dev/null; then
    echo "WireGuard未安装，请先安装WireGuard"
    exit 1
fi

# 获取设备数量
read -p "请输入需要配置的设备数量: " device_num

IPv4="192.168.255."
IPv6="fdff:cafe::"
port="6699"
mtu="1400"

# 创建存储配置文件的目录
nm_config_dir="NetworkManager_configs"
wg_config_dir="wireguard_configs"
mkdir -p "$nm_config_dir"
mkdir -p "$wg_config_dir"

# 生成预共享密钥
preshared_key=$(wg genpsk)

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
address1=$IPv6$i/128
addr-gen-mode=default
method=manual

[proxy]
# 这里会填充其他设备的公钥和AllowedIPs
EOF

    # 创建wg配置文件
    wg_config_file="$wg_config_dir/device$i.conf"
    cat >"$wg_config_file" <<EOF
[Interface]
PrivateKey = $private_key
Address = $IPv4$i/32
Address = $IPv6$i/128
ListenPort = $port
MTU = $mtu

[Peer]
# 这里会填充其他设备的公钥和AllowedIPs
EOF

    # 将生成的公钥保存到一个数组中，用于后续配置Peer信息
    public_keys+=("$public_key")
done

# 配置Peer信息
for ((i = 1; i <= device_num; i++)); do
    nm_config_file="$nm_config_dir/device$i.nmconnection"

    # 从第二个设备开始，每个设备都需要配置其他所有设备的Peer信息
    for ((j = 1; j <= device_num; j++)); do
        if [ "$i" -ne "$j" ]; then
            echo "" >>"$nm_config_file"
            echo "[wireguard-peer.${public_keys[$j - 1]}]" >>"$nm_config_file"
            echo "preshared-key=$preshared_key" >>"$nm_config_file"
            echo "allowed-ips=$IPv4$j/32, $IPv6$j/128" >>"$nm_config_file"
            echo "Endpoint = device$j # 这里需要替换为实际的设备主机名或IP" >>"$nm_config_file"
            echo "persistent-keepalive=30" >>"$nm_config_file"
        fi
    done
done

# 配置Peer信息
for ((i = 1; i <= device_num; i++)); do
    wg_config_file="$wg_config_dir/device$i.conf"

    # 从第二个设备开始，每个设备都需要配置其他所有设备的Peer信息
    for ((j = 1; j <= device_num; j++)); do
        if [ "$i" -ne "$j" ]; then
            echo "" >>"$wg_config_file"
            echo "[Peer]" >>"$wg_config_file"
            echo "PublicKey = ${public_keys[$j - 1]}" >>"$wg_config_file"
            echo "PresharedKey =  $preshared_key" >>"$wg_config_file"
            echo "AllowedIPs = $IPv4$j/32, $IPv6$j/128" >>"$wg_config_file"
            echo "Endpoint = device$j # 这里需要替换为实际的设备主机名或IP" >>"$wg_config_file"
            echo "PersistentKeepalive = 30" >>"$wg_config_file"
        fi
    done
done

echo "配置文件已生成在$nm_config_dir $wg_config_dir目录下"
echo "请将配置文件拷贝到各设备并配置好Endpoint信息"
