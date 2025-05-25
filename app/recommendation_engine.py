# 基于协同过滤算法的电影推荐系统研究与实现
# 作者：刘鑫凯 (毕业设计作品)
# Mindsnap团队的电影推荐系统分团队 
# 推荐引擎模块：实现电影推荐算法，包括协同过滤和基于内容的推荐

############################################################
# 导入必要的库
############################################################
import logging  # 日志库，用于记录算法执行情况
import random   # 随机库，用于增加推荐结果多样性
import math     # 数学库，用于各种数学计算
from app import db_manager  # 数据库管理模块，提供数据访问功能
from app.config import SIMILAR_USERS_COUNT, MIN_COMMON_RATINGS  # 推荐算法配置参数

############################################################
# 配置日志系统
############################################################
# 设置日志级别为INFO，格式包含时间、级别和消息
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)  # 创建当前模块的日志记录器

############################################################
# 基于用户的协同过滤推荐算法
############################################################
def get_user_cf_recommendations(target_user_id, num_recommendations=5):
    """
    基于用户的协同过滤推荐算法 (User-CF)
    
    算法核心思想：
    1. 找到与目标用户有相似偏好的用户（邻居用户）
    2. 推荐这些相似用户喜欢但目标用户尚未看过的电影
    
    Args:
        target_user_id (int): 目标用户ID，即要给谁推荐
        num_recommendations (int): 推荐电影数量
        
    Returns:
        list: 推荐电影ID列表，按预测评分从高到低排序
    """
    try:
        logger.info(f"为用户 {target_user_id} 生成协同过滤推荐")
        
        # 步骤1: 获取目标用户的评分记录
        # 返回格式: [{'movie_id': 电影ID, 'score': 评分}, ...]
        target_user_ratings = db_manager.get_user_ratings(target_user_id)
        
        # 如果用户没有任何评分记录，无法使用协同过滤
        if not target_user_ratings:
            logger.info(f"用户 {target_user_id} 没有评分记录，无法使用协同过滤")
            return []
        
        # 将目标用户评分转换为字典形式 {movie_id: score}，便于后续O(1)时间复杂度查找
        target_user_ratings_dict = {rating['movie_id']: rating['score'] for rating in target_user_ratings}
        
        # 步骤2: 获取所有用户的评分记录
        # 返回格式: {user_id1: [{'movie_id': 电影ID, 'score': 评分}, ...], user_id2: [...], ...}
        all_user_ratings = db_manager.get_all_user_ratings()
        
        # 步骤3: 计算用户相似度（核心步骤）
        # 用字典存储每个用户与目标用户的相似度和其他信息
        user_similarity = {}
        
        # 遍历所有其他用户，计算与目标用户的相似度
        for other_user_id, other_user_ratings in all_user_ratings.items():
            # 排除目标用户自己
            try:
                if int(other_user_id) == target_user_id:
                    continue
            except (ValueError, TypeError):
                logger.warning(f"无效的用户ID: {other_user_id}")
                continue
            
            # 验证评分数据
            if not other_user_ratings or not isinstance(other_user_ratings, list):
                continue
            
            # 将其他用户评分也转换为字典形式，便于查找
            other_user_ratings_dict = {rating['movie_id']: rating['score'] for rating in other_user_ratings}
            
            # 找出两个用户共同评分的电影（两个集合的交集）
            common_movies = set(target_user_ratings_dict.keys()) & set(other_user_ratings_dict.keys())
            
            # 如果共同评分电影太少，视为不相似，跳过
            # MIN_COMMON_RATINGS参数控制最小共同评分数量，太少可能导致相似度不可靠
            if len(common_movies) < MIN_COMMON_RATINGS:
                continue
            
            # 计算基于评分差平方的相似度
            # 论文算法：差异值area = Σ(score_target_user_i - score_other_user_i)^2 / num_common_movies
            # 计算所有共同评分电影的评分差的平方和
            sum_squared_diff = 0
            for movie_id in common_movies:
                target_score = target_user_ratings_dict[movie_id]  # 目标用户对电影的评分
                other_score = other_user_ratings_dict[movie_id]    # 其他用户对电影的评分
                squared_diff = (target_score - other_score) ** 2   # 评分差的平方
                sum_squared_diff += squared_diff
            
            # 计算差异值area (越小越相似)
            # 除以共同电影数量是为了归一化，使得评分数量不影响相似度
            area = sum_squared_diff / len(common_movies)
            
            # 考虑不重合电影数量的影响（论文4.3.2节）
            # 计算各自独有的电影数量，可选择用于调整相似度
            target_only_count = len(target_user_ratings_dict) - len(common_movies)
            other_only_count = len(other_user_ratings_dict) - len(common_movies)
            
            # 调整差异值（可以根据需要调整公式，当前代码默认不启用）
            # area = area * (1 + 0.1 * (target_only_count + other_only_count))
            
            # 转换差异值为相似度
            # 因为是差异值（越小表示越相似），使用1/(1+area)转换为相似度（越大越相似）
            # 范围为(0,1]，完全相同的用户相似度为1
            similarity = 1 / (1 + area)
            
            # 存储用户相似度及相关信息
            user_similarity[other_user_id] = {
                'similarity': similarity,                # 相似度
                'common_movies': len(common_movies),     # 共同评分电影数
                'area': area,                            # 原始差异值
                'ratings': other_user_ratings_dict       # 该用户的所有评分字典
            }
        
        # 步骤4: 选取Top-N个最相似的邻居用户
        # 按相似度从大到小排序，取前SIMILAR_USERS_COUNT个
        neighbors = sorted(
            user_similarity.items(),
            key=lambda x: x[1]['similarity'], 
            reverse=True
        )[:SIMILAR_USERS_COUNT]
        
        logger.info(f"找到 {len(neighbors)} 个相似用户作为邻居")
        
        # 如果没有找到足够相似的用户，无法使用协同过滤
        if not neighbors:
            logger.info(f"未找到足够相似的用户，无法使用协同过滤")
            return []
        
        # 步骤5: 获取目标用户已评分电影列表，避免推荐已看过的电影
        rated_movie_ids = db_manager.get_movies_rated_by_user(target_user_id)
        
        # 步骤6: 生成候选电影及其预测评分
        # 用字典存储候选电影及其预测评分信息
        candidate_movies = {}
        
        # 遍历所有邻居用户，收集他们高分评价的电影
        for user_id, user_data in neighbors:
            neighbor_ratings = user_data['ratings']  # 邻居用户的所有评分
            similarity = user_data['similarity']     # 与目标用户的相似度
            
            # 遍历邻居用户的所有评分
            for movie_id, score in neighbor_ratings.items():
                # 排除目标用户已评分的电影
                if movie_id in rated_movie_ids:
                    continue
                
                # 只考虑邻居高分评价的电影 (评分 >= 7)
                # 这个阈值可以根据需要调整，目前选择7分是因为7-10分通常代表用户喜欢的电影
                if score < 7:
                    continue
                
                # 计算预测评分 = 邻居评分 * 相似度
                # 如果多个邻居都评价了同一部电影，需要累加
                if movie_id not in candidate_movies:
                    # 第一次遇到这部电影，初始化记录
                    candidate_movies[movie_id] = {
                        'weighted_sum': score * similarity,  # 评分与相似度的加权和
                        'similarity_sum': similarity          # 相似度之和，用于归一化
                    }
                else:
                    # 已经遇到过这部电影，累加数值
                    candidate_movies[movie_id]['weighted_sum'] += score * similarity
                    candidate_movies[movie_id]['similarity_sum'] += similarity
        
        # 步骤7: 计算最终预测评分并排序
        # 遍历所有候选电影，计算归一化的预测评分
        for movie_id in candidate_movies:
            # 预测评分 = 加权评分总和 / 相似度总和
            # 这是加权平均值，相似度高的用户对预测评分影响更大
            candidate_movies[movie_id]['predicted_score'] = (
                candidate_movies[movie_id]['weighted_sum'] / 
                candidate_movies[movie_id]['similarity_sum']
            )
        
        # 按预测评分排序，选出top-N个电影
        recommended_movies = sorted(
            candidate_movies.items(),
            key=lambda x: x[1]['predicted_score'],
            reverse=True
        )[:num_recommendations]
        
        # 提取电影ID列表
        recommended_movie_ids = [movie_id for movie_id, _ in recommended_movies]
        
        logger.info(f"协同过滤推荐生成的电影数量: {len(recommended_movie_ids)}")
        return recommended_movie_ids
    
    except Exception as e:
        logger.error(f"协同过滤推荐算法出错: {e}")
        return []

