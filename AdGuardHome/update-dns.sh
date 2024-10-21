#!/bin/bash

# 下载配置文件
curl -LO https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf

sed \
    -e 's/server=\/\(.*\)\//\/\1\//g' \
    -e 's/114\.114\.114\.114//g' \
    accelerated-domains.china.conf > accelerated-domains.china.sing-box.conf
sing-box rule-set convert --type adguard --output accelerated-domains.china.srs accelerated-domains.china.sing-box.conf
rm -f accelerated-domains.china.sing-box.conf

# 修改配置文件格式并添加额外的 DNS 服务器
sed -i \
    -e 's/server=\/\(.*\)\//\[\/\1\/\]/g' \
    -e 's/114\.114\.114\.114/h3:\/\/223\.5\.5\.5\/dns-query/g' \
    -e '$ a\https://1.1.1.1\/dns-query\nhttps://8.8.8.8\/dns-query' \
    accelerated-domains.china.conf
