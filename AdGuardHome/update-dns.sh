#!/bin/bash

cd /usr/local/bin/AdGuardHome
# 下载配置文件
curl -LO https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf

# 修改配置文件格式并添加额外的 DNS 服务器
sed -i \
    -e 's/server=\/\(.*\)\//\[\/\1\/\]/g' \
    -e 's/114\.114\.114\.114/quic:\/\/223\.5\.5\.5 quic:\/\/223\.6\.6\.6/g' \
    -e '$ a\tls://1.1.1.1\ntls://1.0.0.1\ntls://8.8.8.8\ntls://8.8.4.4' \
    accelerated-domains.china.conf

systemctl restart AdGuardHome.service
