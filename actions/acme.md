# 使用指南
此文档将指导您如何配置和使用 GitHub Actions 工作流程来申请和更新 SSL 证书。确保您具有相应的权限和配置来顺利执行该工作流程。**请注意，由于证书会上传到仓库，请将仓库设置为私有**。
## 前提条件
1. **仓库权限**：确保在您的仓库的 Settings > Actions > General 页面的底部，赋予工作流程写入权限。
2. **配置 Secrets**：在仓库的 Settings > Secrets 和 Variables > Actions 中，配置以下 Secrets：
   - `DOMAIN_LIST`：需要申请的域名列表，格式为 `<域名>:<DNS服务商>:<ACME服务器>`，使用外部账户需要添加 `:<--eab>`，每个域名会申请单独的泛域名证书。例如：
     ```
     example.com:cloudflare:letsencrypt_test
     example.org:cloudflare:google_test:--eab
     ```
   - `DNS_API`：DNS API 配置，一行一个，需要在末尾加反斜杠，例如：
     ```
     CLOUDFLARE_EMAIL="you@example.com" \
     CLOUDFLARE_API_KEY="yourprivatecloudflareapikey" \
     ```
     支持的 DNS 服务商列表请参考：[lego DNS Providers](https://go-acme.github.io/lego/dns)
   - `LEGO_ACCOUNT_TAR`：Base64 编码的 lego 配置信息，在本地成功签发后运行 `tar cz .lego/accounts | base64 -w0` 获取。
   - `CERT_EMAIL`：注册 ACME 的电子邮件地址。
## 运行工作流程

您可以通过以下两种方式触发工作流程：

1. **手动运行**：在 GitHub 仓库的 Actions 页面，选择 `acme ssl automation` 工作流程，然后点击 `Run workflow` 手动触发。
2. **定时运行**：工作流程将根据配置的 cron 表达式，每周日运行一次。
