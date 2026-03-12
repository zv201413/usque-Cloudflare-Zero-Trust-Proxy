# usque + GOST Cloudflare Zero Trust 代理项目

本项目专为受限 Linux 环境（无 Root 权限、低内存、无标准网络工具）设计。通过 `usque` 实现 MASQUE 协议接入 Cloudflare，并使用 `gost` 提供加密入口，确保连接安全。

## 1. 准备工作

### 获取二进制文件
由于受限主机内存较小，建议直接使用编译好的二进制文件：
1. 从 `usque_1.4.2_linux_amd64.zip` 中提取 `usque` 文件。
2. 上传到主机的项目目录，并重命名为 `usque-bin`。
3. 赋予执行权限：
```bash
chmod +x usque-bin
```
```bash
chmod +x install_gost.sh
```
```bash
chmod +x manage.sh
```

### 安装 GOST
运行安装脚本下载并准备 `gost`：
```bash
./install_gost.sh
```

---

## 2. 获取 Zero Trust 令牌 (JWT)

**注意：令牌有效期极短，获取后请立即执行注册命令。**

1. 访问：`https://<你的团队名>.cloudflareaccess.com/warp`
2. 完成邮箱验证登录。
3. 看到 "Success" 页面后，按下 `F12` 打开控制台 (Console)。
4. 如果提示“禁止粘贴”，请手动输入 `允许粘贴` (或 `allow pasting`) 并回车。
5. 执行以下命令获取 Token：
   ```javascript
   console.log(document.querySelector("meta[http-equiv='refresh']").content.split("=")[2])
   ```

---

## 3. 注册与启动

### 注册设备 (仅需一次)
```bash
./manage.sh register <你的TOKEN>
```
**如果提示 401 Unauthorized：**
- 令牌已过期：请重新刷新浏览器页面并再次执行获取 Token 的 JS 代码。
- 策略未生效：请检查 Zero Trust 后台 **Settings -> Devices -> Enrollment** 里的规则是否包含了你的邮箱。

### 启动服务
```bash
./manage.sh start
```

### 状态检查
```bash
./manage.sh status
```

---

## 4. 客户端配置

在你的手机（Shadowrocket）或电脑（Clash）中添加一个 **Shadowsocks (SS)** 节点：

- **服务器地址**: 你的主机 IP
- **端口**: `2080` (可在 manage.sh 修改)
- **加密方式**: `aes-256-gcm`
- **密码**: `SecurePass123` (建议在 manage.sh 中修改)

---

## 5. 原理解析

1. **入口加密 (你 <-> 主机)**：通过 `gost` 提供的 Shadowsocks 隧道，防止 SOCKS5 明文流量被运营商拦截。
2. **中转 (主机内)**：`gost` 将流量解密后转发到本地 `1080` 端口。
3. **出口隧道 (主机 <-> Cloudflare)**：`usque` 接收流量，通过 **MASQUE (HTTP/3)** 协议将其封装并发送至 Cloudflare 全球边缘节点。
4. **落地**：流量从 Cloudflare 节点流出，实现代理上网。
