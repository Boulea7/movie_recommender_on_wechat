# 基于协同过滤算法的电影推荐系统研究与实现
# 作者：刘鑫凯 (毕业设计作品)
# Mindsnap团队的电影推荐系统分团队
# 数据库管理模块：提供数据库连接和所有数据操作功能

############################################################
# 导入必要的库
############################################################
import pymysql  # MySQL数据库连接库
import logging  # 日志库，用于记录系统运行信息
from app.config import DB_CONFIG  # 导入数据库配置信息

############################################################
# 配置日志系统
############################################################
# 设置日志级别为INFO，格式包含时间、级别和消息
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)  # 创建当前模块的日志记录器

############################################################
# 数据库连接管理
############################################################
def get_db_connection():
    """
    创建并返回MySQL数据库连接对象
    
    根据config.py中的DB_CONFIG配置信息建立与MySQL数据库的连接
    处理特殊情况：如果cursorclass是字符串形式，需要转换为实际的类
    
    Returns:
        pymysql.connections.Connection: 数据库连接对象
        
    Raises:
        Exception: 数据库连接失败时抛出异常
    """
    max_retries = 3
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            # 复制配置信息，避免修改原始配置
            config = DB_CONFIG.copy()
            
            # 处理DictCursor的情况，它是字符串而不是直接的类
            if 'cursorclass' in config and isinstance(config['cursorclass'], str):
                # 如果cursorclass是字符串形式，需要导入实际的类
                if config['cursorclass'] == 'pymysql.cursors.DictCursor':
                    config['cursorclass'] = pymysql.cursors.DictCursor
            
            # 添加连接超时和自动重连配置
            config.update({
                'connect_timeout': 10,  # 连接超时10秒
                'read_timeout': 30,     # 读取超时30秒
                'write_timeout': 30,    # 写入超时30秒
                'autocommit': False,    # 禁用自动提交，手动控制事务
                'ping': True           # 启用连接保活
            })
            
            # 使用配置信息创建数据库连接
            conn = pymysql.connect(**config)
            
            # 测试连接是否正常
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
            
            logger.info("数据库连接成功")
            return conn
            
        except pymysql.Error as e:
            retry_count += 1
            logger.warning(f"数据库连接失败 (尝试 {retry_count}/{max_retries}): {e}")
            
            if retry_count >= max_retries:
                logger.error(f"数据库连接失败，已达到最大重试次数: {e}")
                raise
            
            # 等待一段时间后重试
            import time
            time.sleep(1)
            
        except Exception as e:
            # 记录连接错误信息并向上抛出异常
            logger.error(f"数据库连接失败: {e}")
            raise

############################################################
# 用户相关函数
############################################################
def get_user_by_openid(openid):
    """
    根据微信openid查询用户信息
    
    查询users表中与指定openid匹配的用户记录
    
    Args:
        openid (str): 微信用户的唯一标识OpenID
        
    Returns:
        dict or None: 用户记录字典，包含用户的所有字段信息；如果不存在则返回None
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 执行查询SQL
            sql = "SELECT * FROM users WHERE openid = %s"
            cursor.execute(sql, (openid,))
            # 获取查询结果
            result = cursor.fetchone()
        # 关闭数据库连接
        conn.close()
        return result
    except Exception as e:
        # 记录错误信息
        logger.error(f"查询用户失败 (openid: {openid}): {e}")
        return None

def create_user(openid, nickname=None):
    """
    创建新用户
    
    当用户首次使用系统时，在users表中创建用户记录
    
    Args:
        openid (str): 微信用户的唯一标识OpenID
        nickname (str, optional): 用户昵称，可选参数
        
    Returns:
        int: 新创建的用户ID
        
    Raises:
        Exception: 创建用户失败时抛出异常
    """
    conn = None
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 执行插入SQL
            sql = "INSERT INTO users (openid, nickname) VALUES (%s, %s)"
            cursor.execute(sql, (openid, nickname))
        # 提交事务
        conn.commit()
        # 获取刚插入的用户ID
        user_id = cursor.lastrowid
        # 关闭数据库连接
        conn.close()
        # 记录成功信息
        logger.info(f"创建新用户成功 (ID: {user_id}, openid: {openid})")
        return user_id
    except Exception as e:
        # 记录错误信息
        logger.error(f"创建用户失败 (openid: {openid}): {e}")
        # 确保数据库连接被关闭
        if conn:
            conn.close()
        raise

def get_user_id_by_openid(openid):
    """
    根据openid获取用户ID，如果用户不存在则先创建
    
    这是一个便捷函数，用于获取或创建用户ID，是大多数功能的前置操作
    
    Args:
        openid (str): 微信用户的唯一标识OpenID
        
    Returns:
        int: 用户ID
    """
    # 先尝试查找用户
    user = get_user_by_openid(openid)
    if user:
        # 用户存在，返回ID
        return user['id']
    else:
        # 用户不存在，创建新用户并返回ID
        return create_user(openid)

############################################################
# 电影相关函数
############################################################
def get_movie_by_id(movie_id):
    """
    根据电影ID查询电影详细信息
    
    从movies表中获取指定ID的电影完整信息
    
    Args:
        movie_id (int): 电影ID
        
    Returns:
        dict or None: 电影记录字典，包含电影的所有字段信息；如果不存在则返回None
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 执行查询SQL
            sql = "SELECT * FROM movies WHERE id = %s"
            cursor.execute(sql, (movie_id,))
            # 获取查询结果
            result = cursor.fetchone()
        # 关闭数据库连接
        conn.close()
        return result
    except Exception as e:
        # 记录错误信息
        logger.error(f"查询电影失败 (ID: {movie_id}): {e}")
        return None

