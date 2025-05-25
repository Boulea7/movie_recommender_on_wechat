# 基于协同过滤算法的电影推荐系统研究与实现
# 作者：刘鑫凯 (毕业设计作品)
# Mindsnap团队的电影推荐系统分团队
# 微信消息处理模块：负责微信消息解析、处理和响应构建

############################################################
# 导入必要的库
############################################################
import xml.etree.ElementTree as ET  # XML解析库，用于解析微信消息
import time  # 时间处理，用于生成消息时间戳
import hashlib  # 哈希库，用于验证微信签名
import logging  # 日志库，记录系统运行信息
import re  # 正则表达式，用于解析用户评价命令

# 导入配置和其他模块
from .config import WECHAT_TOKEN, MAX_SEARCH_RESULTS, DEFAULT_RECOMMENDATIONS_COUNT  # 导入配置项
from . import db_manager  # 数据库管理模块，提供数据访问接口
from . import recommendation_engine  # 推荐引擎模块，提供电影推荐算法
from .rate_limiter import check_rate_limit  # 速率限制模块

############################################################
# 配置日志系统
############################################################
# 设置日志级别为INFO，格式包含时间、级别和消息
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)  # 创建当前模块的日志记录器

############################################################
# 微信签名验证
############################################################
def check_signature(signature, timestamp, nonce, token=WECHAT_TOKEN):
    """
    微信签名验证函数
    
    微信服务器在发送请求时会附带签名(signature)参数，用于验证请求的合法性
    验证流程：
    1. 将token、timestamp、nonce三个参数按字典序排序
    2. 将三个参数字符串拼接成一个字符串进行SHA1加密
    3. 将加密后的字符串与signature对比，相同则验证通过
    
    Args:
        signature: 微信加密签名
        timestamp: 时间戳
        nonce: 随机数
        token: 令牌（默认从配置文件读取WECHAT_TOKEN）
        
    Returns:
        验证通过返回True，否则返回False
    """
    try:
        # 按字典序排序token、timestamp、nonce
        temp_list = [token, timestamp, nonce]
        temp_list.sort()
        
        # 将三个参数字符串拼接成一个字符串
        temp_str = ''.join(temp_list)
        
        # SHA1加密
        hash_str = hashlib.sha1(temp_str.encode('utf-8')).hexdigest()
        
        # 比较加密后的字符串与signature是否一致
        return hash_str == signature
    except Exception as e:
        logger.error(f"签名验证失败: {e}")
        return False

def parse_xml_message(xml_data):
    """
    解析微信XML消息
    
    Args:
        xml_data: XML格式的消息字符串
        
    Returns:
        解析后的消息字典
    """
    try:
        root = ET.fromstring(xml_data)
        msg_dict = {}
        
        # 遍历XML节点，提取消息内容
        for child in root:
            msg_dict[child.tag] = child.text
        
        return msg_dict
    except Exception as e:
        logger.error(f"XML解析失败: {e}")
        return {}

def build_text_response(to_user, from_user, content):
    """
    构建XML格式的文本回复消息
    
    Args:
        to_user: 接收方（用户OpenID）
        from_user: 发送方（公众号原始ID）
        content: 回复内容
        
    Returns:
        XML格式的回复消息字符串
    """
    response = f"""<xml>
    <ToUserName><![CDATA[{to_user}]]></ToUserName>
    <FromUserName><![CDATA[{from_user}]]></FromUserName>
    <CreateTime>{int(time.time())}</CreateTime>
    <MsgType><![CDATA[text]]></MsgType>
    <Content><![CDATA[{content}]]></Content>
</xml>"""
    return response

