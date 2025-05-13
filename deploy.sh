#!/bin/bash
# Mindsnap团队的电影推荐系统分团队 

# deploy.sh
# Mindsnap团队的电影推荐系统分团队 部署脚本

# --- 配置变量 ---
PROJECT_DIR="$PWD" # 默认使用当前目录作为项目路径
VENV_DIR="$PROJECT_DIR/.venv_prod" # 生产虚拟环境目录名
LOG_FILE="$PROJECT_DIR/deploy.log"
PYTHON_EXECUTABLE="python3" # 或 python3.9 等具体版本
MAIN_SCRIPT="$PROJECT_DIR/app/main.py"
PORT=80 # 默认端口为80
DB_USER="movie_rec_user"
DB_PASSWORD="MovieRecDbP@ssw0rd" # 生产环境中建议使用更强密码
DB_NAME="movie_recommendation_system"

# --- 辅助函数 ---
echogreen() { echo -e "\033[0;32m$1\033[0m"; }
echored() { echo -e "\033[0;31m$1\033[0m"; }
echoyellow() { echo -e "\033[0;33m$1\033[0m"; }
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }

# --- 脚本开始 ---
exec > >(tee -a "$LOG_FILE") 2>&1 # 同时输出到控制台和日志文件

log "====================================================="
log "开始部署 Mindsnap 电影推荐系统..."
log "====================================================="

# 0. 检查root权限 (运行在80端口需要)
if [ "$(id -u)" -ne 0 ]; then
  echored "错误: 此脚本需要以root权限运行才能监听80端口。"
  log "错误: 脚本需要root权限。"
  log "请使用 sudo bash deploy.sh 重新运行"
  exit 1
fi
log "Root权限检查通过。"

# 1. 确认项目目录
if [ ! -f "$PROJECT_DIR/app/main.py" ]; then
  echored "错误: 找不到 $PROJECT_DIR/app/main.py"
  log "错误: 项目目录结构不正确。请确保当前目录是项目根目录。"
  
  # 尝试让用户手动输入项目路径
  read -r -p "请输入项目根目录的绝对路径: " USER_DIR
  PROJECT_DIR=$USER_DIR
  VENV_DIR="$PROJECT_DIR/.venv_prod"
  LOG_FILE="$PROJECT_DIR/deploy.log"
  MAIN_SCRIPT="$PROJECT_DIR/app/main.py"
  
  if [ ! -f "$PROJECT_DIR/app/main.py" ]; then
    echored "错误: 仍然找不到 $PROJECT_DIR/app/main.py"
    log "错误: 无法确定项目目录。部署中止。"
    exit 1
  fi
fi
log "项目目录: $PROJECT_DIR"

# 2. 数据库检查
echoyellow "数据库配置:"
echoyellow "- 用户名: $DB_USER"
echoyellow "- 数据库名: $DB_NAME"
echoyellow "注意: 默认假设MySQL已安装并正确配置"
read -r -p "是否需要创建/初始化数据库? (y/N): " create_db

if [[ "$create_db" =~ ^[Yy]$ ]]; then
  log "开始初始化数据库..."
  
  # 确认MySQL已安装
  if ! command -v mysql &> /dev/null; then
    echored "错误: MySQL未安装。请先安装MySQL服务器。"
    log "错误: MySQL未安装。"
    exit 1
  fi
  
  # 提示用户输入MySQL root密码
  read -r -s -p "请输入MySQL root密码: " mysql_root_password
  echo ""
  
  # 创建数据库和用户
  log "创建数据库和用户..."
  mysql -u root -p"$mysql_root_password" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
  
  if [ $? -ne 0 ]; then
    echored "错误: 数据库创建失败。"
    log "错误: 数据库创建失败。"
    exit 1
  fi
  
  # 导入数据库结构
  if [ -f "$PROJECT_DIR/database_schema.sql" ]; then
    log "导入数据库结构和初始数据..."
    mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$PROJECT_DIR/database_schema.sql"
    
    if [ $? -ne 0 ]; then
      echored "错误: 数据库结构导入失败。"
      log "错误: 数据库结构导入失败。"
      exit 1
    fi
    echogreen "数据库初始化完成。"
  else
    echored "警告: 找不到 database_schema.sql 文件，无法导入数据库结构。"
    log "警告: 找不到 database_schema.sql 文件。"
  fi
else
  log "跳过数据库初始化。"
  echoyellow "注意: 您需要确保数据库已正确配置，否则应用可能无法正常运行。"
fi

# 3. 创建/激活虚拟环境
if [ ! -d "$VENV_DIR" ]; then
  log "创建Python虚拟环境 $VENV_DIR..."
  "$PYTHON_EXECUTABLE" -m venv "$VENV_DIR" || { echored "错误: 创建虚拟环境失败。"; log "错误: 创建虚拟环境失败。"; exit 1; }
  log "虚拟环境创建成功。"
else
  log "虚拟环境 $VENV_DIR 已存在。"
fi

log "激活虚拟环境..."
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate" || { echored "错误: 激活虚拟环境失败。"; log "错误: 激活虚拟环境失败。"; exit 1; }
log "虚拟环境已激活。"

