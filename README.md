# usque + GOST Cloudflare Zero Trust 代理项目

本项目专为 sv66 等受限 Linux 环境设计。利用 `usque` 接入 Cloudflare MASQUE 网络，并使用 `gost` 在公网开启 Shadowsocks 加密服务。

## 1. 核心特性
- **交互式启动**: 脚本会自动引导你选择可用端口，并实时检测冲突。
- **端口容错**: 自动分析日志，如果端口被占用，会提示你重新输入。
- **安全加固**: 使用 Shadowsocks (SS) 封装 SOCKS5，解决公网明文传输被拦截的问题。

## 2. 节点配置与链接

**Shadowsocks (SS) 节点链接**:
```text
ss://YWVzLTI1Ni1nY206U2VjdXJlUGFzczEyMw==@<越南主机IP>:<你选择的端口>#Vietnam-CF-MASQUE
```
*(请将 `<越南主机IP>` 替换为你主机的真实公网 IP)*

- **可用端口范围**: `35001 - 35999` (sv66 主机限制，需自行尝试)。
- **加密方式**: `aes-256-gcm`
- **密码**: `SecurePass123`

---

## 3. 配置文件说明 (config.json)

`usque` 的配置文件结构如下：

```json
{
  "private_key": "ASN.1 DER格式的Base64私钥",
  "endpoint_v4": "162.159.192.1",
  "endpoint_v6": "2606:4700:d0::1",
  "endpoint_pub_key": "...",
  "ipv6": "2606:4700:110:8360:b916:a8dd:a764:13db",
  "reserved": [21, 92, 225]
}
```

### 关键注意事项：私钥格式
`usque` 使用 Go 语言的 `x509.ParseECPrivateKey` 解析私钥，它要求私钥必须是 **ASN.1 DER (SEC1)** 格式的 Base64 字符串。
**普通 WireGuard 的 32 字节原始私钥直接填入会报错**。

如果你只有 32 字节的原始私钥（Base64 格式，长度为 44 个字符），你需要将其转换为 DER 格式。
你可以使用以下 Python 脚本进行转换：

```python
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

# 替换为你的 32 字节原始私钥
raw_b64 = "你的原始私钥"
raw_bytes = base64.b64decode(raw_b64)
d = int.from_bytes(raw_bytes, byteorder='big')
priv_key = ec.derive_private_key(d, ec.SECP256R1())
der = priv_key.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.TraditionalOpenSSL,
    encryption_algorithm=serialization.NoEncryption()
)
print(base64.b64encode(der).decode())
```

---

## 4. 快速开始步骤

### 第一步：环境部署
```bash
# 1. 上传 usque-bin
# 2. 安装 gost
./install_gost.sh
# 3. 赋予执行权限
chmod +x usque-bin gost manage.sh install_gost.sh
```

### 第二步：配置与启动
1. **自动模式**: 运行 `./manage.sh register <TOKEN>`，这会自动生成正确的 `config.json`。
2. **手动模式**: 编辑 `config.json` 并填入你的密钥、IPv6 和 `reserved` 值。
3. **启动**: 运行 `./manage.sh start` 并按照提示输入端口。

---

## 5. 故障排查
- **ASN.1 Syntax Error**: 私钥格式错误。请确保 `private_key` 是 DER 格式（见第 3 节）。
- **Address already in use**: 端口被占用。sv66 环境建议在 `35001-35999` 之间随机挑选。
- **401 Unauthorized**: 令牌过期，请重新获取。
- **usque: 已停止**: 检查 `usque.log`。可能是密钥不匹配或 Cloudflare 网络问题。

---

## 6. 其它改进与优化
- **双重保活**: 脚本在启动后会记录 PID，建议结合 `crontab` 每 10 分钟运行一次 `./manage.sh start`，脚本会自动检测如果已运行则跳过，未运行则重启。
- **IPv6 优化**: 如果你的主机支持 IPv6，可以在 `config.json` 中配置 `endpoint_v6` 以获得更稳定的连接。
