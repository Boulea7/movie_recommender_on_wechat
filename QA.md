# 项目常见问题解答 (QA)

## 问题1：我们用了什么神奇的"魔法"来推荐电影？它是怎么实现的？

我们这个项目用了两种主要的"魔法"（在电脑科学里，我们叫它"算法"）来给你推荐可能喜欢的电影：

1.  **"跟你口味相似的人也喜欢这些"魔法 (基于用户的协同过滤 - User-CF)**
2.  **"你以前喜欢这类电影，这些可能也合你胃口"魔法 (基于内容的推荐 - Content-Based)**

并且，我们还会把这两种魔法结合起来用，让推荐更靠谱！

### 1. "跟你口味相似的人也喜欢这些"魔法 (User-CF)

这种魔法的核心想法是：**如果小明和小红都喜欢《哪吒之魔童降世》和《流浪地球》，那么小明喜欢的其他电影，小红可能也会喜欢；反过来也一样。**

它是这么工作的：

*   **第一步：找到"口味相似的邻居"**
    *   系统会先看看你（比如叫"小李"）给哪些电影打过分。
    *   然后，它会去看其他所有用过我们这个小程序的人（比如小明、小红、小张……）都给哪些电影打过分。
    *   接下来，系统会比较你和小明、你和小红……你们俩都看过的电影，以及你们给这些电影打的分数是不是差不多。
        *   比如，你给《功夫熊猫》打了9分，小明打了8.5分，分数很接近。如果你们共同评价了好几部电影，分数都挺像，那系统就觉得你和小明的口味很相似。
        *   我们有一个计算公式（基于你们对共同电影评分差异的平方和）来精确地算出你和其他每个人的"口味相似度"。相似度越高，说明你们越像"电影知己"。
    *   系统会挑出跟你口味最相似的一群人（比如10个人），我们叫他们"邻居"。

*   **第二步：从"邻居"那里找推荐**
    *   系统会看这些"邻居"们都喜欢（比如打了高分，像7分以上）但你还没看过的电影。
    *   比如，你的邻居小明很喜欢《疯狂动物城》，给你打了9分，而你还没看过这部电影。
    *   系统会收集所有邻居推荐的这类电影，并根据邻居跟你口味的相似程度、以及邻居给电影打的分数，给这些电影排个名。越相似的邻居推荐的、评分越高的电影，排名就越靠前。

*   **第三步：把最好的推荐给你**
    *   最后，系统会从这个排名里选出最好的几部电影（比如3部）推荐给你。

**简单说，User-CF 就是通过找到和你"心有灵犀"的电影伙伴，看看他们喜欢什么你没看过的，然后推荐给你。**

在我们的代码里，这部分主要在 `app/recommendation_engine.py` 文件的 `get_user_cf_recommendations` 函数中实现。它会去数据库 (`app/db_manager.py` 帮忙) 读取大家给电影的评分，然后吭哧吭哧地计算相似度，最后找出推荐的电影ID。

### 2. "你以前喜欢这类电影，这些可能也合你胃口"魔法 (Content-Based)

这种魔法主要用在以下情况：
*   **你是新来的**：你刚开始用，还没给几部电影打分，系统不了解你的口味，User-CF魔法就不好使了（我们叫它"冷启动"问题）。
*   **你的口味太独特**：系统找不到和你口味足够相似的"邻居"。

它是这么工作的：

*   **对于新朋友**：既然不知道你喜欢啥，系统就先给你推荐一些大家都说好的电影，比如豆瓣评分很高的那些经典电影。
    *   它会从数据库里挑出一些评分很高的电影 (比如8.5分以上)。
    *   为了不老是推荐同样几部，它可能会从这些高分电影里随机选几部推荐给你。
