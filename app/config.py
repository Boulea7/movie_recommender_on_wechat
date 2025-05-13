# Mindsnap团队的电影推荐系统分团队 

# 数据库配置
DB_CONFIG = {
    'host': 'localhost',  # 部署时可能为服务器IP或127.0.0.1
    'user': 'movie_rec_user',
    'password': 'MovieRecDbP@ssw0rd',  # 生产环境中应使用更安全的方式存储密码
    'db': 'movie_recommendation_system',
    'charset': 'utf8mb4',
    'cursorclass': 'pymysql.cursors.DictCursor'  # 方便将查询结果转为字典
}

# 微信公众号配置
WECHAT_TOKEN = "HelloMindsnap"  # 微信公众号开发者配置中的Token
# WECHAT_APPID = "YOUR_APPID"  # 如果需要主动调用API
# WECHAT_APPSECRET = "YOUR_APPSECRET"  # 如果需要主动调用API
# WECHAT_ENCODING_AES_KEY = "zBgVlxIm7Wag3cn3ZMHICuT8qxUU5Kdo9lcr4MS3pP9"  # 如果使用安全模式

# 系统配置
DEFAULT_RECOMMENDATIONS_COUNT = 5  # 默认推荐电影数量
MAX_SEARCH_RESULTS = 5  # 模糊搜索时返回的最大结果数
SIMILAR_USERS_COUNT = 10  # 协同过滤算法中寻找的相似用户数量
MIN_COMMON_RATINGS = 2  # 判断用户相似度时至少需要的共同评分电影数 