#!/bin/bash
BINARY="./usque-bin"
GOST="./gost"
PID_USQUE="usque.pid"
PID_GOST="gost.pid"
CONFIG_FILE="config.json"
AUTH_FILE=".proxy_auth"

# 基础安全配置
SS_METHOD="aes-256-gcm"

# 获取或生成持久化的随机密码 (增强兼容版)
get_or_create_password() {
    if [ -f "$AUTH_FILE" ] && [ -s "$AUTH_FILE" ]; then
        cat "$AUTH_FILE"
    else
        local pass
        if command -v uuidgen &> /dev/null; then
            pass=$(uuidgen)
        elif [ -r /proc/sys/kernel/random/uuid ]; then
            pass=$(cat /proc/sys/kernel/random/uuid)
        else
            # 最后的保底手段
            pass=$(date +%s%N | md5sum | head -c 32)
        fi
        # 确保密码不为空
        if [ -z "$pass" ]; then pass="DefaultSecurePass123"; fi
        echo "$pass" > "$AUTH_FILE"
        echo "$pass"
    fi
}

# 获取公网 IP
get_public_ip() {
    local ip=$(curl -s -m 5 https://ifconfig.me || curl -s -m 5 https://api.ipify.org || echo "你的IP")
    echo "$ip"
}

is_running() {
    [ -f "$1" ] && ps -p $(cat "$1") > /dev/null 2>&1
}

stop_services() {
    [ -f $PID_USQUE ] && kill $(cat $PID_USQUE) 2>/dev/null && rm -f $PID_USQUE
    [ -f $PID_GOST ] && kill $(cat $PID_GOST) 2>/dev/null && rm -f $PID_GOST
}

start_interactive() {
    local SS_PASS=$(get_or_create_password)
    local PUB_IP=$(get_public_ip)

    while true; do
        echo "==============================================="
        echo "           sv66 自动化 & 交互式启动器           "
        echo "-----------------------------------------------"
        echo "当前外网 IP: $PUB_IP"
        read -p "请输入内部通信端口 (建议 35001-35999 范围内): " INT_PORT
        read -p "请输入外部加密端口 (建议 35001-35999 范围内): " PUB_PORT
        
        if [ "$INT_PORT" == "$PUB_PORT" ]; then
            echo "❌ 错误: 两个端口不能相同！"
            continue
        fi

        echo "正在初始化环境..."
        stop_services
        chmod +x "$BINARY" "$GOST" 2>/dev/null
        rm -f usque.log gost.log
        
        # 1. 启动 usque
        echo "尝试启动 usque (后端隧道)..."
        nohup $BINARY socks --port $INT_PORT --bind 127.0.0.1 --config "$CONFIG_FILE" > usque.log 2>&1 &
        echo $! > $PID_USQUE
        
        sleep 5
        if grep -qi "handshake failure" usque.log; then
            echo "❌ 严重错误: TLS 握手失败！请检查 config.json 是否有效。"
            stop_services && exit 1
        fi
        
        if ! is_running $PID_USQUE; then
            echo "❌ 失败: usque 无法启动。"
            stop_services && continue
        fi
        echo "✅ usque 隧道连接成功！"

        # 2. 启动 GOST
        echo "尝试启动 GOST (Shadowsocks 加密入口)..."
        nohup $GOST -L "ss://$SS_METHOD:$SS_PASS@:$PUB_PORT" -F "socks5://127.0.0.1:$INT_PORT" > gost.log 2>&1 &
        echo $! > $PID_GOST
        
        sleep 2
        if ! is_running $PID_GOST; then
            echo "❌ 失败: GOST 启动失败。请检查端口是否被占用。"
            stop_services && continue
        fi

        # 生成节点链接 (确保 Base64 干净)
        local auth_b64=$(echo -n "$SS_METHOD:$SS_PASS" | base64 | tr -d '\n\r')
        local ss_link="ss://$auth_b64@$PUB_IP:$PUB_PORT#Vietnam-MASQUE"

        echo "-----------------------------------------------"
        echo "🎉 代理节点已上线！"
        echo "密码: $SS_PASS"
        echo "节点链接 (直接复制到软件):"
        echo -e "\033[32m$ss_link\033[0m"
        echo "-----------------------------------------------"
        break
    done
}

start_socks_only() {
    local PUB_IP=$(get_public_ip)
    while true; do
        echo "==============================================="
        echo "           sv66 SOCKS5 模式 (明文)              "
        echo "-----------------------------------------------"
        echo "警告: 此模式不加密，仅建议在内网或临时测试使用。"
        echo "当前外网 IP: $PUB_IP"
        read -p "请输入 SOCKS5 监听端口 (建议 35001-35999): " SOCKS_PORT
        SOCKS_PORT=${SOCKS_PORT:-35801}

        echo "正在初始化环境..."
        stop_services
        chmod +x "$BINARY" 2>/dev/null
        rm -f usque.log
        
        # 尝试通过 devil 开放端口
        if command -v devil &> /dev/null; then
            devil port add tcp $SOCKS_PORT &> /dev/null
        fi

        echo "尝试启动 usque (直连模式)..."
        nohup $BINARY socks --port $SOCKS_PORT --bind 0.0.0.0 --config "$CONFIG_FILE" > usque.log 2>&1 &
        echo $! > $PID_USQUE
        
        sleep 5
        if grep -qi "handshake failure" usque.log; then
            echo "❌ 严重错误: TLS 握手失败！"
            stop_services && exit 1
        fi
        
        if ! is_running $PID_USQUE; then
            echo "❌ 失败: 端口 $SOCKS_PORT 可能被占用。"
            stop_services && continue
        fi

        echo "-----------------------------------------------"
        echo "🎉 SOCKS5 代理已上线！"
        echo "地址: $PUB_IP"
        echo "端口: $SOCKS_PORT"
        echo "提示: 无需密码，协议请选择 SOCKS5"
        echo "-----------------------------------------------"
        break
    done
}

case "$1" in
    register)
        chmod +x "$BINARY" 2>/dev/null
        $BINARY register --jwt "$2" --accept-tos ;;
    start)
        start_interactive ;;
    start-socks)
        start_socks_only ;;
    stop)
        stop_services && echo "已停止。" ;;
    status)
        is_running $PID_USQUE && echo "usque: 运行中" || echo "usque: 已停止"
        is_running $PID_GOST && echo "gost: 运行中" || echo "gost: 已停止" ;;
    new-pass)
        rm -f "$AUTH_FILE"
        echo "密码已重置，下次启动将生成新密码。" ;;
    *)
        echo "用法: ./manage.sh {register|start|start-socks|stop|status|new-pass}" ;;
esac