def handle_movie_search(from_user_openid, movie_title):
    """
    处理电影搜索
    
    Args:
        from_user_openid: 用户OpenID
        movie_title: 搜索的电影标题
        
    Returns:
        格式化的电影信息字符串
    """
    try:
        # 输入验证
        if not movie_title or not movie_title.strip():
            return "搜索内容不能为空，请输入电影名称。"
        
        # 清理用户输入，去除首尾空格和特殊字符
        cleaned_movie_title = movie_title.strip()
        
        # 长度限制
        if len(cleaned_movie_title) > 100:
            return "搜索关键词过长，请输入正确的电影名称。"
        
        # 过滤恶意输入
        if any(char in cleaned_movie_title for char in ['<', '>', '&', '"', "'"]):
            cleaned_movie_title = cleaned_movie_title.replace('<', '').replace('>', '').replace('&', '').replace('"', '').replace("'", '')
        
        if not cleaned_movie_title:
            return "搜索内容包含无效字符，请重新输入电影名称。"
        
        logger.info(f"开始电影搜索，用户 OpenID: {from_user_openid}, 原始输入: '{movie_title}', 清理后输入: '{cleaned_movie_title}'")

        # 获取用户ID（如不存在则创建）
        user_id = db_manager.get_user_id_by_openid(from_user_openid)
        
        # 记录搜索查询（可选功能）
        db_manager.log_search_query(user_id, cleaned_movie_title)
        
        # 先尝试精确匹配
        movies_exact = db_manager.search_movies_by_title_exact(cleaned_movie_title)
        logger.info(f"精确搜索 '{cleaned_movie_title}' 结果数量: {len(movies_exact) if movies_exact else 0}")
        
        movies_to_display = []
        additional_message = ""

        if movies_exact:
            movies_to_display = movies_exact
            # 如果精确匹配结果多于配置的最大显示数，也只取 MAX_SEARCH_RESULTS
            if len(movies_exact) > MAX_SEARCH_RESULTS:
                movies_to_display = movies_exact[:MAX_SEARCH_RESULTS]
                additional_message = f"\n\n提示：'{cleaned_movie_title}' 精确匹配到多部影片，已显示前{MAX_SEARCH_RESULTS}部。"
        else:
            logger.info(f"精确搜索 '{cleaned_movie_title}' 未找到结果，尝试模糊搜索...")
            movies_fuzzy = db_manager.search_movies_by_title_fuzzy(cleaned_movie_title, limit=MAX_SEARCH_RESULTS * 2) # 稍微多取一点，让get_movie_details_for_display去筛选
            logger.info(f"模糊搜索 '{cleaned_movie_title}' 结果数量: {len(movies_fuzzy) if movies_fuzzy else 0}")
            if movies_fuzzy:
                movies_to_display = movies_fuzzy 
                # 注意：这里的 movies_to_display 可能会多于 MAX_SEARCH_RESULTS，
                # get_movie_details_for_display 内部会根据 max_movies_to_display (即 MAX_SEARCH_RESULTS) 来限制实际显示的电影数量
                if len(movies_fuzzy) > MAX_SEARCH_RESULTS:
                     additional_message = f"\n\n提示：模糊搜索到多个结果，已显示评分较高的前{MAX_SEARCH_RESULTS}部。可尝试更精确的搜索词。"

        if not movies_to_display:
            logger.info(f"电影 '{cleaned_movie_title}' 未找到。")
            return f"抱歉，未找到与'{cleaned_movie_title}'相关的电影。请尝试其他关键词。"
        
        # 获取格式化的电影信息，传递 MAX_SEARCH_RESULTS 作为显示数量上限
        # get_movie_details_for_display 内部会处理总长度和简介长度
        response_message_main = db_manager.get_movie_details_for_display(movies_to_display, max_movies_to_display=MAX_SEARCH_RESULTS)
        
        final_response = response_message_main + additional_message
        
        # 再次检查最终消息长度，以防万一 (虽然 get_movie_details_for_display 已经做了很多工作)
        # 微信文本消息限制大约2048字节，中文字符通常3字节。600字符约1800字节，比较安全。
        MAX_WECHAT_CONTENT_CHARS = 650 
        if len(final_response) > MAX_WECHAT_CONTENT_CHARS:
            logger.warning(f"最终搜索响应消息过长({len(final_response)} > {MAX_WECHAT_CONTENT_CHARS})，将被截断。")
            # 尝试从尾部截断，保留 "..." (如果存在)
            suffix = "..." if final_response.endswith("...") else ""
            if suffix:
                final_response = final_response[:-len(suffix)]
            final_response = final_response[:MAX_WECHAT_CONTENT_CHARS - len(suffix)] + suffix

        logger.info(f"为 '{cleaned_movie_title}' 生成的最终响应消息长度: {len(final_response)}")
        return final_response
    
    except Exception as e:
        logger.error(f"电影搜索失败: {e}")
        return "搜索电影时出现内部错误，请稍后再试。"

