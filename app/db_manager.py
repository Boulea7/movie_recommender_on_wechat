# Mindsnap团队的电影推荐系统分团队

import pymysql
import logging
from app.config import DB_CONFIG

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_db_connection():
    """
    创建并返回MySQL数据库连接对象
    """
    try:
        # 处理DictCursor的情况，它是字符串而不是直接的类
        config = DB_CONFIG.copy()
        if 'cursorclass' in config and isinstance(config['cursorclass'], str):
            # 如果cursorclass是字符串形式，需要导入实际的类
            if config['cursorclass'] == 'pymysql.cursors.DictCursor':
                config['cursorclass'] = pymysql.cursors.DictCursor
        
        conn = pymysql.connect(**config)
        return conn
    except Exception as e:
        logger.error(f"数据库连接失败: {e}")
        raise

# 用户相关函数
def get_user_by_openid(openid):
    """
    根据openid查询用户信息
    
    Args:
        openid: 微信用户openid
        
    Returns:
        用户记录字典，不存在则返回None
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT * FROM users WHERE openid = %s"
            cursor.execute(sql, (openid,))
            result = cursor.fetchone()
        conn.close()
        return result
    except Exception as e:
        logger.error(f"查询用户失败 (openid: {openid}): {e}")
        return None

def create_user(openid, nickname=None):
    """
    创建新用户
    
    Args:
        openid: 微信用户openid
        nickname: 用户昵称，可选
        
    Returns:
        新创建的用户ID
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "INSERT INTO users (openid, nickname) VALUES (%s, %s)"
            cursor.execute(sql, (openid, nickname))
        conn.commit()
        # 获取刚插入的用户ID
        user_id = cursor.lastrowid
        conn.close()
        logger.info(f"创建新用户成功 (ID: {user_id}, openid: {openid})")
        return user_id
    except Exception as e:
        logger.error(f"创建用户失败 (openid: {openid}): {e}")
        if conn:
            conn.close()
        raise

def get_user_id_by_openid(openid):
    """
    根据openid获取用户ID，如果用户不存在则先创建
    
    Args:
        openid: 微信用户openid
        
    Returns:
        用户ID
    """
    user = get_user_by_openid(openid)
    if user:
        return user['id']
    else:
        # 用户不存在，创建新用户
        return create_user(openid)

# 电影相关函数
def get_movie_by_id(movie_id):
    """
    根据电影ID查询电影详细信息
    
    Args:
        movie_id: 电影ID
        
    Returns:
        电影记录字典，不存在则返回None
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT * FROM movies WHERE id = %s"
            cursor.execute(sql, (movie_id,))
            result = cursor.fetchone()
        conn.close()
        return result
    except Exception as e:
        logger.error(f"查询电影失败 (ID: {movie_id}): {e}")
        return None

def search_movies_by_title_exact(title):
    """
    精确匹配电影标题
    
    Args:
        title: 电影标题
        
    Returns:
        匹配的电影记录列表
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT * FROM movies WHERE title = %s"
            cursor.execute(sql, (title,))
            result = cursor.fetchall()
        conn.close()
        return result
    except Exception as e:
        logger.error(f"精确搜索电影失败 (title: {title}): {e}")
        return []