# 4. 安装依赖
log "安装项目依赖..."
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  pip install -r "$PROJECT_DIR/requirements.txt" || { echored "错误: 安装依赖失败。"; log "错误: 安装依赖失败。"; deactivate; exit 1; }
  log "依赖安装完毕。"
else
  echored "警告: 找不到 requirements.txt 文件。"
  log "警告: 找不到 requirements.txt 文件。"
  
  # 安装基本依赖
  log "安装基本依赖..."
  pip install web.py pymysql requests lxml cryptography || { echored "错误: 安装基本依赖失败。"; log "错误: 安装基本依赖失败。"; deactivate; exit 1; }
  log "基本依赖安装完毕。"
fi

# 5. 检查并处理80端口占用
log "检查端口 $PORT 是否被占用..."
LISTENING_PID=$(lsof -t -i:"$PORT" -sTCP:LISTEN)

if [ -n "$LISTENING_PID" ]; then
  echored "警告: 端口 $PORT 正在被进程 PID: $LISTENING_PID 使用。"
  log "警告: 端口 $PORT 被进程 $LISTENING_PID 使用。"
  read -r -p "是否尝试结束该进程? (y/N): " choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    log "尝试结束进程 $LISTENING_PID..."
    kill -9 "$LISTENING_PID" || { echored "错误: 结束进程 $LISTENING_PID 失败。"; log "错误: 结束进程失败。"; deactivate; exit 1; }
    log "进程 $LISTENING_PID 已结束。"
    # 短暂等待端口释放
    sleep 2
  else
    echored "用户选择不结束进程。部署中止。"
    log "用户选择不结束进程。部署中止。"
    deactivate
    exit 1
  fi
else
  log "端口 $PORT 可用。"
fi

# 6. 检查配置文件
log "检查配置文件..."
CONFIG_FILE="$PROJECT_DIR/app/config.py"
if [ -f "$CONFIG_FILE" ]; then
  # 询问是否需要修改配置
  read -r -p "是否需要修改数据库连接配置? (y/N): " edit_config
  
  if [[ "$edit_config" =~ ^[Yy]$ ]]; then
    log "修改配置文件..."
    
    # 备份原配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # 获取服务器IP
    server_ip=$(hostname -I | awk '{print $1}')
    
    # 提示用户输入数据库连接信息
    read -r -p "数据库主机地址 [$server_ip]: " db_host
    db_host=${db_host:-$server_ip}
    
    read -r -p "数据库用户名 [$DB_USER]: " db_user
    db_user=${db_user:-$DB_USER}
    
    read -r -p "数据库密码 [$DB_PASSWORD]: " db_pass
    db_pass=${db_pass:-$DB_PASSWORD}
    
    read -r -p "数据库名 [$DB_NAME]: " db_name
    db_name=${db_name:-$DB_NAME}
    
    # 这里使用sed替换配置文件中的数据库连接信息
    # 这种方法假设配置文件有一个标准格式
    sed -i "s/'host': '[^']*'/'host': '$db_host'/g" "$CONFIG_FILE"
    sed -i "s/'user': '[^']*'/'user': '$db_user'/g" "$CONFIG_FILE"
    sed -i "s/'password': '[^']*'/'password': '$db_pass'/g" "$CONFIG_FILE"
    sed -i "s/'db': '[^']*'/'db': '$db_name'/g" "$CONFIG_FILE"
    
    log "配置文件已更新。"
  else
    log "保持现有配置。"
  fi
else
  echored "警告: 找不到配置文件 $CONFIG_FILE"
  log "警告: 找不到配置文件，应用可能无法正常运行。"
fi

# 7. 启动应用前检查app目录下的Python文件是否存在模块导入问题
log "检查Python模块导入问题..."

# 检查app/main.py中是否设置了正确的sys.path
if ! grep -q "sys.path.insert" "$PROJECT_DIR/app/main.py"; then
  log "修复app/main.py中的路径设置问题..."
  # 备份文件
  cp "$PROJECT_DIR/app/main.py" "$PROJECT_DIR/app/main.py.bak"
  
  # 添加sys.path.insert代码确保能找到模块
  sed -i '1,10s/import sys/import sys\nimport os\n\n# 添加项目根目录到Python路径\nsys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))/' "$PROJECT_DIR/app/main.py"
  
  log "app/main.py已更新，已添加项目路径设置"
fi

# 检查web.application调用是否使用了globals()
if grep -q "app = web.application(urls, locals())" "$PROJECT_DIR/app/main.py"; then
  log "修复app/main.py中的web.application调用..."
  # 备份文件（如果没有备份过）
  if [ ! -f "$PROJECT_DIR/app/main.py.bak" ]; then
    cp "$PROJECT_DIR/app/main.py" "$PROJECT_DIR/app/main.py.bak"
  fi
  
  # 将locals()改为globals()
  sed -i 's/app = web.application(urls, locals())/app = web.application(urls, globals())/' "$PROJECT_DIR/app/main.py"
  
  log "app/main.py已更新，web.application现在使用globals()"
fi

# 检查模块间的导入方式
log "检查app模块间的导入方式..."

