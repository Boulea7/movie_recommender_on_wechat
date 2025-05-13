#!/bin/bash
# Mindsnap团队的电影推荐系统分团队 - 启动脚本

# 设置颜色输出
echogreen() { echo -e "\033[0;32m$1\033[0m"; }
echored() { echo -e "\033[0;31m$1\033[0m"; }
echoyellow() { echo -e "\033[0;33m$1\033[0m"; }

# 配置变量
PROJECT_DIR="$PWD"
VENV_DIR="$PROJECT_DIR/.venv_prod"
MAIN_SCRIPT="$PROJECT_DIR/app/main.py"
LOG_FILE="$PROJECT_DIR/app.log"
PID_FILE="$PROJECT_DIR/app.pid"
PORT=80

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
  echored "错误: 此脚本需要以root权限运行才能监听80端口。"
  echo "请使用 sudo bash start.sh 重新运行"
  exit 1
fi

# 检查服务是否已经在运行
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if ps -p "$PID" > /dev/null; then
    echoyellow "微信电影推荐系统服务已经在运行中 (PID: $PID)"
    echo "如需重启服务，请先运行 sudo bash stop.sh"
    exit 0
  else
    echoyellow "检测到旧的PID文件，但服务未运行。将清除该文件并启动新服务。"
    rm -f "$PID_FILE"
  fi
fi

# 检查端口是否被占用
LISTENING_PID=$(lsof -t -i:$PORT -sTCP:LISTEN)
if [ -n "$LISTENING_PID" ]; then
  echored "警告: 端口 $PORT 已被进程 PID: $LISTENING_PID 占用。"
  echo "请先结束该进程，或使用 sudo bash stop.sh 停止服务。"
  exit 1
fi

# 检查虚拟环境
if [ ! -d "$VENV_DIR" ]; then
  echored "错误: 找不到虚拟环境，请先运行 deploy.sh 进行完整部署。"
  exit 1
fi

# 激活虚拟环境并启动应用
echo "正在启动微信电影推荐系统服务..."
source "$VENV_DIR/bin/activate"

# 启动应用
nohup "$VENV_DIR/bin/python" "$MAIN_SCRIPT" "$PORT" > "$LOG_FILE" 2>&1 &
APP_PID=$!

# 等待3秒检查服务是否成功启动
sleep 3
if ps -p "$APP_PID" > /dev/null; then
  echo "$APP_PID" > "$PID_FILE"
  server_ip=$(hostname -I | awk '{print $1}')
  echogreen "服务启动成功，PID: $APP_PID"
  echogreen "应用访问地址: http://$server_ip/"
  echogreen "微信配置URL: http://$server_ip/"
  echoyellow "查看日志: tail -f $LOG_FILE"
else
  echored "服务启动失败，请检查日志文件获取更多信息: $LOG_FILE"
  exit 1
fi 