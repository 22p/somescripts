#!/bin/bash

curl -LO https://ispip.clang.cn/all_cn.txt
mv all_cn.txt geoip4_cn.nft
sed -i \
        -e '$!s/$/,/' \
        -e '$s/$/ }\n}/' \
        -e '1s/^/set byp4 {\n  typeof ip daddr\n  flags interval\n  elements = { /' \
        geoip4_cn.nft

curl -LO https://ispip.clang.cn/all_cn_ipv6.txt
mv all_cn_ipv6.txt geoip6_cn.nft
sed -i \
        -e '$!s/$/,/' \
        -e '$s/$/ }\n}/' \
        -e '1s/^/set byp6 {\n  typeof ip6 daddr\n  flags interval\n  elements = { /' \
        geoip6_cn.nft


