#!/bin/bash
# Mindsnap团队的电影推荐系统分团队 

# deploy.sh
# Mindsnap团队的电影推荐系统分团队 部署脚本

# 设置颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
NC='\033[0m' # 无颜色（恢复默认）

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
echogreen() { echo -e "${GREEN}$1${NC}"; }
echored() { echo -e "${RED}$1${NC}"; }
echoyellow() { echo -e "${YELLOW}$1${NC}"; }
echoblue() { echo -e "${BLUE}$1${NC}"; }
echomagenta() { echo -e "${MAGENTA}$1${NC}"; }
echocyan() { echo -e "${CYAN}$1${NC}"; }
echowhite() { echo -e "${WHITE}$1${NC}"; }
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; echo "$1"; }

# 显示分隔线函数
show_separator() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 显示步骤标题函数
show_step() {
  show_separator
  echo -e "${MAGENTA}【 $1 】${NC}"
}

# 显示完成消息函数
show_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# 显示错误消息函数
show_error() {
  echo -e "${RED}✗ $1${NC}"
}

# 显示加载动画函数
show_spinner() {
  local pid=$1
  local message=$2
  local spin='-\|/'
  local i=0
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r${CYAN}${spin:$i:1}${NC} ${YELLOW}%s...${NC}" "$message"
    sleep 0.1
  done
  printf "\r${GREEN}✓${NC} ${GREEN}%s${NC}   \n" "$message"
}

# --- 脚本开始 ---
clear # 清屏
exec > >(tee -a "$LOG_FILE") 2>&1 # 同时输出到控制台和日志文件

# 显示大型艺术标题
echo -e "${MAGENTA}"
cat << "EOF"
███╗   ███╗ ██████╗ ██╗   ██╗██╗███████╗
████╗ ████║██╔═══██╗██║   ██║██║██╔════╝
██╔████╔██║██║   ██║██║   ██║██║█████╗  
██║╚██╔╝██║██║   ██║╚██╗ ██╔╝██║██╔══╝  
██║ ╚═╝ ██║╚██████╔╝ ╚████╔╝ ██║███████╗
╚═╝     ╚═╝ ╚═════╝   ╚═══╝  ╚═╝╚══════╝
                                        
██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗███╗   ███╗███████╗███╗   ██╗██████╗ ███████╗██████╗ 
██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗ ████║████╗ ████║██╔════╝████╗  ██║██╔══██╗██╔════╝██╔══██╗
██████╔╝█████╗  ██║     ██║   ██║██╔████╔██║██╔████╔██║█████╗  ██╔██╗ ██║██║  ██║█████╗  ██████╔╝
██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╔╝██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗
██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║██║ ╚═╝ ██║███████╗██║ ╚████║██████╔╝███████╗██║  ██║
╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝
EOF
echo -e "${NC}"
echo -e "${CYAN}💫 Mindsnap团队出品 - 微信公众号电影推荐系统 💫${NC}"
echo -e "${YELLOW}版本: 1.0.0 | 部署日期: $(date '+%Y-%m-%d')${NC}\n"

show_separator
echo -e "${GREEN}👉 开始部署流程...${NC}"
show_separator
echo

# 0. 检查root权限 (运行在80端口需要)
show_step "权限检查"
if [ "$(id -u)" -ne 0 ]; then
  show_error "此脚本需要以root权限运行才能监听80端口"
  log "错误: 脚本需要root权限。"
  echo -e "${YELLOW}请使用 ${CYAN}sudo bash deploy.sh${YELLOW} 重新运行${NC}"
  exit 1
fi
show_success "Root权限检查通过"