def search_movies_by_title_exact(title):
    """
    精确匹配电影标题
    
    查找与输入标题完全一致的电影
    
    Args:
        title (str): 电影标题
        
    Returns:
        list: 匹配的电影记录列表，可能包含多个同名电影
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 执行精确匹配查询SQL
            sql = "SELECT * FROM movies WHERE title = %s"
            cursor.execute(sql, (title,))
            # 获取所有匹配结果
            result = cursor.fetchall()
        # 关闭数据库连接
        conn.close()
        return result
    except Exception as e:
        # 记录错误信息
        logger.error(f"精确搜索电影失败 (title: {title}): {e}")
        return []

def search_movies_by_title_fuzzy(title, limit=5):
    """
    模糊匹配电影标题
    
    使用SQL的LIKE操作符查找标题包含关键词的电影
    结果按照豆瓣评分降序排序，并限制数量
    
    Args:
        title (str): 电影标题关键词
        limit (int, optional): 返回结果数量限制，默认为5
        
    Returns:
        list: 匹配的电影记录列表
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 执行模糊匹配查询SQL，按豆瓣评分排序
            sql = "SELECT * FROM movies WHERE title LIKE %s ORDER BY douban_rating DESC LIMIT %s"
            cursor.execute(sql, (f'%{title}%', limit))
            # 获取所有匹配结果
            result = cursor.fetchall()
        # 关闭数据库连接
        conn.close()
        return result
    except Exception as e:
        # 记录错误信息
        logger.error(f"模糊搜索电影失败 (title: {title}): {e}")
        return []