*   **对于已经评过一些电影但User-CF效果不好的朋友**：系统会分析你已经评过高分的电影的特征（比如类型是"科幻"、"喜剧"，导演是谁，演员是谁等等，虽然目前我们主要还是看你评过高分的电影本身，然后推类似的），然后找具有相似特征的电影推荐给你。但目前我们系统更偏向于推荐那些"热门且你没看过的"。

**简单说，Content-Based 就是在你"人生地不熟"或者"口味独特不好找伴儿"的时候，给你推荐一些公认的好电影，或者根据你以前的喜好猜你可能喜欢什么。**

这部分主要在 `app/recommendation_engine.py` 文件的 `get_content_based_recommendations` 函数中实现。它会去数据库 (`app/db_manager.py` 帮忙) 查找高分电影，并排除掉你已经看过的。

### 3. 两种魔法一起用 (混合推荐)

大多数时候，我们会优先尝试第一种魔法 (User-CF)，因为它通常能挖到更个性化的推荐。
*   如果User-CF找到了足够多的好电影推荐给你，那就用它的结果。
*   如果User-CF找到的电影不够多（比如只找到1部，但我们想推荐3部），或者它因为某些原因没成功，我们就会用第二种魔法 (Content-Based) 来补充，或者完全用Content-Based的结果。

这样就能确保你总能收到一些推荐啦！这个调度工作是在 `app/recommendation_engine.py` 的 `generate_recommendations` 函数里完成的。

## 问题2：微信公众号是怎么搭建和工作的？

咱们这个电影推荐系统是通过微信公众号来和你互动的。你可以在公众号里发消息，比如搜电影、给电影打分、或者叫它给你推荐电影。

它的工作流程大概是这样的：

1.  **你和公众号的"约定" (配置)**
    *   首先，我们需要在微信公众平台（一个专门管理公众号的网站）上进行一些设置。
    *   我们会告诉微信：当有用户给这个公众号发消息时，请把消息转发到我们自己服务器的一个特定网址（URL），比如 `http://你的服务器IP地址/`。
    *   我们还会设置一个"暗号"（Token，比如 `HelloMindsnap`）。这个暗号用来确保微信服务器真的是在和我们的服务器说话，而不是别人冒充的。

2.  **第一次"握手" (服务器验证)**
    *   当我们在微信公众平台填好上面说的URL和Token，点击"提交"的时候，微信服务器会先给我们的服务器URL发送一个"打招呼"的请求（GET请求）。
    *   这个请求里会带上一些参数，包括一个随机字符串 `echostr` 和一个根据我们设置的Token以及其他参数算出来的"签名" `signature`。
    *   我们的服务器收到这个请求后（代码在 `app/main.py` 的 `WeChatInterface` 类的 `GET` 方法里处理），会用同样的Token和参数，按照和微信服务器一样的规则也算出一个签名。
    *   如果两个签名对得上，说明"暗号正确"，我们的服务器就会把那个随机字符串 `echostr` 原封不动地还给微信服务器。微信服务器收到后，就知道我们的服务器是"自己人"，配置就成功了。这部分验证签名的逻辑在 `app/wechat_handler.py` 的 `check_signature` 函数里。

3.  **你发消息，我们收消息 (接收用户消息)**
    *   当你关注了我们的公众号，或者在里面输入文字（比如电影名"阿甘正传"、"推荐"、"评价 狮子王 9"）并发送时：
    *   你的微信会把这条消息先发给微信的服务器。
    *   微信的服务器会把这条消息打包成一种叫XML的特殊格式文本，然后通过网络发送（POST请求）到我们之前配置好的服务器URL (`http://你的服务器IP地址/`)。
    *   我们服务器上的程序 (`app/main.py` 的 `WeChatInterface` 类的 `POST` 方法) 就会接收这个XML数据包。

