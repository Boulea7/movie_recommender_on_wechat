# 基于协同过滤算法的电影推荐系统研究与实现
# 作者：刘鑫凯 (毕业设计作品)
# Mindsnap团队的电影推荐系统分团队
# 速率限制模块：防止用户频繁请求，保护系统稳定性

import time
import logging
from collections import defaultdict, deque

logger = logging.getLogger(__name__)

class RateLimiter:
    """
    简单的速率限制器
    
    使用滑动窗口算法限制用户请求频率
    """
    
    def __init__(self, max_requests=10, time_window=60):
        """
        初始化速率限制器
        
        Args:
            max_requests (int): 时间窗口内最大请求数
            time_window (int): 时间窗口大小（秒）
        """
        self.max_requests = max_requests
        self.time_window = time_window
        self.user_requests = defaultdict(deque)  # 用户请求时间戳队列
        
    def is_allowed(self, user_id):
        """
        检查用户是否允许发送请求
        
        Args:
            user_id (str): 用户标识
            
        Returns:
            bool: True表示允许，False表示被限制
        """
        current_time = time.time()
        user_queue = self.user_requests[user_id]
        
        # 清理过期的请求记录
        while user_queue and current_time - user_queue[0] > self.time_window:
            user_queue.popleft()
        
        # 检查是否超过限制
        if len(user_queue) >= self.max_requests:
            logger.warning(f"用户 {user_id} 请求频率过高，被限制")
            return False
        
        # 记录当前请求
        user_queue.append(current_time)
        return True
    
    def get_remaining_requests(self, user_id):
        """
        获取用户剩余请求次数
        
        Args:
            user_id (str): 用户标识
            
        Returns:
            int: 剩余请求次数
        """
        current_time = time.time()
        user_queue = self.user_requests[user_id]
        
        # 清理过期的请求记录
        while user_queue and current_time - user_queue[0] > self.time_window:
            user_queue.popleft()
        
        return max(0, self.max_requests - len(user_queue))

# 全局速率限制器实例
# 每个用户每分钟最多10次请求
rate_limiter = RateLimiter(max_requests=10, time_window=60)

def check_rate_limit(user_openid):
    """
    检查用户请求是否被速率限制
    
    Args:
        user_openid (str): 用户OpenID
        
    Returns:
        tuple: (是否允许, 错误消息)
    """
    if not rate_limiter.is_allowed(user_openid):
        remaining = rate_limiter.get_remaining_requests(user_openid)
        return False, f"请求过于频繁，请稍后再试。您还可以发送 {remaining} 次请求。"
    
    return True, None 