# 修复db_manager.py中的导入
DB_MANAGER_FILE="$PROJECT_DIR/app/db_manager.py"
if [ -f "$DB_MANAGER_FILE" ] && grep -q "from app.config import" "$DB_MANAGER_FILE"; then
  log "修复$DB_MANAGER_FILE中的导入方式..."
  cp "$DB_MANAGER_FILE" "${DB_MANAGER_FILE}.bak"
  sed -i 's/from app.config import/from .config import/' "$DB_MANAGER_FILE"
  log "$DB_MANAGER_FILE已更新，修复了导入方式"
fi

# 修复wechat_handler.py中的导入
WECHAT_HANDLER_FILE="$PROJECT_DIR/app/wechat_handler.py"
if [ -f "$WECHAT_HANDLER_FILE" ]; then
  if grep -q "from app.config import" "$WECHAT_HANDLER_FILE" || grep -q "from app import" "$WECHAT_HANDLER_FILE"; then
    log "修复$WECHAT_HANDLER_FILE中的导入方式..."
    cp "$WECHAT_HANDLER_FILE" "${WECHAT_HANDLER_FILE}.bak"
    sed -i 's/from app.config import/from .config import/' "$WECHAT_HANDLER_FILE"
    sed -i 's/from app import/from . import/' "$WECHAT_HANDLER_FILE"
    log "$WECHAT_HANDLER_FILE已更新，修复了导入方式"
  fi
fi

# 修复recommendation_engine.py中的导入
RECOMMENDATION_FILE="$PROJECT_DIR/app/recommendation_engine.py"
if [ -f "$RECOMMENDATION_FILE" ] && grep -q "from app import" "$RECOMMENDATION_FILE"; then
  log "修复$RECOMMENDATION_FILE中的导入方式..."
  cp "$RECOMMENDATION_FILE" "${RECOMMENDATION_FILE}.bak"
  sed -i 's/from app import/from . import/' "$RECOMMENDATION_FILE"
  log "$RECOMMENDATION_FILE已更新，修复了导入方式"
fi

# 确保__init__.py文件存在
if [ ! -f "$PROJECT_DIR/app/__init__.py" ]; then
  log "创建app/__init__.py文件..."
  touch "$PROJECT_DIR/app/__init__.py"
  log "app/__init__.py已创建"
fi

log "Python模块导入问题检查完成"

# 8. 启动应用
log "启动应用 $MAIN_SCRIPT 监听端口 $PORT ..."

# 使用nohup后台运行，直接使用Python脚本方式而非模块导入方式
cd "$PROJECT_DIR" && nohup "$VENV_DIR/bin/python" "$PROJECT_DIR/app/main.py" "$PORT" > "$LOG_FILE" 2>&1 &
APP_PID=$! # 获取后台进程PID

sleep 3 # 等待应用启动

# 检查应用是否成功启动
if ps -p $APP_PID > /dev/null; then
  echogreen "应用已启动，PID: $APP_PID。日志文件: $LOG_FILE"
  log "应用启动成功，PID: $APP_PID。"
  
  # 保存PID到文件，方便后续管理
  echo $APP_PID > "$PROJECT_DIR/app.pid"
  
  # 显示URL
  server_ip=$(hostname -I | awk '{print $1}')
  echogreen "应用访问地址: http://$server_ip/"
  echogreen "微信配置URL请使用: http://$server_ip/"
else
  echored "错误: 应用启动失败。请检查 $LOG_FILE 获取更多信息。"
  log "错误: 应用启动失败。"
  deactivate
  exit 1
fi

log "====================================================="
echogreen "Mindsnap 电影推荐系统部署完成！"
log "部署完成。"
log "====================================================="

# 微信公众号配置提醒
echoyellow "请在微信公众号后台开发者配置中设置:"
echoyellow "- 服务器地址(URL): http://$(hostname -I | awk '{print $1}')/"
echoyellow "- 令牌(Token): HelloMindsnap"
echoyellow "- 消息加解密方式: 明文模式或兼容模式"

deactivate # 退出虚拟环境

# 添加便捷的启动/停止脚本
cat > "$PROJECT_DIR/start.sh" << EOF
#!/bin/bash
sudo bash deploy.sh
EOF

cat > "$PROJECT_DIR/stop.sh" << EOF
#!/bin/bash
if [ -f "$PROJECT_DIR/app.pid" ]; then
  PID=\$(cat "$PROJECT_DIR/app.pid")
  echo "正在停止应用 (PID: \$PID)..."
  sudo kill \$PID
  rm "$PROJECT_DIR/app.pid"
  echo "应用已停止。"
else
  echo "找不到PID文件，尝试查找进程..."
  PID=\$(lsof -t -i:80)
  if [ -n "\$PID" ]; then
    echo "找到端口80的进程 (PID: \$PID)，正在停止..."
    sudo kill \$PID
    echo "应用已停止。"
  else
    echo "找不到运行中的应用。"
  fi
fi
EOF

chmod +x "$PROJECT_DIR/start.sh" "$PROJECT_DIR/stop.sh"
echogreen "已创建便捷脚本: start.sh 和 stop.sh" 