# 1. 确认项目目录
show_step "项目目录检查"
if [ ! -f "$PROJECT_DIR/app/main.py" ]; then
  show_error "找不到 $PROJECT_DIR/app/main.py"
  log "错误: 项目目录结构不正确。请确保当前目录是项目根目录。"
  
  # 添加更友好的用户交互
  echo -e "${YELLOW}请输入项目根目录的${WHITE}绝对路径${YELLOW}:${NC} "
  read -r USER_DIR
  PROJECT_DIR=$USER_DIR
  VENV_DIR="$PROJECT_DIR/.venv_prod"
  LOG_FILE="$PROJECT_DIR/deploy.log"
  MAIN_SCRIPT="$PROJECT_DIR/app/main.py"
  
  if [ ! -f "$PROJECT_DIR/app/main.py" ]; then
    show_error "仍然找不到 $PROJECT_DIR/app/main.py"
    log "错误: 无法确定项目目录。部署中止。"
    exit 1
  fi
fi
show_success "项目目录: $PROJECT_DIR"

# 2. 数据库检查
show_step "数据库配置"
echo -e "${CYAN}当前数据库配置:${NC}"
echo -e "  ${YELLOW}• 用户名:${NC} $DB_USER"
echo -e "  ${YELLOW}• 数据库名:${NC} $DB_NAME"
echo -e "${YELLOW}注意: 默认假设MySQL已安装并正确配置${NC}"
echo
echo -e "${CYAN}是否需要创建/初始化数据库? (y/N):${NC} "
read -r create_db

if [[ "$create_db" =~ ^[Yy]$ ]]; then
  log "开始初始化数据库..."
  
  # 确认MySQL已安装
  if ! command -v mysql &> /dev/null; then
    show_error "MySQL未安装。请先安装MySQL服务器"
    log "错误: MySQL未安装。"
    exit 1
  fi
  
  # 提示用户输入MySQL root密码
  echo -e "${YELLOW}请输入MySQL root密码:${NC} "
  read -r -s mysql_root_password
  echo
  
  # 创建数据库和用户
  echo -e "${CYAN}正在创建数据库和用户...${NC}"
  mysql -u root -p"$mysql_root_password" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
  
  if [ $? -ne 0 ]; then
    show_error "数据库创建失败"
    log "错误: 数据库创建失败。"
    exit 1
  fi
  
  # 导入数据库结构
  if [ -f "$PROJECT_DIR/database_schema.sql" ]; then
    echo -e "${CYAN}正在导入数据库结构和初始数据...${NC}"
    mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$PROJECT_DIR/database_schema.sql"
    
    if [ $? -ne 0 ]; then
      show_error "数据库结构导入失败"
      log "错误: 数据库结构导入失败。"
      exit 1
    fi
    show_success "数据库初始化完成"
  else
    show_error "找不到 database_schema.sql 文件，无法导入数据库结构"
    log "警告: 找不到 database_schema.sql 文件。"
  fi
else
  log "跳过数据库初始化。"
  echo -e "${YELLOW}⚠️ 注意: 您需要确保数据库已正确配置，否则应用可能无法正常运行。${NC}"
fi

# 3. 创建/激活虚拟环境
show_step "Python虚拟环境"
if [ ! -d "$VENV_DIR" ]; then
  echo -e "${CYAN}创建Python虚拟环境 $VENV_DIR...${NC}"
  "$PYTHON_EXECUTABLE" -m venv "$VENV_DIR" &
  show_spinner $! "创建虚拟环境"
  
  if [ $? -ne 0 ]; then
    show_error "创建虚拟环境失败"
    log "错误: 创建虚拟环境失败。"
    exit 1
  fi
  show_success "虚拟环境创建成功"
else
  show_success "虚拟环境已存在"
fi

echo -e "${CYAN}激活虚拟环境...${NC}"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate" || { show_error "激活虚拟环境失败"; log "错误: 激活虚拟环境失败。"; exit 1; }
show_success "虚拟环境已激活"

# 4. 安装依赖
show_step "安装项目依赖"
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  echo -e "${CYAN}从requirements.txt安装依赖...${NC}"
  pip install -r "$PROJECT_DIR/requirements.txt" &
  show_spinner $! "安装依赖包"
  
  if [ $? -ne 0 ]; then
    show_error "安装依赖失败"
    log "错误: 安装依赖失败。"
    deactivate
    exit 1
  fi
  show_success "依赖安装完毕"