def get_movie_details_for_display(movie_records, max_movies_to_display=3, max_total_chars=580):
    """
    将从数据库获取的电影记录列表格式化为易于微信显示的文本。

    Args:
        movie_records (dict or list): 电影记录列表或单个电影记录。
        max_movies_to_display (int): 最多显示几部电影的信息。
        max_total_chars (int): 整个消息内容的最大字符数（中文及符号）。

    Returns:
        str: 格式化后的文本字符串，多个电影记录用空行分隔。
             如果内容超长，会尝试截断并在末尾提示。
    """
    if not movie_records:
        return "未找到相关电影"

    if isinstance(movie_records, dict):
        movie_records = [movie_records]

    result_texts = []
    current_total_chars = 0
    movies_displayed_count = 0
    
    # 单个电影简介的最大长度
    PLOT_SUMMARY_MAX_LENGTH = 60 

    for movie in movie_records:
        if movies_displayed_count >= max_movies_to_display:
            break

        # 格式化单部电影信息
        plot_summary = movie.get('plot_summary', '')
        if len(plot_summary) > PLOT_SUMMARY_MAX_LENGTH:
            plot_summary = plot_summary[:PLOT_SUMMARY_MAX_LENGTH] + "..."
        else:
            # 确保即使不截断也有 ... (如果原本就没有简介，则是空字符串)
            if plot_summary and len(plot_summary) == movie.get('plot_summary', '').__len__(): # 确保是真的完整简介
                 pass # 不需要加...
            elif plot_summary: # 有简介但被配置截断了
                 plot_summary = plot_summary + "..."


        movie_text_parts = [
            f"《{movie.get('title', '未知电影')}》",
            f"评分: {movie.get('douban_rating', 'N/A')} ({movie.get('rating_count', 0)}人评价)",
            f"年代: {movie.get('release_date', '未知')}",
            f"类型: {movie.get('genres', '未知')}",
            # f"导演: {movie.get('directors', '未知')}", # 导演和主演信息较长，优先省略
            # f"主演: {movie.get('actors', '未知')}",
            f"简介: {plot_summary}"
        ]
        movie_text = "\n".join(movie_text_parts)

        # 检查加入这部电影后是否会超长
        # 预估长度时，考虑分隔符 "\n\n" 的长度
        separator_len = len("\n\n") if result_texts else 0
        if current_total_chars + len(movie_text) + separator_len > max_total_chars:
            if not result_texts: # 如果第一部电影就超长了，尝试极简模式
                simple_plot_summary = movie.get('plot_summary', '')
                if len(simple_plot_summary) > 20: # 进一步缩短简介
                    simple_plot_summary = simple_plot_summary[:20] + "..."
                
                shorter_movie_text = (
                    f"《{movie.get('title', '未知电影')}>\n"
                    f"评分: {movie.get('douban_rating', 'N/A')}\n"
                    f"简介: {simple_plot_summary}"
                )
                if len(shorter_movie_text) <= max_total_chars :
                    result_texts.append(shorter_movie_text)
                    current_total_chars += len(shorter_movie_text)
                    movies_displayed_count +=1
            # 无论如何，不能再加更多电影了
            if movies_displayed_count < len(movie_records) and movies_displayed_count < max_movies_to_display :
                 result_texts.append("...") # 暗示还有更多内容，但已达长度上限
                 current_total_chars += len("...")
            break 
            

        result_texts.append(movie_text)
        current_total_chars += len(movie_text) + separator_len
        movies_displayed_count += 1
        
    if not result_texts: # 如果处理后没有任何内容（例如第一条就因极简模式也超长而被跳过）
        return "电影信息过长，无法完整显示。请尝试更精确的搜索或查看单个电影详情。"


    final_output = "\n\n".join(result_texts)
    
    # 最后再检查一次总长度，以防万一
    if len(final_output) > max_total_chars:
        #  如果还是超长，可能需要更强的截断，但目前逻辑应该能避免大部分情况
        #  这里简单返回一个通用提示，或者可以尝试只返回第一条的极简信息
        logger.warning(f"格式化后的电影信息仍然超长({len(final_output)} > {max_total_chars})，可能显示不全。原始电影数: {len(movie_records)}")
        # 尝试返回截断到max_total_chars的内容
        # 确保不会切断一个多字节字符的中间
        truncated_output = []
        current_len = 0
        for char_ in final_output:
            # 简单假设中文字符占位较多，UTF-8可能1-4字节，这里用len计算的是字符数
            # Python字符串长度是字符数，不是字节数。微信限制是字节。
            # 这里的max_total_chars应该理解为字符数上限的一个估计。
            if current_len + len(char_.encode('utf-8')) > max_total_chars * 0.9: # 留一些buffer
                truncated_output.append("...")
                break
            truncated_output.append(char_)
            current_len += len(char_.encode('utf-8'))
        return "".join(truncated_output)


    return final_output

############################################################
# 评分相关函数
############################################################
def add_or_update_rating(user_id, movie_id, score):
    """
    添加或更新用户对电影的评分
    
    如果用户之前已对该电影评分，则更新评分；否则添加新评分
    
    Args:
        user_id (int): 用户ID
        movie_id (int): 电影ID
        score (float): 评分 (0-10)
        
    Returns:
        bool: 成功返回True，失败返回False
    """
    conn = None
    try:
        # 验证评分范围并自动调整
        score = float(score)
        if score < 0:
            score = 0
        elif score > 10:
            score = 10
        
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 检查评分是否已存在
            check_sql = "SELECT id FROM ratings WHERE user_id = %s AND movie_id = %s"
            cursor.execute(check_sql, (user_id, movie_id))
            existing_rating = cursor.fetchone()
            
            if existing_rating:
                # 更新已有评分
                update_sql = "UPDATE ratings SET score = %s, rated_at = NOW() WHERE user_id = %s AND movie_id = %s"
                cursor.execute(update_sql, (score, user_id, movie_id))
                logger.info(f"更新评分 (用户ID: {user_id}, 电影ID: {movie_id}, 评分: {score})")
            else:
                # 添加新评分
                insert_sql = "INSERT INTO ratings (user_id, movie_id, score) VALUES (%s, %s, %s)"
                cursor.execute(insert_sql, (user_id, movie_id, score))
                logger.info(f"添加评分 (用户ID: {user_id}, 电影ID: {movie_id}, 评分: {score})")
        
        # 提交事务
        conn.commit()
        # 关闭数据库连接
        conn.close()
        return True
    except Exception as e:
        # 记录错误信息
        logger.error(f"评分失败 (用户ID: {user_id}, 电影ID: {movie_id}): {e}")
        # 确保数据库连接被关闭
        if conn:
            conn.close()
        return False

