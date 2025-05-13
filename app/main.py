# Mindsnap团队的电影推荐系统分团队 

import web
import sys
import os
import logging

# 添加项目根目录到Python路径，确保能找到模块
# 使用更健壮的方式获取项目根目录
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

# 现在可以导入模块了
from app import wechat_handler
from app.config import WECHAT_TOKEN

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# 定义URL路由
urls = ('/', 'WeChatInterface')

class WeChatInterface:
    """微信公众号接口类"""
    
    def GET(self):
        """
        处理微信服务器的GET请求（验证服务器有效性）
        
        微信服务器会发送以下参数：
        signature: 微信加密签名
        timestamp: 时间戳
        nonce: 随机数
        echostr: 随机字符串
        
        验证通过后返回echostr，表示验证成功
        """
        try:
            # 获取请求参数
            params = web.input()
            signature = params.signature
            timestamp = params.timestamp
            nonce = params.nonce
            echostr = params.echostr
            
            logger.info(f"收到验证请求: signature={signature}, timestamp={timestamp}, nonce={nonce}")
            
            # 进行签名验证
            if wechat_handler.check_signature(signature, timestamp, nonce, WECHAT_TOKEN):
                logger.info("验证成功")
                return echostr  # 验证成功，返回echostr
            else:
                logger.warning("验证失败")
                return "验证失败"  # 验证失败
        except Exception as e:
            logger.error(f"验证请求处理异常: {e}")
            return "请求处理异常"
    
    def POST(self):
        """
        处理微信服务器的POST请求（用户发送消息）
        
        接收用户发送的XML格式消息，调用消息处理函数，返回XML格式响应
        """
        try:
            # 获取POST请求的原始数据（XML格式）
            xml_data = web.data()
            logger.info(f"收到用户消息: {xml_data.decode('utf-8')}")
            
            # 调用消息处理函数
            response = wechat_handler.handle_wechat_message(xml_data)
            logger.info(f"返回响应: {response}")
            
            # 直接返回XML响应
            return response
        except Exception as e:
            logger.error(f"处理用户消息异常: {e}")
            return "处理用户消息异常"

# 应用入口
if __name__ == "__main__":
    # 处理命令行参数，支持指定端口
    args = sys.argv
    port_to_listen = 8080  # 默认端口
    
    # 检查是否提供了端口参数
    if len(args) > 1:
        try:
            port_to_listen = int(args[1])
            logger.info(f"使用指定端口: {port_to_listen}")
        except ValueError:
            logger.warning(f"无效的端口参数: {args[1]}，使用默认端口: {port_to_listen}")
    
    # 清除命令行参数，确保web.py正确处理
    sys.argv = [args[0]]
    
    # web.py 0.62版本的端口指定方式
    # 让web.py使用我们指定的端口
    sys.argv.append(str(port_to_listen))
    
    # 创建应用实例并运行
    logger.info(f"启动微信电影推荐系统服务，监听端口: {port_to_listen}")
    try:
        app = web.application(urls, globals())
        app.run()
    except Exception as e:
        logger.error(f"应用启动失败: {e}")
        sys.exit(1) 