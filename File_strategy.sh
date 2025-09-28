#!/usr/bin/env bash
# install_filebrowser_15200.sh
# 一键安装 FileBrowser Quantum，容器内外端口都用 15200，不占用 80

set -e

FOLDER_TO_USE="${1:-$HOME/filebrowser_data}"
CONFIG_FILE="${FOLDER_TO_USE}/config.yaml"
IMAGE="gtstef/filebrowser:latest"
CONTAINER_NAME="filebrowser"
PORT=15200

echo "🚀 开始安装 FileBrowser Quantum..."
echo "📂 数据目录: $FOLDER_TO_USE"
echo "🌐 使用端口: $PORT "

# 检查端口
if lsof -i :"$PORT" >/dev/null 2>&1; then
  echo "❌ 端口 $PORT 已被占用，请先释放或改用其他端口"
  exit 1
fi

mkdir -p "$FOLDER_TO_USE"

# 检测旧配置文件，如果包含旧字段就删掉重建
if [ -f "$CONFIG_FILE" ]; then
  if grep -q "root:" "$CONFIG_FILE" || grep -q "log:" "$CONFIG_FILE"; then
    echo "⚠️ 检测到旧版本配置文件，已删除重建..."
    rm -f "$CONFIG_FILE"
  fi
fi

# 生成新配置文件
if [ ! -f "$CONFIG_FILE" ]; then
  echo "⚙️ 生成 config.yaml (监听 $PORT)..."
  cat > "$CONFIG_FILE" <<EOF
server:
  sources:
    - path: /srv
      config:
        defaultEnabled: true
  port: $PORT
auth:
  adminUsername: admin
  adminPassword: admin
EOF
else
  sed -i "s/port:.*/port: $PORT/" "$CONFIG_FILE"
fi

# 拉取镜像
echo "🐳 拉取镜像 $IMAGE ..."
docker pull "$IMAGE"

# 删除旧容器
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
  echo "🛑 停止并删除旧容器..."
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# 启动新容器，绑定 15200
echo "▶️ 启动 FileBrowser 容器..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -v "$FOLDER_TO_USE:/srv" \
  -v "$CONFIG_FILE:/home/filebrowser/config.yaml" \
  -p "$PORT:$PORT" \
  "$IMAGE"

if [ $? -eq 0 ]; then
  echo "✅ FileBrowser 已成功运行！"
  echo "🌐 访问地址: http://$(hostname -I | awk '{print $1}'):$PORT"
  echo "🔑 默认账号: admin / admin"
  echo "💡 建议修改 config.yaml 中的 adminPassword 后执行： docker restart $CONTAINER_NAME"
else
  echo "❌ 启动失败，请执行： docker logs $CONTAINER_NAME 查看详情"
fi
