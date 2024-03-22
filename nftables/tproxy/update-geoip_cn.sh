#!/bin/bash

curl -Lo geoip4_cn.nft https://ispip.clang.cn/all_cn.txt
sed -i \
        -e '$!s/$/,/' \
        -e '$s/$/ }\n}/' \
        -e '1s/^/set byp4 {\n  typeof ip daddr\n  flags interval\n  elements = { /' \
        geoip4_cn.nft

curl -Lo geoip6_cn.nft https://ispip.clang.cn/all_cn_ipv6.txt
sed -i \
        -e '$!s/$/,/' \
        -e '$s/$/ }\n}/' \
        -e '1s/^/set byp6 {\n  typeof ip6 daddr\n  flags interval\n  elements = { /' \
        geoip6_cn.nft


