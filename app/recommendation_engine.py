# Mindsnap团队的电影推荐系统分团队 

import logging
import random
import math
from app import db_manager
from app.config import SIMILAR_USERS_COUNT, MIN_COMMON_RATINGS

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_user_cf_recommendations(target_user_id, num_recommendations=5):
    """
    基于用户的协同过滤推荐算法
    
    Args:
        target_user_id: 目标用户ID
        num_recommendations: 推荐电影数量
        
    Returns:
        推荐电影ID列表
    """
    try:
        logger.info(f"为用户 {target_user_id} 生成协同过滤推荐")
        
        # 获取目标用户的评分记录
        target_user_ratings = db_manager.get_user_ratings(target_user_id)
        if not target_user_ratings:
            logger.info(f"用户 {target_user_id} 没有评分记录，无法使用协同过滤")
            return []
        
        # 将目标用户评分转换为 {movie_id: score} 字典，方便后续查找
        target_user_ratings_dict = {rating['movie_id']: rating['score'] for rating in target_user_ratings}
        
        # 获取所有用户的评分记录
        all_user_ratings = db_manager.get_all_user_ratings()
        
        # 计算用户相似度
        user_similarity = {}
        for other_user_id, other_user_ratings in all_user_ratings.items():
            # 排除目标用户自己
            if int(other_user_id) == target_user_id:
                continue
            
            # 转换其他用户评分为字典形式
            other_user_ratings_dict = {rating['movie_id']: rating['score'] for rating in other_user_ratings}
            
            # 找出两个用户共同评分的电影
            common_movies = set(target_user_ratings_dict.keys()) & set(other_user_ratings_dict.keys())
            
            # 如果共同评分电影太少，视为不相似
            if len(common_movies) < MIN_COMMON_RATINGS:
                continue
            
            # 计算基于评分差平方的相似度
            # 论文算法：越小越相似，差异值area = Σ(score_target_user_i - score_other_user_i)^2 / num_common_movies
            sum_squared_diff = 0
            for movie_id in common_movies:
                target_score = target_user_ratings_dict[movie_id]
                other_score = other_user_ratings_dict[movie_id]
                squared_diff = (target_score - other_score) ** 2
                sum_squared_diff += squared_diff
            
            # 计算差异值area (越小越相似)
            area = sum_squared_diff / len(common_movies)
            
            # 考虑不重合电影数量的影响（论文4.3.2节）
            target_only_count = len(target_user_ratings_dict) - len(common_movies)
            other_only_count = len(other_user_ratings_dict) - len(common_movies)
            
            # 调整差异值（可以根据需要调整公式）
            # area = area * (1 + 0.1 * (target_only_count + other_only_count))
            
            # 因为是差异值（越小表示越相似），我们使用 1/(1+area) 转换为相似度（越大越相似）
            similarity = 1 / (1 + area)
            
            user_similarity[other_user_id] = {
                'similarity': similarity,
                'common_movies': len(common_movies),
                'area': area,
                'ratings': other_user_ratings_dict
            }
        
        # 选取Top-N个最相似的邻居用户
        # 按相似度从大到小排序
        neighbors = sorted(
            user_similarity.items(),
            key=lambda x: x[1]['similarity'], 
            reverse=True
        )[:SIMILAR_USERS_COUNT]
        
        logger.info(f"找到 {len(neighbors)} 个相似用户作为邻居")
        
        if not neighbors:
            logger.info(f"未找到足够相似的用户，无法使用协同过滤")
            return []
        
        # 获取目标用户已评分电影列表，避免推荐已看过的电影
        rated_movie_ids = db_manager.get_movies_rated_by_user(target_user_id)
        
        # 候选电影及其预测评分
        candidate_movies = {}
        
        # 从邻居的评分中生成推荐
        for user_id, user_data in neighbors:
            neighbor_ratings = user_data['ratings']
            similarity = user_data['similarity']
            
            # 遍历邻居用户的评分
            for movie_id, score in neighbor_ratings.items():
                # 排除目标用户已评分的电影
                if movie_id in rated_movie_ids:
                    continue
                
                # 只考虑邻居高分评价的电影 (评分 >= 7)
                if score < 7:
                    continue
                
                # 计算预测评分 = 邻居评分 * 相似度
                if movie_id not in candidate_movies:
                    candidate_movies[movie_id] = {
                        'weighted_sum': score * similarity,
                        'similarity_sum': similarity
                    }
                else:
                    candidate_movies[movie_id]['weighted_sum'] += score * similarity
                    candidate_movies[movie_id]['similarity_sum'] += similarity
        
        # 计算最终预测评分
        for movie_id in candidate_movies:
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
        
        # 提取电影ID
        recommended_movie_ids = [movie_id for movie_id, _ in recommended_movies]
        
        logger.info(f"协同过滤推荐生成的电影数量: {len(recommended_movie_ids)}")
        return recommended_movie_ids
    
    except Exception as e:
        logger.error(f"协同过滤推荐算法出错: {e}")
        return []