############################################################
# 基于内容的推荐算法（冷启动解决方案）
############################################################
def get_content_based_recommendations(target_user_id, num_recommendations=5):
    """
    基于内容的电影推荐算法（用于冷启动或补充推荐）
    
    当协同过滤无法生成足够的推荐时，使用此算法作为补充
    算法思路：
    1. 从高评分电影中排除用户已看过的电影
    2. 随机选择一些高分电影推荐给用户，增加多样性
    
    Args:
        target_user_id (int): 目标用户ID
        num_recommendations (int): 推荐电影数量
        
    Returns:
        list: 推荐电影ID列表
    """
    try:
        logger.info(f"为用户 {target_user_id} 生成基于内容的推荐")
        
        # 步骤1: 获取用户已评分电影列表
        # 用于排除用户已看过的电影
        rated_movie_ids = db_manager.get_movies_rated_by_user(target_user_id)
        
        # 步骤2: 获取高评分电影作为候选（排除用户已评分的）
        # 从数据库中获取按豆瓣评分排序的电影（最多100部）
        candidate_movies = db_manager.get_movies_for_content_based_recommendation(
            exclude_movie_ids=rated_movie_ids,
            limit=100  # 选取前100部高分电影作为候选池
        )
        
        # 如果候选电影不足，直接返回全部
        if len(candidate_movies) <= num_recommendations:
            return [movie['id'] for movie in candidate_movies]
        
        # 步骤3: 按豆瓣评分排序
        sorted_movies = sorted(
            candidate_movies,
            key=lambda x: float(x['douban_rating']),
            reverse=True
        )
        
        # 步骤4: 为了增加多样性，从前50%的高分电影中随机选择
        # 而不是简单地取前N个最高分电影，这样可以避免推荐过于集中
        top_half = sorted_movies[:len(sorted_movies) // 2]  # 取前一半的高分电影
        
        if len(top_half) <= num_recommendations:
            # 如果高分电影数量不足，全部使用
            recommended_movies = top_half
        else:
            # 随机选择指定数量的电影，增加推荐多样性
            recommended_movies = random.sample(top_half, num_recommendations)
        
        # 提取电影ID列表
        recommended_movie_ids = [movie['id'] for movie in recommended_movies]
        
        logger.info(f"基于内容推荐生成的电影数量: {len(recommended_movie_ids)}")
        return recommended_movie_ids
    
    except Exception as e:
        logger.error(f"基于内容推荐算法出错: {e}")
        return []

############################################################
# 综合推荐策略
############################################################
def generate_recommendations(target_user_id, num_recommendations=5):
    """
    综合推荐函数，整合不同推荐策略的结果
    
    推荐流程：
    1. 优先使用协同过滤算法
    2. 如果协同过滤结果不足，用基于内容的推荐补充
    3. 如遇到异常，回退到基于内容的推荐
    
    Args:
        target_user_id (int): 目标用户ID
        num_recommendations (int): 推荐电影数量
        
    Returns:
        list: 综合推荐的电影ID列表
    """
    try:
        logger.info(f"为用户 {target_user_id} 生成综合推荐")
        
        # 步骤1: 尝试使用协同过滤生成推荐
        cf_recommendations = get_user_cf_recommendations(target_user_id, num_recommendations)
        
        # 步骤2: 判断协同过滤结果是否足够
        # 如果协同过滤推荐数量足够，直接返回
        if len(cf_recommendations) >= num_recommendations:
            return cf_recommendations[:num_recommendations]
        
        # 步骤3: 如果协同过滤推荐不足，使用基于内容的推荐补充
        # 计算还需要多少推荐数量
        needed_count = num_recommendations - len(cf_recommendations)
        content_recommendations = get_content_based_recommendations(
            target_user_id, 
            needed_count
        )
        
        # 步骤4: 合并两种推荐结果（注意去重）
        final_recommendations = cf_recommendations.copy()
        
        # 遍历基于内容的推荐结果
        for movie_id in content_recommendations:
            # 如果电影尚未在最终推荐列表中，则添加
            if movie_id not in final_recommendations:
                final_recommendations.append(movie_id)
                # 如果达到目标数量，提前结束
                if len(final_recommendations) >= num_recommendations:
                    break
        
        logger.info(f"最终综合推荐电影数量: {len(final_recommendations)} (CF: {len(cf_recommendations)}, Content: {len(content_recommendations)})")
        return final_recommendations
    
    except Exception as e:
        logger.error(f"生成综合推荐出错: {e}")
        
        # 异常处理：出错时尝试返回基于内容的推荐作为备选方案
        # 这是一个容错机制，确保即使协同过滤算法失败，用户仍能获得一些推荐
        try:
            return get_content_based_recommendations(target_user_id, num_recommendations)
        except:
            return [] 