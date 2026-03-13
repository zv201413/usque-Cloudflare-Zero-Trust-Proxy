# usque + GOST Cloudflare Zero Trust 代理项目

这是一个专为 sv66 (Serv00) 等受限 Linux 环境设计的代理部署方案。通过 `usque` 接入 Cloudflare MASQUE 网络，并结合 `gost` 提供安全的 Shadowsocks 入口。

## 1. 快速部署步骤

在你的远程主机终端中直接执行以下命令进行初始化：

```bash
# 下载安装脚本并赋予权限
curl -L https://raw.githubusercontent.com/zv201413/usque-Cloudflare-Zero-Trust-Proxy/main/setup.sh -o setup.sh
curl -L https://raw.githubusercontent.com/zv201413/usque-Cloudflare-Zero-Trust-Proxy/main/manage.sh -o manage.sh
chmod +x setup.sh manage.sh

# 运行初始化环境 (自动下载 usque 和 gost 二进制文件)
./setup.sh
```

---

## 2. 获取 Zero Trust 令牌 (JWT)

这是最关键的一步，用于将你的主机作为合法设备接入 Cloudflare 团队。

1. **访问认证页面**：在浏览器打开 `https://<你的团队名>.cloudflareaccess.com/warp`。
2. **完成登录**：输入邮箱并填入收到的验证码。
3. **获取令牌**：
   - 登录成功后，页面会显示 **Success**。
   - 按下 `F12` 键打开开发者工具，点击 **Console (控制台)**。
   - 如果系统提示禁止粘贴，请输入 `允许粘贴` 并按回车。
   - 复制并运行以下代码：
     ```javascript
     console.log(document.querySelector("meta[http-equiv='refresh']").content.split("=")[2])
     ```
   - 控制台会输出一串以 `eyJ...` 开头的极长字符串，**请立即复制**（有效期通常仅 1 分钟）。

---

## 3. 注册与启动服务

### 第一步：注册设备 (仅需一次)
将上一步获取的令牌填入：
```bash
./manage.sh register <你复制的令牌>
```
*如果提示 401 Unauthorized，说明令牌已过期，请刷新浏览器重新获取。*

### 第二步：交互式启动
```bash
./manage.sh start
```
- **内部端口**: 建议输入 `35001 - 35999` 之间的一个数字（如 `35801`）。
- **外部端口**: 建议输入 `35001 - 35999` 之间的另一个数字（如 `35998`）。
- **自检逻辑**: 脚本会自动检查端口是否被占用以及 TLS 握手是否成功。

### 第三步：获取节点链接
启动成功后，屏幕会输出绿色的 `ss://` 链接。将其直接复制并导入 v2rayN、Shadowrocket 或 Clash 即可使用。

---

## 4. 常见问题排查 (Q&A)

*   **Q: 为什么生成的链接导入 v2rayN 后报错？**
    *   A: 可能是密码生成失败。运行 `./manage.sh new-pass` 重置密码，然后重新 `./manage.sh start`。
*   **Q: 为什么 ping0.cc 显示我的 IP 风险高？**
    *   A: Cloudflare WARP 的 IP 属于数据中心类别，这是正常现象。只要能正常访问 Google/YouTube 即可，不影响使用。
*   **Q: 端口总是提示 Address already in use？**
    *   A: sv66 是共享环境，很多端口已被其他用户占用。请尝试 `35001 - 35999` 之间的随机数字。

---

## 5. 自动维护 (Crontab)
为了防止进程被系统杀掉，建议添加定时守护：
```bash
crontab -e
# 添加以下行 (请根据实际路径修改)
*/10 * * * * cd /home/zvtdcomi/ && ./manage.sh start << 'EOF'
35801
35998
EOF
```

## 特别鸣谢
本项目灵感及基础思路参考了 YouTube 博主 [@闹海金蛟](https://www.youtube.com/@%E9%97%B9%E6%B5%B7%E9%87%91%E8%9B%9F) 的视频（第 931 期和 935 期）。

**主要改进**：原本的思路仅生成明文 SOCKS5 链接，在公网传输存在风险。本项目在其基础上通过 `gost` 增加了“本机到主机”这一段的 Shadowsocks 加密封装，极大提升了在受限网络环境下的安全性与稳定性。

## 声明
本项目基于 [Diniboy1123/usque](https://github.com/Diniboy1123/usque) 核心构建。
