#!/bin/bash
BINARY="./usque-bin"
GOST="./gost"
PID_USQUE="usque.pid"
PID_GOST="gost.pid"
CONFIG_FILE="config.json"

# 默认配置
DEFAULT_INTERNAL="35801"
DEFAULT_PUBLIC="35998"
SS_METHOD="aes-256-gcm"
SS_PASS="SecurePass123"

# 检查进程是否真实运行
is_running() {
    [ -f "$1" ] && ps -p $(cat "$1") > /dev/null 2>&1
}

# 停止服务逻辑
stop_services() {
    [ -f $PID_USQUE ] && kill $(cat $PID_USQUE) 2>/dev/null && rm -f $PID_USQUE
    [ -f $PID_GOST ] && kill $(cat $PID_GOST) 2>/dev/null && rm -f $PID_GOST
}

# 检查配置文件
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 错误: 找不到 $CONFIG_FILE。请先运行 ./manage.sh register <TOKEN>"
        return 1
    fi
    # 检查 private_key 是否过短 (DER 格式通常 > 80 字符)
    PRIV_KEY=$(grep -oP '"private_key":\s*"\K[^"]+' "$CONFIG_FILE")
    if [ ${#PRIV_KEY} -lt 60 ]; then
        echo "⚠️  警告: 检测到 private_key 可能不是 DER 格式。这可能导致启动失败。"
        echo "参考 README.md 中的私钥转换方法。"
    fi
}

start_interactive() {
    check_config || return 1
    
    while true; do
        echo "-----------------------------------------------"
        echo "sv66 端口范围建议: 35001 - 35999"
        read -p "请输入 usque 内部端口 [默认: $DEFAULT_INTERNAL]: " INTERNAL_PORT
        INTERNAL_PORT=${INTERNAL_PORT:-$DEFAULT_INTERNAL}
        
        read -p "请输入 GOST 公网出口端口 [默认: $DEFAULT_PUBLIC]: " PUBLIC_PORT
        PUBLIC_PORT=${PUBLIC_PORT:-$DEFAULT_PUBLIC}
        echo "-----------------------------------------------"

        # 1. 启动 usque
        echo "正在尝试启动 usque (后端)..."
        rm -f usque.log
        nohup $BINARY socks --port $INTERNAL_PORT --bind 127.0.0.1 --config "$CONFIG_FILE" > usque.log 2>&1 &
        echo $! > $PID_USQUE
        
        sleep 3
        if grep -qi "address already in use" usque.log; then
            echo "❌ 错误: 内部端口 $INTERNAL_PORT 已被占用！"
            stop_services
            continue
        fi
        
        if grep -qi "failed to parse private key" usque.log; then
            echo "❌ 错误: 私钥解析失败 (ASN.1 Syntax Error)！"
            echo "请确保 config.json 中的 private_key 是 DER 格式的 Base64 字符串。"
            stop_services
            exit 1
        fi

        if ! is_running $PID_USQUE; then
            echo "❌ 错误: usque 启动失败。最近的日志内容："
            tail -n 5 usque.log
            stop_services
            continue
        fi
        echo "✅ usque 启动成功 (127.0.0.1:$INTERNAL_PORT)"

        # 2. 启动 GOST
        echo "正在尝试启动 GOST (出口)..."
        rm -f gost.log
        nohup $GOST -L "ss://$SS_METHOD:$SS_PASS@:$PUBLIC_PORT" -F "socks5://127.0.0.1:$INTERNAL_PORT" > gost.log 2>&1 &
        echo $! > $PID_GOST
        
        sleep 2
        if grep -qiE "address already in use|bind: permission denied" gost.log; then
            echo "❌ 错误: 公网端口 $PUBLIC_PORT 不可用！"
            stop_services
            continue
        fi

        if ! is_running $PID_GOST; then
            echo "❌ 错误: GOST 启动失败，请检查 gost.log"
            stop_services
            continue
        fi

        echo "✅ GOST 启动成功 (公网端口:$PUBLIC_PORT)"
        echo "-----------------------------------------------"
        echo "🎉 所有服务已就绪！"
        echo "SS 节点链接: ss://$(echo -n "$SS_METHOD:$SS_PASS" | base64)@你的IP:$PUBLIC_PORT#Vietnam"
        break
    done
}

case "$1" in
    register)
        if [ -z "$2" ]; then echo "用法: ./manage.sh register <TOKEN>"; exit 1; fi
        chmod +x "$BINARY" 2>/dev/null
        $BINARY register --jwt "$2" --accept-tos
        ;;
    start)
        if is_running $PID_USQUE && is_running $PID_GOST; then
            echo "服务已在运行中。"
            exit 0
        fi
        chmod +x "$BINARY" "$GOST" 2>/dev/null
        start_interactive
        ;;
    stop)
        echo "停止服务..."
        stop_services
        echo "已停止。"
        ;;
    status)
        is_running $PID_USQUE && echo "usque: 运行中" || echo "usque: 已停止"
        is_running $PID_GOST && echo "gost: 运行中" || echo "gost: 已停止"
        ;;
    *)
        echo "用法: ./manage.sh {register|start|stop|status}"
        ;;
esac