def get_content_based_recommendations(target_user_id, num_recommendations=5):
    """
    基于内容的电影推荐算法（用于冷启动或补充推荐）
    
    Args:
        target_user_id: 目标用户ID
        num_recommendations: 推荐电影数量
        
    Returns:
        推荐电影ID列表
    """
    try:
        logger.info(f"为用户 {target_user_id} 生成基于内容的推荐")
        
        # 获取用户已评分电影列表
        rated_movie_ids = db_manager.get_movies_rated_by_user(target_user_id)
        
        # 获取高评分电影作为候选（排除用户已评分的）
        candidate_movies = db_manager.get_movies_for_content_based_recommendation(
            exclude_movie_ids=rated_movie_ids,
            limit=100
        )
        
        # 如果候选电影不足，直接返回全部
        if len(candidate_movies) <= num_recommendations:
            return [movie['id'] for movie in candidate_movies]
        
        # 否则先按豆瓣评分排序
        sorted_movies = sorted(
            candidate_movies,
            key=lambda x: float(x['douban_rating']),
            reverse=True
        )
        
        # 为了增加多样性，从前50%的高分电影中随机选择
        top_half = sorted_movies[:len(sorted_movies) // 2]
        if len(top_half) <= num_recommendations:
            recommended_movies = top_half
        else:
            recommended_movies = random.sample(top_half, num_recommendations)
        
        recommended_movie_ids = [movie['id'] for movie in recommended_movies]
        
        logger.info(f"基于内容推荐生成的电影数量: {len(recommended_movie_ids)}")
        return recommended_movie_ids
    
    except Exception as e:
        logger.error(f"基于内容推荐算法出错: {e}")
        return []

def generate_recommendations(target_user_id, num_recommendations=5):
    """
    综合推荐函数，优先使用协同过滤，不足时用基于内容的推荐补充
    
    Args:
        target_user_id: 目标用户ID
        num_recommendations: 推荐电影数量
        
    Returns:
        推荐电影ID列表
    """
    try:
        logger.info(f"为用户 {target_user_id} 生成综合推荐")
        
        # 尝试协同过滤推荐
        cf_recommendations = get_user_cf_recommendations(target_user_id, num_recommendations)
        
        # 如果协同过滤推荐数量足够，直接返回
        if len(cf_recommendations) >= num_recommendations:
            return cf_recommendations[:num_recommendations]
        
        # 如果协同过滤推荐不足，使用基于内容的推荐补充
        content_recommendations = get_content_based_recommendations(
            target_user_id, 
            num_recommendations - len(cf_recommendations)
        )
        
        # 合并两种推荐结果（注意去重）
        final_recommendations = cf_recommendations.copy()
        for movie_id in content_recommendations:
            if movie_id not in final_recommendations:
                final_recommendations.append(movie_id)
                # 如果达到目标数量，提前结束
                if len(final_recommendations) >= num_recommendations:
                    break
        
        logger.info(f"最终综合推荐电影数量: {len(final_recommendations)} (CF: {len(cf_recommendations)}, Content: {len(content_recommendations)})")
        return final_recommendations
    
    except Exception as e:
        logger.error(f"生成综合推荐出错: {e}")
        
        # 出错时尝试返回基于内容的推荐作为备选
        try:
            return get_content_based_recommendations(target_user_id, num_recommendations)
        except:
            return [] 