#!/bin/bash

cd "$(dirname "$0")" || exit

# Nginx
pushd ../nginx >/dev/null || exit
(
    cat <<'EOF'
# Cloudflare 回源验证 需要去控制台启用 经过身份验证的源服务器拉取
# curl -LO https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem

ssl_verify_client on;
ssl_client_certificate /cert/authenticated_origin_pull_ca.pem;

# https://www.cloudflare.com/ips
EOF

    curl -s https://www.cloudflare.com/ips-v4 | sed 's/^/set_real_ip_from /; s/$/;/'
    echo -e ""
    curl -s https://www.cloudflare.com/ips-v6 | sed 's/^/set_real_ip_from /; s/$/;/'
    echo -e "\n"
    cat <<EOF
#use any of the following two
real_ip_header CF-Connecting-IP;
#real_ip_header X-Forwarded-For;
EOF
) >config.cloudflare
popd >/dev/null

# AdGuardHome
pushd ../AdGuardHome >/dev/null || exit
curl -sLO https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf

sed \
    -e 's/server=\/\(.*\)\//\/\1\//g' \
    -e 's/114\.114\.114\.114//g' \
    accelerated-domains.china.conf >accelerated-domains.china.sing-box.conf
docker run --rm -v "$(pwd)":/conf ghcr.io/sagernet/sing-box:latest rule-set convert --type adguard --output /conf/accelerated-domains.china.srs /conf/accelerated-domains.china.sing-box.conf
rm -f accelerated-domains.china.sing-box.conf

sed -i \
    -e 's/server=\/\(.*\)\//\[\/\1\/\]/g' \
    -e 's/114\.114\.114\.114/h3:\/\/223\.5\.5\.5\/dns-query/g' \
    -e '$ a\https://1.1.1.1\/dns-query\nhttps://8.8.8.8\/dns-query' \
    accelerated-domains.china.conf
popd >/dev/null

# nftables
pushd ../nftables/tproxy >/dev/null || exit
curl -sLo ip4_cn.nft https://ispip.clang.cn/all_cn.txt
sed -i \
    -e '$!s/$/,/' \
    -e '$s/$/ }\n}/' \
    -e '1s/^/set ip4_cn {\n  typeof ip daddr\n  flags interval\n  elements = { /' \
    ip4_cn.nft

curl -sLo ip6_cn.nft https://ispip.clang.cn/all_cn_ipv6.txt
sed -i \
    -e '$!s/$/,/' \
    -e '$s/$/ }\n}/' \
    -e '1s/^/set ip6_cn {\n  typeof ip6 daddr\n  flags interval\n  elements = { /' \
    ip6_cn.nft
popd >/dev/null