4.  **我们"解读"你的意思并回复 (处理消息并响应)**
    *   服务器收到XML后，会交给 `app/wechat_handler.py` 里的 `handle_wechat_message` 函数来处理。
    *   这个函数会：
        *   先把XML"解包"，读懂里面是什么内容（比如是文字消息还是关注事件，文字内容是什么）。这部分用到了 `parse_xml_message` 函数。
        *   根据你发的内容做不同的事情：
            *   如果你发的是电影名，它就去叫 `app/db_manager.py` 帮忙去数据库里搜电影信息 (通过 `handle_movie_search` 函数)。
            *   如果你发的是"评价 电影名 分数"，它就去记录你的评分 (通过 `handle_movie_rating` 函数)。
            *   如果你发的是"推荐"，它就去叫 `app/recommendation_engine.py` 用前面说的"魔法"给你找电影 (通过 `handle_movie_recommendation` 函数)。
            *   如果你是刚关注，它就会准备一段欢迎词。
        *   处理完之后，它会把要回复给你的内容（比如电影信息、推荐列表、或者"评分成功"的提示）也打包成XML格式。这部分用到了 `build_text_response` 函数。
        *   最后，我们的服务器把这个XML回复包发回给微信服务器，微信服务器再把它显示在你的手机微信里。

所以，整个过程就像：你 -> 微信 -> 我们的服务器 -> (处理) -> 我们的服务器 -> 微信 -> 你。微信服务器在中间扮演了一个"邮递员"的角色。

## 问题3：我们的"电影资料库"（数据库）是什么样的？

为了能搜索电影、记录你的评分、还有推荐电影，我们需要一个地方来存这些信息。这个"地方"就是数据库。

*   **数据库类型和版本**：我们用的是一种非常流行的关系型数据库，叫做 **MySQL**，版本是 **8.0**。你可以把它想象成一个管理很多表格的超级Excel。

*   **数据库名字**：我们的数据库总管叫 `movie_recommendation_system`。