def search_movies_by_title_fuzzy(title, limit=5):
    """
    模糊匹配电影标题
    
    Args:
        title: 电影标题关键词
        limit: 返回结果数量限制
        
    Returns:
        匹配的电影记录列表
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT * FROM movies WHERE title LIKE %s ORDER BY douban_rating DESC LIMIT %s"
            cursor.execute(sql, (f'%{title}%', limit))
            result = cursor.fetchall()
        conn.close()
        return result
    except Exception as e:
        logger.error(f"模糊搜索电影失败 (title: {title}): {e}")
        return []

def get_movie_details_for_display(movie_records):
    """
    将从数据库获取的电影记录列表格式化为易于微信显示的文本
    
    Args:
        movie_records: 电影记录列表或单个电影记录
        
    Returns:
        格式化后的文本字符串
    """
    if not movie_records:
        return "未找到相关电影"
    
    # 如果是单个电影记录（字典），转换为列表处理
    if isinstance(movie_records, dict):
        movie_records = [movie_records]
    
    result_texts = []
    for movie in movie_records:
        movie_text = (
            f"《{movie['title']}》\n"
            f"评分: {movie['douban_rating']} ({movie['rating_count']}人评价)\n"
            f"年代: {movie['release_date']}\n"
            f"类型: {movie['genres']}\n"
            f"导演: {movie['directors']}\n"
            f"主演: {movie['actors']}\n"
            f"简介: {movie['plot_summary'][:100]}...\n"
        )
        result_texts.append(movie_text)
    
    return "\n\n".join(result_texts)

# 评分相关函数
def add_or_update_rating(user_id, movie_id, score):
    """
    添加或更新用户对电影的评分
    
    Args:
        user_id: 用户ID
        movie_id: 电影ID
        score: 评分 (0-10)
        
    Returns:
        成功返回True，失败返回False
    """
    try:
        # 验证评分范围
        score = float(score)
        if score < 0:
            score = 0
        elif score > 10:
            score = 10
        
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
        
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        logger.error(f"评分失败 (用户ID: {user_id}, 电影ID: {movie_id}): {e}")
        if conn:
            conn.close()
        return False

def get_user_ratings(user_id):
    """
    获取特定用户的所有评分记录
    
    Args:
        user_id: 用户ID
        
    Returns:
        评分记录列表 [{'movie_id': X, 'score': Y}, ...]
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT movie_id, score FROM ratings WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            result = cursor.fetchall()
        conn.close()
        return result
    except Exception as e:
        logger.error(f"获取用户评分失败 (用户ID: {user_id}): {e}")
        return []

def get_all_user_ratings():
    """
    获取所有用户的评分数据，用于协同过滤
    
    Returns:
        字典 {user_id1: [{'movie_id': X, 'score': Y}, ...], user_id2: [...], ...}
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT user_id, movie_id, score FROM ratings"
            cursor.execute(sql)
            all_ratings = cursor.fetchall()
        conn.close()
        
        # 按用户ID组织数据
        result = {}
        for rating in all_ratings:
            user_id = rating['user_id']
            if user_id not in result:
                result[user_id] = []
            result[user_id].append({
                'movie_id': rating['movie_id'],
                'score': rating['score']
            })
        return result
    except Exception as e:
        logger.error(f"获取所有评分数据失败: {e}")
        return {}

def get_movies_rated_by_user(user_id):
    """
    获取用户已评分的电影ID列表
    
    Args:
        user_id: 用户ID
        
    Returns:
        电影ID列表
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT movie_id FROM ratings WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            results = cursor.fetchall()
        conn.close()
        
        # 提取电影ID列表
        movie_ids = [row['movie_id'] for row in results]
        return movie_ids
    except Exception as e:
        logger.error(f"获取用户已评分电影失败 (用户ID: {user_id}): {e}")
        return []

# 推荐辅助函数
def get_movies_for_content_based_recommendation(exclude_movie_ids=None, limit=100):
    """
    获取一批用于内容推荐的电影（高评分电影，排除用户已看过的）
    
    Args:
        exclude_movie_ids: 需要排除的电影ID列表（如用户已评分的电影）
        limit: 返回结果数量限制
        
    Returns:
        电影记录列表
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            if exclude_movie_ids and len(exclude_movie_ids) > 0:
                # 排除指定的电影ID
                placeholders = ', '.join(['%s'] * len(exclude_movie_ids))
                sql = f"SELECT * FROM movies WHERE id NOT IN ({placeholders}) ORDER BY douban_rating DESC LIMIT %s"
                params = exclude_movie_ids + [limit]
                cursor.execute(sql, params)
            else:
                # 不需要排除任何电影
                sql = "SELECT * FROM movies ORDER BY douban_rating DESC LIMIT %s"
                cursor.execute(sql, (limit,))
            
            result = cursor.fetchall()
        conn.close()
        return result
    except Exception as e:
        logger.error(f"获取内容推荐电影失败: {e}")
        return []

def log_search_query(user_id, search_query):
    """
    记录用户搜索查询（可选功能）
    
    Args:
        user_id: 用户ID
        search_query: 搜索关键词
        
    Returns:
        成功返回True，失败返回False
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "INSERT INTO search_logs (user_id, search_query) VALUES (%s, %s)"
            cursor.execute(sql, (user_id, search_query))
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        logger.error(f"记录搜索查询失败 (用户ID: {user_id}, 查询: {search_query}): {e}")
        if conn:
            conn.close()
        return False