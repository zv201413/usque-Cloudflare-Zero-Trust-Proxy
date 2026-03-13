# sv66.dataonline-usque-CF-Zero-Trust

这是一个专为 sv66 (Serv00) 等受限 Linux 环境设计的代理部署方案。通过接入 Cloudflare MASQUE 网络，并结合 `gost` 提供安全的 Shadowsocks 入口。

## 1. 快速部署 (一键初始化)

在你的远程主机终端中直接执行以下命令：

```bash
# 下载脚本
curl -L https://raw.githubusercontent.com/zv201413/sv66.dataonline-usque-CF-Zero-Trust/main/setup.sh -o setup.sh
curl -L https://raw.githubusercontent.com/zv201413/sv66.dataonline-usque-CF-Zero-Trust/main/manage.sh -o manage.sh
chmod +x setup.sh manage.sh

# 运行初始化 (自动在线拉取 usque-bin 和 gost 二进制文件)
./setup.sh
```

---

## 2. 获取 Zero Trust 令牌 (JWT) - 核心步骤

1. **访问认证页面**：在浏览器打开 `https://<你的团队名>.cloudflareaccess.com/warp`。
2. **完成验证**：输入邮箱并填入验证码。
3. **F12 提取令牌**：
   - 看到 **Success** 页面后，按下 `F12` 打开控制台 (Console)。
   - 输入 `允许粘贴` (或 `allow pasting`) 并回车以解锁。
   - 粘贴并运行以下代码：
     ```javascript
     console.log(document.querySelector("meta[http-equiv='refresh']").content.split("=")[2])
     ```
   - 复制输出的那串以 `eyJ...` 开头的极长字符串（**有效期仅 1 分钟**）。

---

## 3. 注册与启动

### 第一步：注册设备 (仅需一次)
```bash
./manage.sh register <你复制的令牌>
```
*如果报 401 错误，请刷新浏览器重新获取 Token 并快速执行。*

### 第二步：交互式启动
```bash
./manage.sh start
```
- **自检逻辑**：脚本会自动通过 `gost` 预探测端口可用性。如果端口被占用，会立即提示你重新输入，直至启动成功。
- **端口范围**：sv66 建议使用 `35001 - 35999`。

### 第三步：获取节点链接
启动成功后，屏幕会输出绿色的 `ss://` 链接。将其复制并导入 v2rayN、Shadowrocket 或 Clash 即可。

---

## 4. 自动保活 (Crontab)
建议添加定时任务，防止进程被系统杀掉：
```bash
crontab -e
# 添加以下行 (请根据实际路径修改)
*/10 * * * * cd /home/zvtdcomi/ && ./manage.sh start << 'EOF'
35801
35998
EOF
```

---

## 特别鸣谢
本项目灵感及基础思路参考了 YouTube 博主 [@闹海金蛟](https://www.youtube.com/@%E9%97%B9%E6%B5%B7%E9%87%91%E8%9B%9F) 的视频（第 931 期和 935 期）。

**主要改进**：
1. **在线拉取**：`setup.sh` 自动从 [Diniboy1123/usque](https://github.com/Diniboy1123/usque/releases) 下载最新二进制并重命名。
2. **安全性**：在原本 SOCKS5 的基础上增加了 `gost` 的 Shadowsocks 加密封装，解决了公网传输明文的风险。
3. **健壮性**：增加了交互式端口动态反馈与 TLS 握手状态自检。

## 声明
本项目仅供技术研究使用，请遵守当地法律法规。
