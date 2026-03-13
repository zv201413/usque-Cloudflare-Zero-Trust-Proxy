#!/bin/bash
set -e

PROJECT_DIR=$(pwd)

# 1. 下载 GOST (v3.0.0-rc10)
GOST_VER="3.0.0-rc10"
GOST_URL="https://github.com/go-gost/gost/releases/download/v${GOST_VER}/gost_${GOST_VER}_linux_amd64.tar.gz"

echo "[1/2] 正在在线拉取 GOST..."
curl -L "$GOST_URL" -o "$PROJECT_DIR/gost.tar.gz"
tar -xzf "$PROJECT_DIR/gost.tar.gz" -C "$PROJECT_DIR" gost
rm "$PROJECT_DIR/gost.tar.gz"
chmod +x "$PROJECT_DIR/gost"

# 2. 下载 usque (v1.4.2)
USQUE_VER="1.4.2"
USQUE_URL="https://github.com/Diniboy1123/usque/releases/download/v${USQUE_VER}/usque_${USQUE_VER}_linux_amd64.zip"

echo "[2/2] 正在在线拉取 usque v${USQUE_VER}..."
curl -L "$USQUE_URL" -o "$PROJECT_DIR/usque.zip"
# 使用 python 进行解压，确保受限环境兼容性
python3 -c "import zipfile; zipfile.ZipFile('usque.zip').extract('usque', '$PROJECT_DIR')"
# 重命名为 usque-bin
mv "$PROJECT_DIR/usque" "$PROJECT_DIR/usque-bin"
rm "$PROJECT_DIR/usque.zip"
chmod +x "$PROJECT_DIR/usque-bin"

echo "---------------------------------------"
echo "✅ 二进制文件拉取完成！"
echo "1. 请按照 README.md 获取 Token"
echo "2. 运行 ./manage.sh register <TOKEN> 进行注册"
echo "3. 运行 ./manage.sh start 开启加密代理"
