#!/bin/bash
BINARY="./usque-bin"
GOST="./gost"
PID_USQUE="usque.pid"
PID_GOST="gost.pid"
CONFIG_FILE="config.json"
AUTH_FILE=".proxy_auth"
USQUE_LOG="usque.log"
GOST_LOG="gost.log"

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
            pass=$(date +%s%N | md5sum | head -c 32)
        fi
        [ -z "$pass" ] && pass="DefaultPass$(date +%s)"
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
    [ -f "$PID_USQUE" ] && { kill $(cat "$PID_USQUE") 2>/dev/null; rm -f "$PID_USQUE"; }
    [ -f "$PID_GOST" ] && { kill $(cat "$PID_GOST") 2>/dev/null; rm -f "$PID_GOST"; }
}

# 使用 GOST 预探测端口可用性
check_port() {
    local port=$1
    local name=$2
    echo "正在探测 $name 端口 $port 的可用性..."
    
    # 尝试启动一个极简监听
    timeout 2s "$GOST" -L ":$port" > .port_check.log 2>&1 &
    local probe_pid=$!
    sleep 1.5
    
    if grep -qiE "address already in use|bind: permission denied" .port_check.log; then
        kill $probe_pid 2>/dev/null
        rm -f .port_check.log
        return 1
    fi
    
    kill $probe_pid 2>/dev/null
    rm -f .port_check.log
    return 0
}

start_interactive() {
    local SS_PASS=$(get_or_create_password)
    local PUB_IP=$(get_public_ip)

    while true; do
        echo "==============================================="
        echo "           sv66 交互式自检启动器               "
        echo "-----------------------------------------------"
        echo "当前外网 IP: $PUB_IP"
        read -p "请输入内部通信端口 (建议 35001-35999): " INT_PORT
        read -p "请输入外部加密端口 (建议 35001-35999): " PUB_PORT
        
        [ "$INT_PORT" == "$PUB_PORT" ] && { echo "❌ 错误: 端口不能相同！"; continue; }

        # 端口预检
        if ! check_port "$INT_PORT" "内部"; then
            echo "❌ 失败: 内部端口 $INT_PORT 已被占用。"
            continue
        fi
        if ! check_port "$PUB_PORT" "外部"; then
            echo "❌ 失败: 外部端口 $PUB_PORT 已被占用。"
            continue
        fi

        echo "正在准备环境并正式启动..."
        stop_services
        chmod +x "$BINARY" "$GOST" 2>/dev/null
        rm -f "$USQUE_LOG" "$GOST_LOG"
        
        # 1. 启动 usque
        echo "尝试启动 usque 后端..."
        nohup "$BINARY" socks --port "$INT_PORT" --bind 127.0.0.1 --config "$CONFIG_FILE" > "$USQUE_LOG" 2>&1 &
        echo $! > "$PID_USQUE"
        
        sleep 4
        if grep -qi "handshake failure" "$USQUE_LOG"; then
            echo "❌ 严重错误: TLS 握手失败！请重新 register 获取 Token。"
            stop_services
            exit 1
        fi
        
        if ! is_running "$PID_USQUE"; then
            echo "❌ 失败: usque 启动异常，请查看 $USQUE_LOG"
            stop_services
            continue
        fi
        echo "✅ usque 隧道连接成功！"

        # 2. 启动 GOST
        echo "尝试启动 GOST 出口..."
        nohup "$GOST" -L "ss://$SS_METHOD:$SS_PASS@:$PUB_PORT" -F "socks5://127.0.0.1:$INT_PORT" > "$GOST_LOG" 2>&1 &
        echo $! > "$PID_GOST"
        
        sleep 2
        if ! is_running "$PID_GOST"; then
            echo "❌ 失败: GOST 启动失败。请更换外部端口。"
            stop_services
            continue
        fi

        # 生成节点链接
        local auth_b64=$(echo -n "$SS_METHOD:$SS_PASS" | base64 | tr -d '\n\r')
        local ss_link="ss://$auth_b64@$PUB_IP:$PUB_PORT#Vietnam-MASQUE"

        echo "-----------------------------------------------"
        echo "🎉 所有服务已成功绑定并运行！"
        echo "密码: $SS_PASS"
        echo "节点链接 (彩色显示，直接复制):"
        echo -e "\033[32m$ss_link\033[0m"
        echo "-----------------------------------------------"
        break
    done
}

case "$1" in
    register)
        chmod +x "$BINARY" 2>/dev/null
        "$BINARY" register --jwt "$2" --accept-tos ;;
    start)
        start_interactive ;;
    stop)
        stop_services && echo "已停止。" ;;
    status)
        is_running "$PID_USQUE" && echo "usque: 运行中" || echo "usque: 已停止"
        is_running "$PID_GOST" && echo "gost: 运行中" || echo "gost: 已停止" ;;
    new-pass)
        rm -f "$AUTH_FILE" && echo "密码已重置。" ;;
    *)
        echo "用法: ./manage.sh {register|start|stop|status|new-pass}" ;;
esac