def handle_movie_rating(from_user_openid, content):
    """
    处理电影评分
    
    Args:
        from_user_openid: 用户OpenID
        content: 评分消息内容，格式为 "评价 电影名 评分"
        
    Returns:
        评分结果提示字符串
    """
    try:
        # 输入验证
        if not content or not content.strip():
            return "评价内容不能为空。正确格式为：评价 电影名 评分\n例如：评价 肖申克的救赎 9.5"
        
        # 解析评分命令
        # 匹配格式 "评价 电影名 评分"，允许评分为整数或一位小数
        pattern = r'^评价\s+(.+)\s+(\d+(\.\d)?)$'
        match = re.match(pattern, content.strip())
        
        if not match:
            return "评价格式不正确。正确格式为：评价 电影名 评分\n例如：评价 肖申克的救赎 9.5"
        
        movie_name = match.group(1).strip()
        if not movie_name:
            return "电影名不能为空。正确格式为：评价 电影名 评分\n例如：评价 肖申克的救赎 9.5"
        
        # 电影名长度限制
        if len(movie_name) > 100:
            return "电影名过长，请输入正确的电影名称。"
        
        try:
            score = float(match.group(2))
        except (ValueError, TypeError):
            return "评分必须是0-10之间的数字，可以包含一位小数。"
        
        # 评分范围验证和调整
        if score < 0:
            score = 0
            note = "（评分已调整为最小值0）"
        elif score > 10:
            score = 10
            note = "（评分已调整为最大值10）"
        else:
            note = ""
        
        # 获取用户ID
        user_id = db_manager.get_user_id_by_openid(from_user_openid)
        
        # 查找电影
        movies = db_manager.search_movies_by_title_exact(movie_name)
        
        if not movies:
            return f"未找到电影《{movie_name}》，无法评价。"
        
        # 处理同名电影问题（目前简单处理，取第一个）
        movie = movies[0]
        movie_id = movie['id']
        
        # 添加或更新评分
        success = db_manager.add_or_update_rating(user_id, movie_id, score)
        
        if success:
            response = f"《{movie_name}》评分成功！{note}"
            # 如果有多部同名电影，添加提示
            if len(movies) > 1:
                response += f"\n注意：该名称对应多部影片，已默认评价第一部。"
            return response
        else:
            return f"评价《{movie_name}》时出现错误，请稍后再试。"
    
    except ValueError:
        return "评分必须是0-10之间的数字，可以包含一位小数。"
    except Exception as e:
        logger.error(f"处理电影评分失败: {e}")
        return "评价电影时出现错误，请稍后再试。"

def handle_movie_recommendation(from_user_openid):
    """
    处理电影推荐请求
    
    Args:
        from_user_openid: 用户OpenID
        
    Returns:
        推荐结果提示字符串
    """
    try:
        # 获取用户ID
        user_id = db_manager.get_user_id_by_openid(from_user_openid)
        
        # 获取用户评分数量
        user_ratings = db_manager.get_user_ratings(user_id)
        ratings_count = len(user_ratings) if user_ratings else 0
        
        # 如果用户没有任何评分，提示需要先进行评分
        if ratings_count == 0:
            return (
                "您目前还没有评价过任何电影，系统无法生成个性化推荐。\n\n"
                "请先尝试评价一些电影，例如：\n"
                "评价 肖申克的救赎 9.5\n"
                "评价 泰坦尼克号 8.5\n"
                "评价 盗梦空间 9.0"
            )
        
        # 若评分太少，给出提示但仍继续推荐
        recommendation_tip = ""
        if ratings_count < 3:
            recommendation_tip = (
                f"您目前只评价了{ratings_count}部电影，推荐可能不够个性化。"
                "多评价几部电影可以获得更精准的推荐哦！\n\n"
            )
        
        # 调用推荐引擎生成推荐电影ID列表
        movie_ids = recommendation_engine.generate_recommendations(
            user_id, 
            DEFAULT_RECOMMENDATIONS_COUNT # 使用config中定义的推荐数量
        )
        
        # 如果没有推荐结果
        if not movie_ids:
            return (
                "很抱歉，系统暂时无法为您生成推荐。\n\n"
                "这可能是因为：\n"
                "1. 您评价的电影与其他用户重合度不高\n"
                "2. 系统中的电影数据暂时不足\n\n"
                "您可以尝试评价更多热门电影，或稍后再试。"
            )
        
        # 获取推荐电影的详细信息
        movies_info = []
        for movie_id in movie_ids:
            movie = db_manager.get_movie_by_id(movie_id)
            if movie:
                movies_info.append(movie)
        
        # 格式化电影信息
        if movies_info:
            # 构建推荐结果消息
            # 调用更新后的 get_movie_details_for_display，传递推荐数量上限
            recommendations_text = db_manager.get_movie_details_for_display(
                movies_info, 
                max_movies_to_display=DEFAULT_RECOMMENDATIONS_COUNT
            )
            result = f"{recommendation_tip}为您推荐以下电影：\n\n{recommendations_text}"
            
            # 再次检查最终消息长度
            MAX_WECHAT_CONTENT_CHARS = 650 
            if len(result) > MAX_WECHAT_CONTENT_CHARS:
                logger.warning(f"最终推荐响应消息过长({len(result)} > {MAX_WECHAT_CONTENT_CHARS})，将被截断。")
                # 尝试从尾部截断，保留 "..." (如果存在)
                suffix = "..." if result.endswith("...") else ""
                if suffix:
                    result = result[:-len(suffix)]
                result = result[:MAX_WECHAT_CONTENT_CHARS - len(suffix)] + suffix

            logger.info(f"为用户 {from_user_openid} 生成的最终推荐消息长度: {len(result)}")
            return result
        else:
            return "推荐的电影信息获取失败，请稍后再试。"
    
    except Exception as e:
        logger.error(f"电影推荐失败: {e}")
        return "生成电影推荐时出现内部错误，请稍后再试。"

