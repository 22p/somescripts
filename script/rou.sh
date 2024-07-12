#/bin/bash

# 外部网卡名
DEV_WORLD=enp1s0
# PPPoE帐号密码
PPPOE_USERNAME=
PPPOE_PASSWORD=

DEV_BRIGE=br0
IP4_ADDRESS=192.168.100.1/24
# 桥接从属网卡
DEV_SLACE=("enp2s0" "eno1" "enp4s0")

if [[ $EUID -ne 0 ]]; then
  echo "错误: 此脚本必须以root身份运行." >&2
  exit 1
fi

if nmcli connection show | grep -q "$DEV_BRIGE"; then
  echo "桥接连接 $DEV_BRIGE 已存在,取消配置."
  exit 0
fi

# 添加桥接连接
nmcli connection add type bridge ifname $DEV_BRIGE con-name $DEV_BRIGE bridge.stp no ipv4.addresses $IP4_ADDRESS ipv4.method manual ipv6.method shared ipv4.may-fail no ipv6.may-fail no connection.autoconnect yes 

# 添加桥接从属连接
for iface in "${DEV_SLACE[@]}"; do
  nmcli connection add type bridge-slave ifname $iface master $DEV_BRIGE
done

# 添加外部网卡设置
# nmcli connection add type ethernet ifname $DEV_WORLD con-name $DEV_WORLD ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes connection.autoconnect yes
# 添加PPPoE连接
# rpm-ostree install NetworkManager-ppp
nmcli connection add type pppoe ifname $DEV_WORLD username $PPPOE_USERNAME password $PPPOE_PASSWORD ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes 802-3-ethernet.mtu 1492 connection.autoconnect yes

# 添加并应用nftable设置
NFTABLES_URL_BASE="https://github.com/22p/somescripts/raw/main/nftables"
mkdir -p /etc/nftables/tproxy
curl -Lo /etc/nftables/router.nft $NFTABLES_URL_BASE/router.nft
for file in tproxy.nft ip_reserved.nft ip6_cn.nft ip6_cn.nft; do
  curl -Lo /etc/nftables/tproxy/$file $NFTABLES_URL_BASE/tproxy/$file
done
echo "include \"/etc/nftables/router.nft\"" >> /etc/sysconfig/nftables.conf
systemctl enable --now nftables.service


# 添加并应用 sysctl 配置
cat <<EOL >/etc/sysctl.conf
# sysctl settings are defined through files in
# /usr/lib/sysctl.d/, /run/sysctl.d/, and /etc/sysctl.d/.
#
# Vendors settings live in /usr/lib/sysctl.d/.
# To override a whole file, create a new file with the same in
# /etc/sysctl.d/ and put new settings there. To override
# only specific settings, add a file with a lexically later
# name in /etc/sysctl.d/ and put new settings there.
#
# For more information, see sysctl.conf(5) and sysctl.d(5).

# IP端口配置
net.ipv4.ip_unprivileged_port_start=0

# 默认队列调度算法
net.core.default_qdisc = fq

# TCP拥塞控制算法
net.ipv4.tcp_congestion_control = bbr

# 文件系统安全设置
fs.protected_hardlinks=1
fs.protected_symlinks=1

# BPF（Berkeley Packet Filter）设置
net.core.bpf_jit_enable=1
net.core.bpf_jit_kallsyms=1

# ARP（地址解析协议）设置
net.ipv4.conf.default.arp_ignore=1
net.ipv4.conf.all.arp_ignore=1

# IP转发设置
net.ipv4.ip_forward=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1

# ICMP设置
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1

# IGMP（Internet Group Management Protocol）设置
net.ipv4.igmp_max_memberships=100

# TCP超时设置
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=120

# TCP参数设置
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_dsack=1

# 连接跟踪和防火墙设置
net.netfilter.nf_conntrack_acct=1
net.netfilter.nf_conntrack_checksum=0
net.netfilter.nf_conntrack_tcp_timeout_established=7440
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=180

# 网络接收和发送缓冲区大小设置
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
EOL
sysctl -p
