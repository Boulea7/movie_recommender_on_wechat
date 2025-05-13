#!/bin/bash
# Mindsnap团队的电影推荐系统分团队 - 停止脚本

# 设置颜色输出
echogreen() { echo -e "\033[0;32m$1\033[0m"; }
echored() { echo -e "\033[0;31m$1\033[0m"; }
echoyellow() { echo -e "\033[0;33m$1\033[0m"; }

# 配置变量
PROJECT_DIR="$PWD"
PID_FILE="$PROJECT_DIR/app.pid"
PORT=80

# 函数：检查并清理端口占用
check_port() {
  LISTENING_PID=$(lsof -t -i:$PORT -sTCP:LISTEN)
  if [ -n "$LISTENING_PID" ]; then
    echoyellow "发现端口 $PORT 被进程 PID: $LISTENING_PID 占用"
    
    # 确认是否为我们的服务
    if [ -f "$PID_FILE" ] && [ "$LISTENING_PID" = "$(cat "$PID_FILE")" ]; then
      echo "确认是本服务进程，准备结束..."
    else
      echoyellow "警告: 占用端口的不是由start.sh启动的服务进程。"
      read -r -p "是否结束该进程? (y/N): " choice
      if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo "用户取消操作。"
        return 1
      fi
    fi
    
    # 尝试正常终止进程
    echo "正在尝试结束进程 $LISTENING_PID..."
    kill "$LISTENING_PID"
    
    # 等待进程结束
    for i in {1..5}; do
      if ! ps -p "$LISTENING_PID" > /dev/null; then
        echogreen "进程已成功结束"
        return 0
      fi
      echo "等待进程结束... ($i/5)"
      sleep 1
    done
    
    # 如果进程仍然存在，使用强制终止
    if ps -p "$LISTENING_PID" > /dev/null; then
      echoyellow "进程未响应，将强制终止..."
      kill -9 "$LISTENING_PID"
      sleep 1
      
      if ps -p "$LISTENING_PID" > /dev/null; then
        echored "错误: 无法结束进程 $LISTENING_PID"
        return 1
      else
        echogreen "进程已强制终止"
        return 0
      fi
    fi
  else
    echo "端口 $PORT 未被占用"
    return 0
  fi
}

# 主程序开始
echo "正在停止微信电影推荐系统服务..."

# 如果存在PID文件，尝试根据PID停止服务
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  echo "找到PID文件，服务进程PID: $PID"
  
  if ps -p "$PID" > /dev/null; then
    echo "确认服务正在运行，准备停止..."
    kill "$PID"
    
    # 等待进程结束
    for i in {1..5}; do
      if ! ps -p "$PID" > /dev/null; then
        echogreen "服务已成功停止"
        rm -f "$PID_FILE"
        break
      fi
      echo "等待服务停止... ($i/5)"
      sleep 1
    done
    
    # 如果进程仍然存在，使用强制终止
    if ps -p "$PID" > /dev/null; then
      echoyellow "服务未响应，将强制终止..."
      kill -9 "$PID"
      sleep 1
      
      if ! ps -p "$PID" > /dev/null; then
        echogreen "服务已强制终止"
        rm -f "$PID_FILE"
      else
        echored "错误: 无法停止服务，请手动结束进程 $PID"
        exit 1
      fi
    fi
  else
    echoyellow "PID文件存在，但服务似乎未运行。将清除PID文件。"
    rm -f "$PID_FILE"
  fi
else
  echoyellow "未找到PID文件，将检查端口占用情况..."
  check_port
  if [ $? -eq 0 ]; then
    echogreen "端口已释放"
  else
    echored "端口释放失败"
    exit 1
  fi
fi

echogreen "微信电影推荐系统服务已停止" 