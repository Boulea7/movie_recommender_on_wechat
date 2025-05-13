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

# 检查Python文件中的模块导入问题
echo "检查Python模块导入问题..."

# 确保app/main.py中使用了正确的sys.path设置
if ! grep -q "sys.path.insert" "$PROJECT_DIR/app/main.py"; then
  echoyellow "修复app/main.py中的路径设置问题..."
  # 备份文件
  cp "$PROJECT_DIR/app/main.py" "$PROJECT_DIR/app/main.py.bak"
  
  # 添加sys.path.insert代码确保能找到模块
  sed -i '1,10s/import sys/import sys\nimport os\n\n# 添加项目根目录到Python路径\nsys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))/' "$PROJECT_DIR/app/main.py"
  
  echo "app/main.py已更新，已添加项目路径设置"
fi

# 检查web.application调用是否使用了globals()
if grep -q "app = web.application(urls, locals())" "$PROJECT_DIR/app/main.py"; then
  echoyellow "修复app/main.py中的web.application调用..."
  # 备份文件（如果没有备份过）
  if [ ! -f "$PROJECT_DIR/app/main.py.bak" ]; then
    cp "$PROJECT_DIR/app/main.py" "$PROJECT_DIR/app/main.py.bak"
  fi
  
  # 将locals()改为globals()
  sed -i 's/app = web.application(urls, locals())/app = web.application(urls, globals())/' "$PROJECT_DIR/app/main.py"
  
  echo "app/main.py已更新，web.application现在使用globals()"
fi

# 确保相关模块的导入方式正确
for file in "$PROJECT_DIR/app/db_manager.py" "$PROJECT_DIR/app/wechat_handler.py" "$PROJECT_DIR/app/recommendation_engine.py"; do
  if [ -f "$file" ]; then
    if grep -q "from app.config import" "$file" || grep -q "from app import" "$file"; then
      echoyellow "修复$(basename "$file")中的导入方式..."
      cp "$file" "${file}.bak"
      sed -i 's/from app.config import/from .config import/' "$file"
      sed -i 's/from app import/from . import/' "$file"
      echo "$(basename "$file")已更新，修复了导入方式"
    fi
  fi
done

# 确保__init__.py文件存在
if [ ! -f "$PROJECT_DIR/app/__init__.py" ]; then
  echoyellow "创建app/__init__.py文件..."
  touch "$PROJECT_DIR/app/__init__.py"
  echo "app/__init__.py已创建"
fi

echo "Python模块导入问题检查完成"

# 激活虚拟环境并启动应用
echo "正在启动微信电影推荐系统服务..."
source "$VENV_DIR/bin/activate"

# 启动应用
cd "$PROJECT_DIR" && nohup "$VENV_DIR/bin/python" "$PROJECT_DIR/app/main.py" "$PORT" > "$LOG_FILE" 2>&1 &
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