def get_user_ratings(user_id):
    """
    获取特定用户的所有评分记录
    
    查询用户对所有电影的评分，用于生成个性化推荐
    
    Args:
        user_id (int): 用户ID
        
    Returns:
        list: 评分记录列表，每条记录包含movie_id和score字段
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 执行查询SQL
            sql = "SELECT movie_id, score FROM ratings WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            # 获取所有评分记录
            result = cursor.fetchall()
        # 关闭数据库连接
        conn.close()
        return result
    except Exception as e:
        # 记录错误信息
        logger.error(f"获取用户评分失败 (用户ID: {user_id}): {e}")
        return []

def get_all_user_ratings():
    """
    获取所有用户的评分数据，用于协同过滤算法
    
    查询整个系统中的所有评分记录，并按用户ID组织
    这是协同过滤算法的重要输入数据
    
    Returns:
        dict: 按用户ID组织的评分数据
              格式: {user_id1: [{'movie_id': X, 'score': Y}, ...], user_id2: [...], ...}
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 查询所有评分记录
            sql = "SELECT user_id, movie_id, score FROM ratings"
            cursor.execute(sql)
            all_ratings = cursor.fetchall()
        # 关闭数据库连接
        conn.close()
        
        # 按用户ID组织数据
        # 构建字典：{用户ID: [{电影ID, 评分}, ...], ...}
        result = {}
        for rating in all_ratings:
            user_id = rating['user_id']
            # 如果用户ID不在结果字典中，初始化空列表
            if user_id not in result:
                result[user_id] = []
            # 添加评分记录到对应用户的列表中
            result[user_id].append({
                'movie_id': rating['movie_id'],
                'score': rating['score']
            })
        return result
    except Exception as e:
        # 记录错误信息
        logger.error(f"获取所有评分数据失败: {e}")
        return {}

def get_movies_rated_by_user(user_id):
    """
    获取用户已评分的电影ID列表
    
    用于推荐时排除用户已经看过的电影
    
    Args:
        user_id (int): 用户ID
        
    Returns:
        list: 用户已评分的电影ID列表
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 查询用户已评分的电影ID
            sql = "SELECT movie_id FROM ratings WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            results = cursor.fetchall()
        # 关闭数据库连接
        conn.close()
        
        # 提取电影ID列表
        movie_ids = [row['movie_id'] for row in results]
        return movie_ids
    except Exception as e:
        # 记录错误信息
        logger.error(f"获取用户已评分电影失败 (用户ID: {user_id}): {e}")
        return []

############################################################
# 推荐辅助函数
############################################################
def get_movies_for_content_based_recommendation(exclude_movie_ids=None, limit=100):
    """
    获取一批用于内容推荐的电影（高评分电影，排除用户已看过的）
    
    用于基于内容的推荐和冷启动推荐
    
    Args:
        exclude_movie_ids (list, optional): 需要排除的电影ID列表（如用户已评分的电影）
        limit (int, optional): 返回结果数量限制，默认100
        
    Returns:
        list: 电影记录列表，按豆瓣评分降序排序
    """
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            if exclude_movie_ids and len(exclude_movie_ids) > 0:
                # 排除指定的电影ID
                # 动态生成SQL参数占位符，如 IN (%s, %s, %s)
                placeholders = ', '.join(['%s'] * len(exclude_movie_ids))
                sql = f"SELECT * FROM movies WHERE id NOT IN ({placeholders}) ORDER BY douban_rating DESC LIMIT %s"
                # 参数列表：先是排除的电影ID列表，再加上limit
                params = exclude_movie_ids + [limit]
                cursor.execute(sql, params)
            else:
                # 不需要排除任何电影，直接查询
                sql = "SELECT * FROM movies ORDER BY douban_rating DESC LIMIT %s"
                cursor.execute(sql, (limit,))
            
            # 获取查询结果
            result = cursor.fetchall()
        # 关闭数据库连接
        conn.close()
        return result
    except Exception as e:
        # 记录错误信息
        logger.error(f"获取内容推荐电影失败: {e}")
        return []

############################################################
# 搜索记录相关函数
############################################################
def log_search_query(user_id, search_query):
    """
    记录用户搜索查询（可选功能）
    
    用于后续分析用户行为和改进搜索功能
    
    Args:
        user_id (int): 用户ID
        search_query (str): 搜索关键词
        
    Returns:
        bool: 成功返回True，失败返回False
    """
    conn = None
    try:
        # 获取数据库连接
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # 插入搜索记录
            sql = "INSERT INTO search_logs (user_id, search_query) VALUES (%s, %s)"
            cursor.execute(sql, (user_id, search_query))
        # 提交事务
        conn.commit()
        # 关闭数据库连接
        conn.close()
        return True
    except Exception as e:
        # 记录错误信息
        logger.error(f"记录搜索查询失败 (用户ID: {user_id}, 查询: {search_query}): {e}")
        # 确保数据库连接被关闭
        if conn:
            conn.close()
        return False