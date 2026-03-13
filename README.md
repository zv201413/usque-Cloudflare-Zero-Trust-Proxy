# usque + GOST Cloudflare Zero Trust 代理项目

本项目专为 sv66 等受限 Linux 环境设计。利用 `usque` 接入 Cloudflare MASQUE 网络，并使用 `gost` 在公网开启 Shadowsocks 加密服务。

## 1. 核心特性
- **交互式启动**: 脚本会自动引导你选择可用端口。
- **端口冲突检测**: 如果选择的端口被占用，脚本会读取日志并自动弹出提示，让你重新选择，直到成功。
- **安全加固**: 通过 GOST 隧道将 SOCKS5 封装为 Shadowsocks (SS)，防止公网明文传输。

## 2. 节点配置与链接

**Shadowsocks (SS) 节点链接**:
```text
ss://YWVzLTI1Ni1nY206U2VjdXJlUGFzczEyMw==@<越南主机IP>:<你选择的端口>#Vietnam-CF-MASQUE
```

- **协议**: Shadowsocks (SS)
- **可用端口范围**: `35001 - 35999` (sv66 主机限制)
- **加密方式**: `aes-256-gcm`
- **密码**: `SecurePass123`

---

## 3. 配置文件模拟 (config.json)

如果你需要手动修改或备份配置，`config.json` 的结构如下：

```json
{
  "private_key": "x4CnJjPO0JcVwAigm9uxZ32V8LcZmptgXPQNvuYJvYo=",
  "endpoint_v4": "162.159.192.1",
  "endpoint_v6": "2606:4700:d0::1",
  "endpoint_pub_key": "...",
  "ipv6": "2606:4700:110:8360:b916:a8dd:a764:13db",
  "reserved": [21, 92, 225]
}
```

### 如何更新密钥配置？
1. **自动更新**: 重新运行 `./manage.sh register <新TOKEN>`。
2. **手动更新**: 
   - 编辑 `config.json`。
   - 填入你的 `private_key`、`ipv6` 地址及 `reserved` 数组。
   - 重启服务: `./manage.sh stop && ./manage.sh start`。

---

## 4. 快速开始步骤

### 第一步：环境准备
```bash
./install_gost.sh
# 确保 usque-bin 已上传
chmod +x usque-bin gost manage.sh install_gost.sh
```

### 第二步：注册并启动
```bash
# 注册设备
./manage.sh register <TOKEN>

# 交互式启动
./manage.sh start
```
*启动时，脚本会询问端口。如果端口被占用，脚本会提示你：“错误: 端口已被占用”，并要求你重新输入。*

---

## 5. 故障排查
- **401 Unauthorized**: 令牌过期或注册规则未配置。请重新刷新页面获取最新 Token。
- **服务自动停止**: sv66 内存极小，进程可能被杀。
- **日志分析**:
  - `tail -f usque.log`: 查看后端连接 Cloudflare 状态。
  - `tail -f gost.log`: 查看前端代理流量状态。
