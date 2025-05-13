# Mindsnap团队的电影推荐系统分团队

import xml.etree.ElementTree as ET
import time
import hashlib
import logging
import re
from app.config import WECHAT_TOKEN, MAX_SEARCH_RESULTS, DEFAULT_RECOMMENDATIONS_COUNT
from app import db_manager
from app import recommendation_engine

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_signature(signature, timestamp, nonce, token=WECHAT_TOKEN):
    """
    微信签名验证函数
    
    Args:
        signature: 微信加密签名
        timestamp: 时间戳
        nonce: 随机数
        token: 令牌（默认从配置文件读取）
        
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
        # 获取用户ID（如不存在则创建）
        user_id = db_manager.get_user_id_by_openid(from_user_openid)
        
        # 记录搜索查询（可选功能）
        db_manager.log_search_query(user_id, movie_title)
        
        # 先尝试精确匹配
        movies = db_manager.search_movies_by_title_exact(movie_title)
        
        # 如果精确匹配无结果，尝试模糊匹配
        if not movies:
            movies = db_manager.search_movies_by_title_fuzzy(movie_title, MAX_SEARCH_RESULTS)
        
        # 如果仍无结果，返回提示信息
        if not movies:
            return f"抱歉，未找到与"{movie_title}"相关的电影。"
        
        # 获取格式化的电影信息
        return db_manager.get_movie_details_for_display(movies)
    
    except Exception as e:
        logger.error(f"电影搜索失败: {e}")
        return "搜索电影时出现错误，请稍后再试。"

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
        # 解析评分命令
        # 匹配格式 "评价 电影名 评分"，允许评分为整数或一位小数
        pattern = r'^评价\s+(.+)\s+(\d+(\.\d)?)$'
        match = re.match(pattern, content)
        
        if not match:
            return "评价格式不正确。正确格式为：评价 电影名 评分\n例如：评价 肖申克的救赎 9.5"
        
        movie_name = match.group(1).strip()
        score = float(match.group(2))
        
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
            DEFAULT_RECOMMENDATIONS_COUNT
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
            result = f"{recommendation_tip}为您推荐以下电影：\n\n"
            result += db_manager.get_movie_details_for_display(movies_info)
            return result
        else:
            return "推荐电影获取失败，请稍后再试。"
    
    except Exception as e:
        logger.error(f"电影推荐失败: {e}")
        return "生成电影推荐时出现错误，请稍后再试。"

def handle_wechat_message(xml_data):
    """
    处理微信消息主函数
    
    Args:
        xml_data: 接收到的XML格式消息
        
    Returns:
        XML格式的回复消息
    """
    try:
        # 解析接收到的XML消息
        msg = parse_xml_message(xml_data)
        if not msg:
            logger.error("无法解析消息内容")
            return "无法解析请求"
        
        # 提取基本信息
        from_user = msg.get('FromUserName')  # 用户OpenID
        to_user = msg.get('ToUserName')      # 公众号原始ID
        msg_type = msg.get('MsgType')        # 消息类型
        
        # 根据消息类型进行处理
        if msg_type == 'text':
            # 文本消息，提取内容
            content = msg.get('Content', '').strip()
            
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
                    "欢迎使用个性化电影推荐！\n\n"
                    "您可以：\n"
                    "1. 输入电影名搜索，如：泰坦尼克号\n"
                    "2. 评价电影，如：评价 泰坦尼克号 9\n"
                    "3. 获取推荐，输入：推荐"
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