else
  show_error "找不到 requirements.txt 文件"
  log "警告: 找不到 requirements.txt 文件。"
  
  # 安装基本依赖
  echo -e "${CYAN}安装基本依赖...${NC}"
  pip install web.py pymysql requests lxml cryptography &
  show_spinner $! "安装基本依赖包"
  
  if [ $? -ne 0 ]; then
    show_error "安装基本依赖失败"
    log "错误: 安装基本依赖失败。"
    deactivate
    exit 1
  fi
  show_success "基本依赖安装完毕"
fi

# 5. 检查并处理80端口占用
show_step "端口检查"
echo -e "${CYAN}检查端口 $PORT 是否被占用...${NC}"
LISTENING_PID=$(lsof -t -i:"$PORT" -sTCP:LISTEN)

if [ -n "$LISTENING_PID" ]; then
  show_error "端口 $PORT 正在被进程 PID: $LISTENING_PID 使用"
  log "警告: 端口 $PORT 被进程 $LISTENING_PID 使用。"
  echo -e "${YELLOW}是否尝试结束该进程? (y/N):${NC} "
  read -r choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}正在结束进程 $LISTENING_PID...${NC}"
    kill -9 "$LISTENING_PID" || { show_error "结束进程 $LISTENING_PID 失败"; log "错误: 结束进程失败。"; deactivate; exit 1; }
    show_success "进程 $LISTENING_PID 已结束"
    # 短暂等待端口释放
    sleep 2
  else
    show_error "用户选择不结束进程。部署中止"
    log "用户选择不结束进程。部署中止。"
    deactivate
    exit 1
  fi
else
  show_success "端口 $PORT 可用"
fi

