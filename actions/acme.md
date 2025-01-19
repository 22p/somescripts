# 使用指南
此文档将指导您如何配置和使用 GitHub Actions 工作流程来申请和更新 SSL 证书。确保您具有相应的权限和配置来顺利执行该工作流程。**请注意，由于证书会上传到仓库，请将仓库设置为私有**。
## 前提条件
 **配置 Secrets**：在仓库的 Settings > Secrets and Variables > Actions 中，配置以下 Secrets：
   - `DOMAIN_LIST`：需要申请的域名列表，格式为 `<域名>,<DNS服务商>,<ACME服务器>,[--eab],[证书有效期],[证书剩余时间触发续订]`，每个域名会申请单独的泛域名证书。配置示例：
     ```
     example.com,cloudflare,letsencrypt
     example.com,cloudflare,zerossl,,,15
     example.com,cloudflare,google,--eab,30,15
     ```
   - `DNS_API`：DNS API 配置，一行一个，需要在末尾加反斜杠，例如：
     ```
     CLOUDFLARE_EMAIL="you@example.com" \
     CLOUDFLARE_API_KEY="yourprivatecloudflareapikey" \
     ```
     支持的 DNS 服务商列表请参考：[lego DNS Providers](https://go-acme.github.io/lego/dns)
   - `LEGO_ACCOUNT_TAR`：Base64 编码的 lego 配置信息，在本地成功签发后运行 `tar cz .lego/accounts | base64 -w0` 获取。

     本地签发命令示例：
     ```
     CF_DNS_API_TOKEN="***" ./lego --accept-tos \
       --email ssl@example.com --dns cloudflare \
       --server https://dv.acme-v02.api.pki.goog/directory \
       --eab --kid *** --hmac ***  --domains example.com run
     ```
   - `CERT_EMAIL`：注册 ACME 的电子邮件地址。
## 运行工作流程

您可以通过以下两种方式触发工作流程：

1. **手动运行**：在 GitHub 仓库的 Actions 页面，选择 `acme ssl automation` 工作流程，然后点击 `Run workflow` 手动触发。
2. **定时运行**：工作流程将根据配置的 cron 表达式，每周六运行一次。
