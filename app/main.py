# 基于协同过滤算法的电影推荐系统研究与实现
# 作者：刘鑫凯 (毕业设计作品)
# Mindsnap团队的电影推荐系统分团队 
# 主应用入口文件：定义Web路由、初始化应用，处理微信服务器的请求

############################################################
# 导入必要的库
############################################################
import web  # web.py框架，提供Web服务器和路由功能
import sys  # 系统模块，用于访问命令行参数和Python路径
import os   # 操作系统接口，用于文件路径操作
import logging  # 日志模块，记录系统运行信息

############################################################
# 设置Python导入路径，确保可以正确导入项目模块
############################################################
# 获取项目根目录的绝对路径（当前文件的上级目录）
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 将项目根目录添加到Python模块搜索路径，使import语句能找到项目模块
sys.path.insert(0, project_root)

############################################################
# 导入项目内部模块
############################################################
from app import wechat_handler  # 导入微信消息处理模块
from app.config import WECHAT_TOKEN  # 导入微信Token配置

############################################################
# 配置日志系统
############################################################
# 设置日志级别为INFO，指定日志格式包含时间、级别和消息
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
# 创建一个日志记录器，名称与当前模块一致
logger = logging.getLogger(__name__)

############################################################
# 定义URL路由
############################################################
# 将根路径'/'映射到WeChatInterface类，用于处理所有微信服务器的请求
urls = ('/', 'WeChatInterface')

############################################################
# 微信接口处理类定义
############################################################
class WeChatInterface:
    """
    微信公众号接口类
    
    负责处理来自微信服务器的GET请求（验证）和POST请求（接收用户消息）
    GET请求：验证服务器有效性，微信服务器会发送签名、时间戳等参数进行验证
    POST请求：接收用户发送的消息，以XML格式传递
    """
    
    def GET(self):
        """
        处理微信服务器的GET请求（验证服务器有效性）
        
        微信服务器会发送以下参数：
        signature: 微信加密签名，由token、timestamp、nonce通过算法计算得出
        timestamp: 时间戳，用于防止请求被重放
        nonce: 随机数，用于增加签名的随机性
        echostr: 随机字符串，验证通过后原样返回给微信服务器
        
        验证通过后返回echostr，表示验证成功
        此方法仅在配置微信公众号服务器URL时被调用
        """
        try:
            # 使用web.input()获取URL中的查询参数
            params = web.input()
            signature = params.signature  # 微信加密签名
            timestamp = params.timestamp  # 时间戳
            nonce = params.nonce          # 随机数
            echostr = params.echostr      # 随机字符串
            
            # 记录收到的验证请求参数
            logger.info(f"收到验证请求: signature={signature}, timestamp={timestamp}, nonce={nonce}")
            
            # 调用wechat_handler模块的check_signature函数验证签名
            if wechat_handler.check_signature(signature, timestamp, nonce, WECHAT_TOKEN):
                logger.info("验证成功")
                return echostr  # 验证成功，返回echostr给微信服务器
            else:
                logger.warning("验证失败")
                return "验证失败"  # 验证失败，返回错误信息
        except Exception as e:
            # 捕获处理过程中的任何异常，记录错误日志
            logger.error(f"验证请求处理异常: {e}")
            return "请求处理异常"
    
    def POST(self):
        """
        处理微信服务器的POST请求（用户发送消息）
        
        当用户向公众号发送消息时，微信服务器会将消息以XML格式通过POST请求转发到这里
        主要处理流程：
        1. 接收XML格式的消息
        2. 调用wechat_handler模块处理消息
        3. 返回响应消息给微信服务器，再由微信服务器转发给用户
        
        返回的消息也必须是XML格式，包含ToUserName、FromUserName等必要字段
        """
        try:
            # 获取POST请求体中的原始数据（XML格式）
            xml_data = web.data()  # web.data()返回请求体的原始字节数据
            # 记录收到的用户消息，转换为UTF-8字符串便于日志显示
            logger.info(f"收到用户消息: {xml_data.decode('utf-8')}")
            
            # 调用wechat_handler模块的handle_wechat_message函数处理消息
            # 该函数负责解析XML、执行相应业务逻辑、生成响应XML
            response = wechat_handler.handle_wechat_message(xml_data)
            logger.info(f"返回响应: {response}")
            
            # 直接返回XML响应给微信服务器
            return response
        except Exception as e:
            # 捕获处理过程中的任何异常，记录错误日志
            logger.error(f"处理用户消息异常: {e}")
            return "处理用户消息异常"

############################################################
# 应用入口
############################################################
if __name__ == "__main__":
    """
    应用主入口，当script直接运行时执行
    负责解析命令行参数、创建并启动web.py应用
    """
    # 获取命令行参数，用于支持指定端口号
    args = sys.argv
    port_to_listen = 8080  # 默认监听端口为8080
    
    # 检查命令行是否提供了端口参数
    if len(args) > 1:
        try:
            # 尝试将第一个参数转换为整数作为端口号
            port_to_listen = int(args[1])
            logger.info(f"使用指定端口: {port_to_listen}")
        except ValueError:
            # 如果参数不是有效整数，使用默认端口
            logger.warning(f"无效的端口参数: {args[1]}，使用默认端口: {port_to_listen}")
    
    # 清除命令行参数，保留脚本名称
    # 这是因为web.py会自行解析sys.argv，不清除可能导致参数解析错误
    sys.argv = [args[0]]
    
    # 添加端口参数到sys.argv
    # web.py 0.62版本通过命令行参数形式指定端口
    sys.argv.append(str(port_to_listen))
    
    # 创建并启动web.py应用
    logger.info(f"启动微信电影推荐系统服务，监听端口: {port_to_listen}")
    try:
        # 创建web.py应用实例，传入URL路由和全局命名空间
        app = web.application(urls, globals())
        # 启动应用，开始监听请求
        app.run()
    except Exception as e:
        # 捕获应用启动过程中的异常，记录错误并退出
        logger.error(f"应用启动失败: {e}")
        sys.exit(1)  # 非零退出码表示异常终止 