def handle_wechat_message(xml_data):
    """
    处理微信消息主函数
    
    Args:
        xml_data: 接收到的XML格式消息
        
    Returns:
        XML格式的回复消息
    """
    try:
        # 输入验证
        if not xml_data:
            logger.error("接收到空的XML数据")
            return ""
        
        # 解析接收到的XML消息
        msg = parse_xml_message(xml_data)
        if not msg:
            logger.error("无法解析消息内容")
            return ""
        
        # 提取基本信息并验证
        from_user = msg.get('FromUserName')  # 用户OpenID
        to_user = msg.get('ToUserName')      # 公众号原始ID
        msg_type = msg.get('MsgType')        # 消息类型
        
        # 验证必要字段
        if not from_user or not to_user or not msg_type:
            logger.error(f"消息缺少必要字段: FromUserName={from_user}, ToUserName={to_user}, MsgType={msg_type}")
            return ""
        
        # 根据消息类型进行处理
        if msg_type == 'text':
            # 检查速率限制
            allowed, rate_limit_msg = check_rate_limit(from_user)
            if not allowed:
                return build_text_response(from_user, to_user, rate_limit_msg)
            
            # 文本消息，提取内容
            content = msg.get('Content', '').strip()
            
            # 内容长度限制
            if len(content) > 200:
                return build_text_response(from_user, to_user, "消息内容过长，请发送简短的指令。")
            
            # 根据内容判断是什么操作
            # 1. 推荐命令
            if content == "推荐":
                response_content = handle_movie_recommendation(from_user)
            
            # 2. 评价命令
            elif content.startswith("评价 "):
                response_content = handle_movie_rating(from_user, content)
            
            # 3. 默认为电影搜索
            else:
                response_content = handle_movie_search(from_user, content)
            
            # 构建并返回回复消息
            return build_text_response(from_user, to_user, response_content)
        
        elif msg_type == 'event':
            # 事件消息
            event = msg.get('Event')
            
            # 新用户关注
            if event == 'subscribe':
                # 获取用户ID（如不存在则创建）
                db_manager.get_user_id_by_openid(from_user)
                
                # 欢迎语和使用说明
                welcome_msg = (
                    "🎬✨ 欢迎来到刘鑫凯的智能电影推荐世界！✨\n\n"
                    "🎓 这是一个专为电影爱好者打造的AI推荐系统，"
                    "运用先进的协同过滤算法，为您量身定制专属观影清单！\n\n"
                    "🚀 三大核心功能，开启您的观影之旅：\n"
                    "🔍 电影搜索：想看什么直接说！\n"
                    "   例如：「肖申克的救赎」「复仇者联盟」\n"
                    "⭐ 电影评分：分享您的观影感受！\n"
                    "   例如：「评价 泰坦尼克号 9.5」\n"
                    "🎯 智能推荐：发送「推荐」获取专属推荐！\n\n"
                    "💫 温馨提示：评价越多，推荐越精准！\n"
                    "让AI更懂您的电影品味～\n\n"
                    "📖 本系统为刘鑫凯毕业设计作品\n"
                    "《基于协同过滤算法的电影推荐系统研究与实现》"
                )
                return build_text_response(from_user, to_user, welcome_msg)
            
            # 用户取消关注
            elif event == 'unsubscribe':
                # 可选：标记用户不活跃或记录日志
                logger.info(f"用户 {from_user} 取消关注")
                # 微信规定取消关注事件不需要回复
                return ""
            
            # 其他事件
            else:
                return build_text_response(from_user, to_user, "暂不支持此类型的事件")
        
        # 其他类型消息
        else:
            return build_text_response(from_user, to_user, "暂只支持文本消息，请发送文字")
    
    except Exception as e:
        logger.error(f"处理消息失败: {e}")
        return "处理请求失败"