*   **里面有哪些"表格" (表结构)**：
    这个数据库里主要有以下几个重要的表格：

    1.  **`movies` (电影信息表)**：存放所有电影的详细资料。
        *   `id`: 每个电影的独一无二的数字编号 (比如 1, 2, 3...)。
        *   `title`: 电影名称 (比如 "肖申克的救赎")。
        *   `douban_rating`: 这部电影在豆瓣上的评分 (比如 9.7)。
        *   `rating_count`: 有多少人在豆瓣上评价了这部电影。
        *   `release_date`: 电影上映的日期或年份 (比如 "1994" 或 "2023-10-01")。
        *   `actors`: 主要演员的名字，用逗号隔开 (比如 "蒂姆·罗宾斯,摩根·弗里曼")。
        *   `directors`: 导演的名字，用逗号隔开。
        *   `genres`: 电影的类型，用逗号隔开 (比如 "剧情,犯罪")。
        *   `plot_summary`: 电影的剧情简介。
        *   `created_at`, `updated_at`: 这条电影记录是什么时候加进来的，什么时候修改过的。

        ```sql
        -- 电影信息表 (movies) 的样子，这是用SQL语言描述的
        CREATE TABLE IF NOT EXISTS `movies` (
          `id` INT AUTO_INCREMENT PRIMARY KEY,
          `title` VARCHAR(255) NOT NULL COMMENT '电影名称',
          `douban_rating` DECIMAL(3,1) COMMENT '豆瓣评分',
          `rating_count` INT COMMENT '评价人数',
          `release_date` VARCHAR(100) COMMENT '上映日期/年代',
          `actors` TEXT COMMENT '演员列表, 逗号分隔',
          `directors` TEXT COMMENT '导演列表, 逗号分隔',
          `genres` VARCHAR(255) COMMENT '类型, 逗号分隔',
          `plot_summary` TEXT COMMENT '剧情简介',
          -- ... 其他字段和设置 ...
          `poster_url` VARCHAR(512) COMMENT '海报图片URL (可选)',
          `douban_url` VARCHAR(512) COMMENT '豆瓣链接 (可选)',
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX `idx_movies_title` (`title`),
          INDEX `idx_movies_genres` (`genres`),
          INDEX `idx_movies_douban_rating` (`douban_rating`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='电影信息表';
        ```

    2.  **`users` (用户信息表)**：存放关注我们公众号的用户信息。
        *   `id`: 每个用户的独一无二的数字编号。
        *   `openid`: 微信给每个用户分配的一个特别的身份标识（一长串字母数字），通过这个我们才能认出你是谁。这个是**非常重要**的。
        *   `nickname`: 你在微信里的昵称 (这个我们目前没怎么用，主要是为了保护你的隐私)。
        *   `created_at`, `last_active_at`: 你是什么时候关注的，以及最近一次活跃是什么时候。

        ```sql
        -- 用户信息表 (users) 的样子
        CREATE TABLE IF NOT EXISTS `users` (
          `id` INT AUTO_INCREMENT PRIMARY KEY,
          `openid` VARCHAR(128) NOT NULL UNIQUE COMMENT '微信用户OpenID',
          `nickname` VARCHAR(255) COMMENT '微信昵称 (可选, 注意隐私)',
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          `last_active_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后活跃时间'
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户信息表';
        ```

    3.  **`ratings` (用户评分表)**：记录你给哪些电影打了多少分。这是推荐魔法能起作用的关键数据！
        *   `id`: 每条评分记录的独一无二的数字编号。
        *   `user_id`: 是哪个用户打的分 (对应 `users` 表里的 `id`)。
        *   `movie_id`: 是给哪部电影打的分 (对应 `movies` 表里的 `id`)。
        *   `score`: 你打的具体分数 (比如 8.5)。
        *   `rated_at`: 你是什么时候打的这个分。

        ```sql
        -- 用户评分表 (ratings) 的样子
        CREATE TABLE IF NOT EXISTS `ratings` (
          `id` INT AUTO_INCREMENT PRIMARY KEY,
          `user_id` INT NOT NULL COMMENT '关联users表id',
          `movie_id` INT NOT NULL COMMENT '关联movies表id',
          `score` DECIMAL(3,1) NOT NULL COMMENT '用户评分 (0-10)',
          `rated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, -- 允许用户修改评分并更新时间
          UNIQUE KEY `uniq_user_movie_rating` (`user_id`, `movie_id`), -- 保证一个用户对一部电影只能评一次分
          FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE, -- 和users表关联起来
          FOREIGN KEY (`movie_id`) REFERENCES `movies`(`id`) ON DELETE CASCADE ON UPDATE CASCADE, -- 和movies表关联起来
          INDEX `idx_ratings_user_id` (`user_id`),
          INDEX `idx_ratings_movie_id` (`movie_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户评分表';
        ```

    4.  **`search_logs` (用户搜索记录表 - 可选)**：这个表用来记录你都搜过哪些电影。
        *   `id`: 每条搜索记录的编号。
        *   `user_id`: 哪个用户搜的。
        *   `search_query`: 搜的关键词是什么。
        *   `search_time`: 什么时候搜的。
        这个表目前是可选的，主要是为了以后分析大家喜欢搜什么，或者优化搜索功能。

        ```sql
        -- 用户搜索记录表 (search_logs) 的样子
        CREATE TABLE IF NOT EXISTS `search_logs` (
          `id` INT AUTO_INCREMENT PRIMARY KEY,
          `user_id` INT NOT NULL,
          `search_query` VARCHAR(255) NOT NULL,
          `search_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
          INDEX `idx_search_logs_user_id` (`user_id`),
          INDEX `idx_search_logs_query` (`search_query`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户搜索记录表';
        ```

所有这些表格互相配合，存储了我们电影推荐系统运行所需要的所有数据。比如，当你要搜电影时，程序就去 `movies` 表里找；当你要评价时，程序就把你的评分存到 `ratings` 表里，并把它和 `users` 表以及 `movies` 表关联起来。推荐的时候，更是要同时看这几张表的数据才能算出结果。
