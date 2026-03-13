# usque + GOST Cloudflare Zero Trust 代理项目 (增强版)

本项目专为 sv66 等受限环境优化，支持交互式端口检测与私钥 DER 格式转换。

## 1. 核心特性
- **交互式自检**: `manage.sh start` 会引导你输入端口，并自动在 2 秒后通过分析日志检测冲突。
- **自动容错**: 若检测到端口被占用，脚本会提示重新输入，直至启动成功。
- **配置模拟**: 支持手动编辑 `config.json` 接入自定义 CF 账户。

---

## 2. 节点链接 (Shadowsocks)
```text
ss://YWVzLTI1Ni1nY206U2VjdXJlUGFzczEyMw==@<越南主机IP>:<你选择的端口>#Vietnam-CF-MASQUE
```
- **加密方式**: `aes-256-gcm`
- **默认密码**: `SecurePass123`

---

## 3. 配置文件模拟 (config.json)

如果你需要手动修改密钥或 IPv6 地址，请确保格式正确：

```json
{
  "private_key": "ASN.1 DER格式的Base64字符串",
  "endpoint_v4": "162.159.192.1",
  "endpoint_v6": "2606:4700:d0::1",
  "endpoint_pub_key": "-----BEGIN PUBLIC KEY-----\n...",
  "license": "",
  "id": "t.a27618f6-1e19-11f1-9770-e6329005328d",
  "access_token": "0fc2a774-...",
  "ipv4": "100.96.0.2",
  "ipv6": "2606:4700:110:8360:b916:a8dd:a764:13db",
  "reserved": [21, 92, 225]
}
```

### 私钥转换 (32字节原始 -> DER)
由于 `usque` 强制要求 DER 格式，你可以使用以下逻辑更新：
- 运行 `./manage.sh register <TOKEN>` 会自动生成 DER 格式。
- 手动修改时，请确保 `private_key` 是经过 ASN.1 包装后的字符串（长度通常大于 80 位）。

---

## 4. 故障排查
- **Address already in use**: sv66 是共享环境。脚本现在会自动检测并报错，请换一个端口重试（范围 35001-35999）。
- **ASN.1 Syntax Error**: 典型的私钥格式错误，请使用注册生成的 `config.json` 或参考转换方法。
- **usque: 已停止**: 检查 `usque.log` 是否有 `Failed to connect tunnel`，通常为 Cloudflare 网络暂时不可达。

---

## 5. 自动启动与优化
建议在 `crontab -e` 中添加以下内容以实现掉线自动拉起：
```bash
*/10 * * * * cd /home/zvtdcomi/ && ./manage.sh start << 'EOF'
35801
35998
EOF
```
*(注意：Crontab 中建议直接重定向预设端口)*