# 6. 检查配置文件
show_step "配置文件检查"
CONFIG_FILE="$PROJECT_DIR/app/config.py"
if [ -f "$CONFIG_FILE" ]; then
  # 询问是否需要修改配置
  echo -e "${CYAN}是否需要修改数据库连接配置? (y/N):${NC} "
  read -r edit_config
  
  if [[ "$edit_config" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}修改配置文件...${NC}"
    
    # 备份原配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # 获取服务器IP
    server_ip=$(hostname -I | awk '{print $1}')
    
    # 提示用户输入数据库连接信息
    echo -e "${YELLOW}数据库主机地址 [$server_ip]:${NC} "
    read -r db_host
    db_host=${db_host:-$server_ip}
    
    echo -e "${YELLOW}数据库用户名 [$DB_USER]:${NC} "
    read -r db_user
    db_user=${db_user:-$DB_USER}
    
    echo -e "${YELLOW}数据库密码 [$DB_PASSWORD]:${NC} "
    read -r db_pass
    db_pass=${db_pass:-$DB_PASSWORD}
    
    echo -e "${YELLOW}数据库名 [$DB_NAME]:${NC} "
    read -r db_name
    db_name=${db_name:-$DB_NAME}
    
    # 这里使用sed替换配置文件中的数据库连接信息
    # 这种方法假设配置文件有一个标准格式
    sed -i "s/'host': '[^']*'/'host': '$db_host'/g" "$CONFIG_FILE"
    sed -i "s/'user': '[^']*'/'user': '$db_user'/g" "$CONFIG_FILE"
    sed -i "s/'password': '[^']*'/'password': '$db_pass'/g" "$CONFIG_FILE"
    sed -i "s/'db': '[^']*'/'db': '$db_name'/g" "$CONFIG_FILE"
    
    show_success "配置文件已更新"
  else
    show_success "保持现有配置"
  fi
else
  show_error "找不到配置文件 $CONFIG_FILE"
  log "警告: 找不到配置文件，应用可能无法正常运行。"
fi

# 7. 启动应用前检查app目录下的Python文件是否存在模块导入问题
show_step "模块导入问题检查"

# 检查app/main.py中是否设置了正确的sys.path
if ! grep -q "sys.path.insert" "$PROJECT_DIR/app/main.py"; then
  echo -e "${CYAN}修复app/main.py中的路径设置问题...${NC}"
  # 备份文件
  cp "$PROJECT_DIR/app/main.py" "$PROJECT_DIR/app/main.py.bak"
  
  # 添加sys.path.insert代码确保能找到模块
  sed -i '1,10s/import sys/import sys\nimport os\n\n# 添加项目根目录到Python路径\nsys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))/' "$PROJECT_DIR/app/main.py"
  
  show_success "app/main.py已更新，已添加项目路径设置"
fi

# 检查web.application调用是否使用了globals()
if grep -q "app = web.application(urls, locals())" "$PROJECT_DIR/app/main.py"; then
  echo -e "${CYAN}修复app/main.py中的web.application调用...${NC}"
  # 备份文件（如果没有备份过）
  if [ ! -f "$PROJECT_DIR/app/main.py.bak" ]; then
    cp "$PROJECT_DIR/app/main.py" "$PROJECT_DIR/app/main.py.bak"
  fi
  
  # 将locals()改为globals()
  sed -i 's/app = web.application(urls, locals())/app = web.application(urls, globals())/' "$PROJECT_DIR/app/main.py"
  
  show_success "app/main.py已更新，web.application现在使用globals()"
fi

# 检查模块间的导入方式
echo -e "${CYAN}检查app模块间的导入方式...${NC}"

# 修复db_manager.py中的导入
DB_MANAGER_FILE="$PROJECT_DIR/app/db_manager.py"
if [ -f "$DB_MANAGER_FILE" ] && grep -q "from app.config import" "$DB_MANAGER_FILE"; then
  echo -e "${CYAN}修复$DB_MANAGER_FILE中的导入方式...${NC}"
  cp "$DB_MANAGER_FILE" "${DB_MANAGER_FILE}.bak"
  sed -i 's/from app.config import/from .config import/' "$DB_MANAGER_FILE"
  show_success "$DB_MANAGER_FILE已更新，修复了导入方式"
fi

# 修复wechat_handler.py中的导入
WECHAT_HANDLER_FILE="$PROJECT_DIR/app/wechat_handler.py"
if [ -f "$WECHAT_HANDLER_FILE" ]; then
  if grep -q "from app.config import" "$WECHAT_HANDLER_FILE" || grep -q "from app import" "$WECHAT_HANDLER_FILE"; then
    echo -e "${CYAN}修复$WECHAT_HANDLER_FILE中的导入方式...${NC}"
    cp "$WECHAT_HANDLER_FILE" "${WECHAT_HANDLER_FILE}.bak"
    sed -i 's/from app.config import/from .config import/' "$WECHAT_HANDLER_FILE"
    sed -i 's/from app import/from . import/' "$WECHAT_HANDLER_FILE"
    show_success "$WECHAT_HANDLER_FILE已更新，修复了导入方式"
  fi
fi

# 修复recommendation_engine.py中的导入
RECOMMENDATION_FILE="$PROJECT_DIR/app/recommendation_engine.py"
if [ -f "$RECOMMENDATION_FILE" ] && grep -q "from app import" "$RECOMMENDATION_FILE"; then
  echo -e "${CYAN}修复$RECOMMENDATION_FILE中的导入方式...${NC}"
  cp "$RECOMMENDATION_FILE" "${RECOMMENDATION_FILE}.bak"
  sed -i 's/from app import/from . import/' "$RECOMMENDATION_FILE"
  show_success "$RECOMMENDATION_FILE已更新，修复了导入方式"
fi

# 确保__init__.py文件存在
if [ ! -f "$PROJECT_DIR/app/__init__.py" ]; then
  echo -e "${CYAN}创建app/__init__.py文件...${NC}"
  touch "$PROJECT_DIR/app/__init__.py"
  show_success "app/__init__.py已创建"
fi

show_success "Python模块导入问题检查完成"

# 8. 启动应用
show_step "启动应用服务"
echo -e "${CYAN}启动应用 $MAIN_SCRIPT 监听端口 $PORT ...${NC}"

# 使用nohup后台运行，直接使用Python脚本方式而非模块导入方式
cd "$PROJECT_DIR" && nohup "$VENV_DIR/bin/python" "$PROJECT_DIR/app/main.py" "$PORT" > "$LOG_FILE" 2>&1 &
APP_PID=$! # 获取后台进程PID

echo -e "${MAGENTA}应用启动中，请稍候...${NC}"
for i in {1..30}; do
  echo -ne "${CYAN}[${GREEN}"
  for ((j=1; j<=i; j++)); do echo -ne "▓"; done
  for ((j=i+1; j<=30; j++)); do echo -ne "░"; done
  echo -ne "${CYAN}] ${GREEN}$(( i * 100 / 30 ))%${NC}\r"
  sleep 0.1
done
echo -e "${CYAN}[${GREEN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${CYAN}] ${GREEN}100%${NC}"

# 检查应用是否成功启动
if ps -p $APP_PID > /dev/null; then
  echo
  show_success "应用已启动，PID: $APP_PID"
  log "应用启动成功，PID: $APP_PID。"
  
  # 保存PID到文件，方便后续管理
  echo $APP_PID > "$PROJECT_DIR/app.pid"
  
  # 显示URL
  server_ip=$(hostname -I | awk '{print $1}')
  echo
  echo -e "${GREEN}应用访问地址:${NC} ${UNDERLINE}http://$server_ip/${NC}"
  echo -e "${GREEN}微信配置URL:${NC} ${UNDERLINE}http://$server_ip/${NC}"
else
  show_error "应用启动失败。请检查 $LOG_FILE 获取更多信息"
  log "错误: 应用启动失败。"
  deactivate
  exit 1
fi

show_separator
echo -e "${GREEN}"
cat << "EOF"
       ✓ ✓ ✓       部署成功       ✓ ✓ ✓ 
EOF
echo -e "${NC}"
show_separator
log "部署完成。"

# 微信公众号配置提醒
echo
echo -e "${YELLOW}微信公众号配置信息:${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${MAGENTA}服务器地址(URL):${NC} http://$(hostname -I | awk '{print $1}')/ ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${MAGENTA}令牌(Token):${NC} HelloMindsnap                    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${MAGENTA}消息加解密方式:${NC} 明文模式或兼容模式               ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"

deactivate # 退出虚拟环境

# 添加便捷的启动/停止脚本
cat > "$PROJECT_DIR/start.sh" << EOF
#!/bin/bash
sudo bash deploy.sh
EOF

cat > "$PROJECT_DIR/stop.sh" << EOF
#!/bin/bash

# 设置颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

echo -e "\${CYAN}┌─────────────────────────────────────┐\${NC}"
echo -e "\${CYAN}│\${NC} \${YELLOW}电影推荐系统服务停止\${NC}                 \${CYAN}│\${NC}"
echo -e "\${CYAN}└─────────────────────────────────────┘\${NC}"

if [ -f "$PROJECT_DIR/app.pid" ]; then
  PID=\$(cat "$PROJECT_DIR/app.pid")
  echo -e "\${YELLOW}正在停止应用 (PID: \${GREEN}\$PID\${YELLOW})...\${NC}"
  sudo kill \$PID
  rm "$PROJECT_DIR/app.pid"
  echo -e "\${GREEN}应用已停止。\${NC}"
else
  echo -e "\${YELLOW}找不到PID文件，尝试查找进程...\${NC}"
  PID=\$(lsof -t -i:80)
  if [ -n "\$PID" ]; then
    echo -e "\${YELLOW}找到端口80的进程 (PID: \${GREEN}\$PID\${YELLOW})，正在停止...\${NC}"
    sudo kill \$PID
    echo -e "\${GREEN}应用已停止。\${NC}"
  else
    echo -e "\${RED}找不到运行中的应用。\${NC}"
  fi
fi
EOF

chmod +x "$PROJECT_DIR/start.sh" "$PROJECT_DIR/stop.sh"
echogreen "已创建便捷脚本: start.sh 和 stop.sh" 

echo
echo -e "${CYAN}日志文件: ${UNDERLINE}$LOG_FILE${NC}"
echo
echo -e "${GREEN}感谢使用Mindsnap团队的电影推荐系统部署脚本！${NC}"
echo 