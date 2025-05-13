-- Mindsnap团队的电影推荐系统分团队 - 数据库DDL 

-- 创建数据库 (如果尚未创建)
-- CREATE DATABASE movie_recommendation_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE movie_recommendation_system;

-- 1. 电影信息表 (movies)
CREATE TABLE IF NOT EXISTS `movies` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `title` VARCHAR(255) NOT NULL COMMENT '电影名称',
  `douban_rating` DECIMAL(3,1) COMMENT '豆瓣评分',
  `rating_count` INT COMMENT '评价人数',
  `release_date` VARCHAR(100) COMMENT '上映日期/年代', -- 使用VARCHAR以适应多种格式如 "1994" 或 "1994-10-10"
  `actors` TEXT COMMENT '演员列表, 逗号分隔',
  `directors` TEXT COMMENT '导演列表, 逗号分隔',
  `genres` VARCHAR(255) COMMENT '类型, 逗号分隔',
  `plot_summary` TEXT COMMENT '剧情简介',
  `poster_url` VARCHAR(512) COMMENT '海报图片URL (可选)',
  `douban_url` VARCHAR(512) COMMENT '豆瓣链接 (可选)',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_movies_title` (`title`),
  INDEX `idx_movies_genres` (`genres`),
  INDEX `idx_movies_douban_rating` (`douban_rating`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='电影信息表';

-- 2. 用户信息表 (users)
CREATE TABLE IF NOT EXISTS `users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `openid` VARCHAR(128) NOT NULL UNIQUE COMMENT '微信用户OpenID',
  `nickname` VARCHAR(255) COMMENT '微信昵称 (可选, 注意隐私)',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `last_active_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后活跃时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户信息表';

-- 3. 用户评分表 (ratings)
CREATE TABLE IF NOT EXISTS `ratings` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL COMMENT '关联users表id',
  `movie_id` INT NOT NULL COMMENT '关联movies表id',
  `score` DECIMAL(3,1) NOT NULL COMMENT '用户评分 (0-10)',
  `rated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, -- 允许用户修改评分并更新时间
  UNIQUE KEY `uniq_user_movie_rating` (`user_id`, `movie_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (`movie_id`) REFERENCES `movies`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `idx_ratings_user_id` (`user_id`),
  INDEX `idx_ratings_movie_id` (`movie_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户评分表';

-- 4. 用户搜索记录表 (search_logs - 可选实现)
CREATE TABLE IF NOT EXISTS `search_logs` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `search_query` VARCHAR(255) NOT NULL,
  `search_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `idx_search_logs_user_id` (`user_id`),
  INDEX `idx_search_logs_query` (`search_query`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户搜索记录表'; 

-- 电影数据初始化
-- 添加示例电影数据供系统测试和展示使用

INSERT INTO `movies` (`title`, `douban_rating`, `rating_count`, `release_date`, `actors`, `directors`, `genres`, `plot_summary`, `poster_url`, `douban_url`) VALUES
('三块广告牌', 8.7, 650000, '2017', '弗兰西斯·麦克多蒙德,伍迪·哈里森,山姆·洛克威尔,艾比·考尼什', '马丁·麦克唐纳', '剧情,犯罪', '女儿被奸杀后，警方迟迟未能破案，悲痛欲绝的母亲米尔德里德租下了镇外的三块广告牌，抨击警察局长威洛比办案不力。这一举动在小镇上引起了巨大争议，也让米尔德里德与警察、镇民之间的冲突不断升级...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2510081688.jpg', 'https://movie.douban.com/subject/26611804/'),
('看不见的客人', 8.7, 750000, '2016', '马里奥·卡萨斯,阿娜·瓦格纳,何塞·科罗纳多,巴巴拉·莱涅', '奥里奥尔·保罗', '剧情,悬疑,惊悚,犯罪', '商人艾德里安被指控谋杀情人，他聘请了著名女律师弗吉尼亚为自己辩护。在审判前的最后一晚，艾德里安将案件的真相告诉了弗吉尼亚，但这个真相远比想象中复杂...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2498971355.jpg', 'https://movie.douban.com/subject/26580232/'),
('请以你的名字呼唤我', 8.8, 500000, '2017', '提莫西·查拉梅,艾米·汉莫,迈克尔·斯图巴,阿米拉·卡萨尔', '卢卡·瓜达尼诺', '剧情,爱情,同性', '1983年夏天，17岁的少年艾利奥在意大利度假时，遇到了父亲的美国实习生奥利弗。两人逐渐产生了情愫，度过了一段难忘的夏日时光。这段感情虽然短暂，却影响了艾利奥的一生...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2505525050.jpg', 'https://movie.douban.com/subject/26799731/'),
('小偷家族', 8.7, 600000, '2018', '中川雅也,安藤樱,松冈茉优,城桧吏', '是枝裕和', '剧情,家庭,犯罪', '东京郊外的一个贫穷家庭，依靠偷窃和欺诈为生。某天，他们收留了一个被虐待的小女孩，一家人的生活因此改变。影片探讨了"什么是家庭"这一命题，以及在困境中人与人之间的相互温暖...', 'https://img3.doubanio.com/view/photo/s_ratio_poster/public/p2530599636.jpg', 'https://movie.douban.com/subject/27622447/'),
('调音师', 8.3, 700000, '2018', '阿尤斯曼·库拉纳,塔布,拉迪卡·艾普特,安尔·德赫万', '斯里兰姆·拉格万', '喜剧,悬疑,惊悚,犯罪', '假装盲人的钢琴调音师阿卡什意外目睹了一起谋杀案。为了保住自己的秘密和性命，他必须周旋于凶手、受害者妻子和警察之间，上演一场惊心动魄的猫鼠游戏...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2551995207.jpg', 'https://movie.douban.com/subject/30334073/'),
('猫鼠游戏', 8.8, 500000, '2002', '莱昂纳多·迪卡普里奥,汤姆·汉克斯,克里斯托弗·沃肯,艾米·亚当斯', '史蒂文·斯皮尔伯格', '剧情,传记,犯罪', '弗兰克·阿巴奈尔是FBI历史上最年轻的通缉犯，他在21岁之前就成功冒充了医生、律师和飞行员，并伪造了数百万美元的支票。FBI探员卡尔·汉拉迪开始了对他的追捕，两人展开了一场智力较量...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p453924541.jpg', 'https://movie.douban.com/subject/1305487/'),
('烈日灼心', 8.4, 550000, '2015', '邓超,段奕宏,郭涛,王珞丹', '曹保平', '剧情,悬疑,犯罪', '一起看似简单的抢劫杀人案，随着警方的调查逐渐显露出惊人的真相。三位嫌疑人各有隐情，他们的命运在炎热的夏日中交织在一起，最终走向无法挽回的结局...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2259715855.jpg', 'https://movie.douban.com/subject/24719063/'),
('无双', 8.1, 650000, '2018', '周润发,郭富城,张静初,冯文娟', '庄文强', '剧情,动作,悬疑,犯罪', '艺术家李问与造假天才周文在警方监视下联手制作超级伪钞。随着计划的进行，两人之间的关系也越来越复杂。影片通过精彩的叙事手法，展现了一场惊心动魄的造假与反造假的对决...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2535096871.jpg', 'https://movie.douban.com/subject/26425063/'),
('波西米亚狂想曲', 8.7, 700000, '2018', '拉米·马雷克,本·哈迪,约瑟夫·梅泽罗,艾伦·里奇', '布莱恩·辛格', '剧情,传记,音乐', '影片讲述了传奇摇滚乐队"皇后乐队"的成长历程，特别是主唱弗雷迪·莫库里的人生故事。从乐队的组建到登上世界舞台，再到弗雷迪与疾病的抗争，影片展现了一个时代的音乐传奇...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2549558913.jpg', 'https://movie.douban.com/subject/5300054/'),
('燃情岁月', 8.8, 400000, '1994', '布拉德·皮特,安东尼·霍普金斯,朱莉娅·奥蒙德,艾丹·奎因', '爱德华·兹威克', '剧情,爱情,战争,西部', '20世纪初，三兄弟特里斯坦、阿尔弗雷德和塞缪尔在蒙大拿州的农场长大。随着第一次世界大战的爆发，三人都参军上前线。战争改变了他们的命运，也改变了他们与父亲和他们共同爱上的女人苏珊的关系...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p1363250216.jpg', 'https://movie.douban.com/subject/1295865/'),
('头脑特工队', 8.7, 500000, '2015', '艾米·波勒,菲利丝·史密斯,理查德·坎德,比尔·哈德尔', '彼特·道格特,罗纳尔多·德尔·卡门', '喜剧,动画,冒险', '11岁的莱利搬到新城市后情绪低落。在她的大脑控制中心，由喜悦、恐惧、愤怒、厌恶和忧伤五种情绪组成的团队正在经历混乱。当喜悦和忧伤意外被传送到大脑深处，其他情绪必须合作，帮助莱利度过这段困难时期...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2266293606.jpg', 'https://movie.douban.com/subject/10533913/'),
('海蒂和爷爷', 9.2, 280000, '2015', '阿努克·斯特芬,布鲁诺·甘茨,昆林·艾格匹,伊莎贝尔·奥特曼', '阿兰·葛斯彭纳', '剧情,家庭,冒险', '孤儿海蒂被送到阿尔卑斯山上与脾气古怪的爷爷同住。随着时间推移，海蒂的纯真融化了爷爷的心。然而，当她被姑妈带到法兰克福与富家女克拉拉做伴时，她深深思念着山上的自由生活和她的爷爷...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2332944143.jpg', 'https://movie.douban.com/subject/25958717/'),
('阿甘正传', 9.5, 1700000, '1994', '汤姆·汉克斯,罗宾·怀特,加里·西尼斯,麦凯尔泰·威廉逊', '罗伯特·泽米吉斯', '剧情,爱情', '智商只有75的阿甘经历了越战、乒乓外交等历史事件，但他始终保持着赤子之心。他对珍妮的爱情、与丹中尉的友情、对生活的积极态度，让他在平凡中活出了不平凡的人生...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2372307693.jpg', 'https://movie.douban.com/subject/1292720/'),
('肖申克的救赎', 9.7, 2300000, '1994', '蒂姆·罗宾斯,摩根·弗里曼,鲍勃·冈顿,威廉姆·赛德勒', '弗兰克·德拉邦特', '剧情,犯罪', '银行家安迪因被误判谋杀妻子及其情人而被判终身监禁。在肖申克监狱中，他结识了狱友瑞德，并凭借自己的智慧和坚韧在绝望的环境中重获希望。经过近20年的挖掘，安迪终于成功越狱，获得了真正的自由...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p480747492.jpg', 'https://movie.douban.com/subject/1292052/'),
('这个杀手不太冷', 9.4, 1850000, '1994', '让·雷诺,娜塔莉·波特曼,加里·奥德曼,丹尼·爱罗', '吕克·贝松', '剧情,动作,犯罪', '职业杀手里昂遇见了邻居家的小女孩玛蒂尔达，她的家人被警察局的恶警诺曼杀害。里昂收留了玛蒂尔达，并教她射击和格斗技巧。小女孩决心报仇，而里昂也逐渐被唤醒了内心的柔情...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p511118051.jpg', 'https://movie.douban.com/subject/1295644/'),
('霸王别姬', 9.6, 1800000, '1993', '张国荣,张丰毅,巩俐,葛优', '陈凯歌', '剧情,爱情,同性', '从1920年代到1970年代，程蝶衣和段小楼在京剧界的浮沉起伏。程蝶衣对段小楼的感情、段小楼与菊仙的爱情，以及文化大革命的动荡，共同构成了一部关于艺术、爱情与背叛的史诗...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2561716440.jpg', 'https://movie.douban.com/subject/1291546/'),
('泰坦尼克号', 9.4, 1800000, '1997', '莱昂纳多·迪卡普里奥,凯特·温丝莱特,比利·赞恩,凯西·贝茨', '詹姆斯·卡梅隆', '剧情,爱情,灾难', '1912年，贵族少女罗丝与穷画家杰克在前往美国的"泰坦尼克"号邮轮上相遇并相爱。当邮轮撞上冰山后，杰克为了救罗丝牺牲了自己。85年后，年迈的罗丝讲述了这段刻骨铭心的爱情故事...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p457760035.jpg', 'https://movie.douban.com/subject/1292722/'),
('盗梦空间', 9.3, 1550000, '2010', '莱昂纳多·迪卡普里奥,约瑟夫·高登-莱维特,艾伦·佩吉,汤姆·哈迪', '克里斯托弗·诺兰', '剧情,科幻,悬疑,冒险', '道姆·科布是一位"梦境窃贼"，能够潜入他人梦中窃取秘密。他接受了一个危险的任务：在一个人的梦中植入想法而非窃取。科布和他的团队需要在梦中创造复杂的梦境层次，但他内心的情感创伤可能导致任务失败...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p513344864.jpg', 'https://movie.douban.com/subject/3541415/'),
('黑客帝国', 9.0, 780000, '1999', '基努·里维斯,劳伦斯·菲什伯恩,凯瑞-安·莫斯,雨果·维文', '莱纳·沃卓斯基,莉莉·沃卓斯基', '动作,科幻', '黑客尼奥被卷入一场惊天阴谋中。他发现自己生活的世界实际上是由AI创造的虚拟现实——"母体"。在墨菲斯的引导下，尼奥接受真相，加入反抗军对抗机器统治，逐渐觉醒成为能够改变母体规则的"救世主"...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p451926968.jpg', 'https://movie.douban.com/subject/1291843/'),
('楚门的世界', 9.3, 1350000, '1998', '金·凯瑞,劳拉·琳妮,艾德·哈里斯,诺亚·艾默里奇', '彼得·威尔', '剧情,科幻', '楚门不知道自己的一生都在一个巨大的摄影棚中，他的生活被全球直播。当他开始怀疑这个世界的真实性时，节目制作人克里斯托夫使用各种手段阻止他探索真相。最终，楚门选择了冲破人造世界的界限，寻找真正的自由...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p479682972.jpg', 'https://movie.douban.com/subject/1292064/'),
('星际穿越', 9.3, 1550000, '2014', '马修·麦康纳,安妮·海瑟薇,杰西卡·查斯坦,麦肯吉·弗依', '克里斯托弗·诺兰', '剧情,科幻,冒险', '在未来地球资源枯竭的时代，前NASA宇航员库珀接受任务，驾驶飞船通过虫洞寻找新的宜居星球。在这段跨越时空的旅程中，他不得不面对时间相对论的考验和人类情感与生存的终极选择...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2614988097.jpg', 'https://movie.douban.com/subject/1889243/'),
('龙猫', 9.2, 980000, '1988', '日高法子,坂本千夏,糸井重里,岛本须美', '宫崎骏', '动画,奇幻,冒险', '草壁达郎带着两个女儿搬到乡下，以便照顾住院的妻子。姐姐皋月和妹妹梅在森林中遇到了神奇的生物"龙猫"。在与龙猫的奇妙冒险中，孩子们学会了面对生活中的困难，也收获了友谊和勇气...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2540924496.jpg', 'https://movie.douban.com/subject/1291560/'),
('美丽人生', 9.5, 950000, '1997', '罗伯托·贝尼尼,尼可莱塔·布拉斯基,乔治·坎塔里尼,朱斯蒂诺·杜拉诺', '罗伯托·贝尼尼', '剧情,喜剧,爱情,战争', '犹太青年圭多邂逅美丽的女教师多拉，两人结婚并育有一子。然而好景不长，纳粹占领意大利，圭多和儿子被关进了集中营。为了不让儿子受到惊吓，圭多谎称这是一场游戏，奖品是真正的坦克...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2578474613.jpg', 'https://movie.douban.com/subject/1292063/'),
('阿甘正传', 9.5, 1700000, '1994', '汤姆·汉克斯,罗宾·怀特,加里·西尼斯,麦凯尔泰·威廉逊', '罗伯特·泽米吉斯', '剧情,爱情', '阿甘于二战结束后不久出生在美国南方阿拉巴马州一个闭塞的小镇，智商只有75的他从小便被当成弱智。在妈妈的鼓励下，阿甘凭借惊人的奔跑速度读完了高中，并获得了大学的橄榄球奖学金，成为橄榄球明星...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2372307693.jpg', 'https://movie.douban.com/subject/1292720/'),
('肖申克的救赎', 9.7, 2000000, '1994', '蒂姆·罗宾斯,摩根·弗里曼,鲍勃·冈顿,威廉姆·赛德勒', '弗兰克·德拉邦特', '剧情,犯罪', '银行家安迪因被误判为谋杀妻子及情人而入狱肖申克监狱，在那里他结识了能为狱友搞到各种违禁品的瑞德，二人结为患难之交。安迪凭借自己的聪明才智，赢得了狱警和监狱长的信任，但他始终不放弃希望和自由的追求...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p480747492.jpg', 'https://movie.douban.com/subject/1292052/'),
('霸王别姬', 9.6, 1800000, '1993', '张国荣,张丰毅,巩俐,葛优,英达', '陈凯歌', '剧情,爱情,同性', '段小楼与程蝶衣是一对打小一起长大的师兄弟，两人一个演生，一个演旦，一向配合天衣无缝，尤其一出《霸王别姬》更是誉满京城。但两人对戏剧与人生有着不同的理解，段小楼深知戏子也是人，程蝶衣则是人戏不分...', 'https://img3.doubanio.com/view/photo/s_ratio_poster/public/p2561716440.jpg', 'https://movie.douban.com/subject/1291546/'),
('泰坦尼克号', 9.2, 1650000, '1997', '莱昂纳多·迪卡普里奥,凯特·温丝莱特,比利·赞恩,凯西·贝茨', '詹姆斯·卡梅隆', '剧情,爱情,灾难', '1912年，身处不同阶级的年轻人罗丝和杰克在豪华游轮"泰坦尼克号"上相遇并相爱。但一场突如其来的灾难将这段跨越阶级的恋情以及众多乘客的生命吞噬，这场海难已成为人类记忆中不可磨灭的伤痕...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p457760035.jpg', 'https://movie.douban.com/subject/1292722/'),
('这个杀手不太冷', 9.4, 1800000, '1994', '让·雷诺,娜塔莉·波特曼,加里·奥德曼,丹尼·爱罗', '吕克·贝松', '剧情,动作,犯罪', '纽约黑帮杀手里昂与邻居家的小女孩马蒂尔达成为朋友。马蒂尔达的一家人都被警察局的腐败警官斯坦佛杀害，只有她侥幸逃脱。里昂收留了马蒂尔达，小女孩决定学做杀手，为家人报仇，并协助里昂完成他的杀手任务...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p511118051.jpg', 'https://movie.douban.com/subject/1295644/'),
('千与千寻', 9.3, 1780000, '2001', '柊瑠美,入野自由,夏木真理,菅原文太', '宫崎骏', '剧情,动画,奇幻', '10岁的少女千寻与父母一起搬家，在行驶途中误入奇特的隧道，来到了一个神秘的世界。父母因贪吃变成了猪，千寻被迫留在这个世界上，在汤婆婆的澡堂工作。在小白和锅炉爷爷的帮助下，千寻努力生存并想办法救出父母...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2557573348.jpg', 'https://movie.douban.com/subject/1291561/'),
('美丽人生', 9.5, 950000, '1997', '罗伯托·贝尼尼,尼可莱塔·布拉斯基,乔治·坎塔里尼,朱斯蒂诺·杜拉诺', '罗伯托·贝尼尼', '剧情,喜剧,爱情,战争', '犹太青年圭多邂逅美丽的女教师多拉，两人结婚并育有一子。然而好景不长，纳粹占领意大利，圭多和儿子被关进了集中营。为了不让儿子受到惊吓，圭多谎称这是一场游戏，奖品是真正的坦克...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2578474613.jpg', 'https://movie.douban.com/subject/1292063/'),
('盗梦空间', 9.3, 1500000, '2010', '莱昂纳多·迪卡普里奥,约瑟夫·高登-莱维特,艾伦·佩吉,汤姆·哈迪', '克里斯托弗·诺兰', '剧情,科幻,悬疑,冒险', '道姆·柯布是一名"盗梦者"，通过潜入他人梦境来窃取机密信息。在一次任务失败后，他接受了企业家齐藤的委托，试图在目标人物心中种下想法，即"盗梦"的反向操作"植梦"，这是前所未有的挑战...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p513344864.jpg', 'https://movie.douban.com/subject/3541415/'),
('星际穿越', 9.3, 1250000, '2014', '马修·麦康纳,安妮·海瑟薇,杰西卡·查斯坦,麦肯吉·弗依', '克里斯托弗·诺兰', '剧情,科幻,冒险', '在不久的将来，地球面临严重的环境危机。前NASA宇航员库珀接受一项秘密任务，通过虫洞寻找人类新家园。在探索宇宙奥秘的同时，他不得不面对时间相对论带来的悖论，以及与女儿分离的痛苦...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2614988097.jpg', 'https://movie.douban.com/subject/1889243/'),
('楚门的世界', 9.2, 1350000, '1998', '金·凯瑞,劳拉·琳妮,艾德·哈里斯,诺亚·艾默里奇', '彼得·威尔', '剧情,科幻', '楚门是一个平凡的保险推销员，过着看似完美的生活。然而他开始怀疑周围的世界有些不对劲，原来他的一生都在一个巨大的摄影棚内，是一档24小时不间断播出的真人秀节目的主角...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p479682972.jpg', 'https://movie.douban.com/subject/1292064/'),
('大话西游之大圣娶亲', 9.2, 1100000, '1995-02-04', '周星驰,吴孟达,朱茵,蔡少芬', '刘镇伟', '喜剧,爱情,奇幻', '至尊宝被观音菩萨点化后重回五行山,因为与紫霞仙子的一段因缘他还是放不下世间情感。后来与一班兄弟在一次救人的过程中认识了白晶晶，他为了得到白晶晶的欢心，不惜以身犯险，甚至连性命也不顾...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2455050536.jpg', 'https://movie.douban.com/subject/1292213/'),
('机器人总动员', 9.3, 950000, '2008', '本·贝尔特,艾丽莎·奈特,杰夫·格尔林,佛莱德·威拉特', '安德鲁·斯坦顿', '科幻,动画,冒险', '地球被人类遗弃后，清理垃圾的机器人WALL·E孤独地工作了七百年。某天，他遇到了前来寻找地球生命迹象的机器人EVE，并坠入爱河。当EVE被带回飞船时，WALL·E紧随其后，由此开始了一段惊险而温馨的太空之旅...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p1461851991.jpg', 'https://movie.douban.com/subject/2131459/'),
('天空之城', 9.1, 750000, '1986', '田中真弓,横泽启子,初井言荣,寺田农', '宫崎骏', '动画,奇幻,冒险', '矿工西达因缘际会救了掉下天空的女孩希达。希达拥有飞行石，它是通往传说中漂浮在空中的巨大城堡"拉普达"的钥匙。两人为了保护飞行石和寻找拉普达，展开了一场惊险的旅程...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p1446261379.jpg', 'https://movie.douban.com/subject/1291583/'),
('怦然心动', 8.9, 1350000, '2010', '玛德琳·卡罗尔,卡兰·麦克奥利菲,瑞贝卡·德·莫妮,安东尼·爱德华兹', '罗伯·莱纳', '剧情,喜剧,爱情', '布莱斯从小就讨厌隔壁的女孩朱丽，直到初中二年级他们才开始真正了解彼此。朱丽一直暗恋布莱斯，却在他终于喜欢上自己时放弃了，两人的感情历经挫折与考验，终于明白了爱情的真谛...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p501177648.jpg', 'https://movie.douban.com/subject/3319755/'),
('三傻大闹宝莱坞', 9.2, 1400000, '2009', '阿米尔·汗,卡琳娜·卡普尔,马达范,沙尔曼·乔希', '拉库马·希拉尼', '剧情,喜剧,爱情', '工程学院的学生兰彻思维活跃，不满学院的教条式教育，常常惹校长生气。他和好友法罕、拉加在学校的五年中留下许多回忆，毕业后却突然消失。多年后，好友法罕找到拉加，二人回忆往事并寻找兰彻的下落...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p579729551.jpg', 'https://movie.douban.com/subject/3793023/'),
('龙猫', 9.2, 850000, '1988', '日高法子,坂本千夏,糸井重里,岛本须美', '宫崎骏', '动画,奇幻,冒险', '小姐妹小月和小梅随父亲搬到乡下的新家，邻居是年迈的老奶奶。姐妹俩发现了一种神奇的生物"龙猫"，并与之成为朋友。当小梅走失后，小月求助于龙猫，开始了一段奇妙的冒险...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2540924496.jpg', 'https://movie.douban.com/subject/1291560/'),
('熔炉', 9.3, 700000, '2011', '孔侑,郑有美,金智英,白承焕', '黄东赫', '剧情', '江原道一所聋哑学校的新任美术老师发现学校存在严重的性侵害和暴力问题，受害者是那些无法用语言表达痛苦的聋哑孩子们。他与人权活动家合作，试图揭露真相并获得正义，却遭遇整个社会的漠视和抵制...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p1363250216.jpg', 'https://movie.douban.com/subject/5912992/'),
('海上钢琴师', 9.2, 950000, '1998', '蒂姆·罗斯,普路特·泰勒·文斯,比尔·努恩,梅兰尼·蒂埃里', '朱塞佩·托纳多雷', '剧情,音乐', '1900年，弃婴丹尼·巴德曼被遗弃在一艘远洋豪华客轮上，由船上的水手抚养长大。丹尼从未离开过这艘船，却成为了一名天才钢琴家。虽然外面的世界充满诱惑，但他始终不愿踏上陆地，直到船被拆解的命运到来...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2574551676.jpg', 'https://movie.douban.com/subject/1292001/'),
('忠犬八公的故事', 9.3, 930000, '2009', '理查·基尔,萨拉·罗默尔,琼·艾伦,罗比·萨布莱特', '拉斯·霍尔斯道姆', '剧情', '大学教授帕克在车站偶然收养了一只走失的秋田犬，取名"八公"。八公与主人之间建立了深厚的感情，每天都会在车站等候主人下班。即使在主人去世后，八公仍然坚持在车站等候近10年，感动了无数人...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p524964016.jpg', 'https://movie.douban.com/subject/3011091/'),
('教父', 9.3, 700000, '1972', '马龙·白兰度,阿尔·帕西诺,詹姆斯·肯恩,理查德·卡斯特尔诺', '弗朗西斯·福特·科波拉', '剧情,犯罪', '纽约黑手党家族教父维托·唐·科莱昂在女儿婚礼当天处理各种请求。当他拒绝参与毒品交易后，一场黑帮战争爆发，长子桑尼在冲突中丧生，小儿子迈克尔被迫回国并接替父亲的位置...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p616779645.jpg', 'https://movie.douban.com/subject/1291841/'),
('指环王1：魔戒再现', 9.0, 650000, '2001', '伊莱贾·伍德,伊恩·麦克莱恩,丽芙·泰勒,维果·莫腾森', '彼得·杰克逊', '剧情,奇幻,冒险', '佛罗多意外继承了一枚具有巨大邪恶力量的魔戒，必须前往魔多将其销毁。他与伙伴组成护戒使者，踏上艰难的旅程，同时邪恶势力也在不断追寻魔戒的下落...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2561245602.jpg', 'https://movie.douban.com/subject/1291571/'),
('疯狂动物城', 9.1, 1300000, '2016', '金妮弗·古德温,杰森·贝特曼,伊德里斯·艾尔巴,珍妮·斯蕾特', '拜恩·霍华德,瑞奇·摩尔', '喜剧,动画,冒险', '兔子朱迪从小就梦想成为一名警察，尽管没有人相信一只兔子可以做到这一点。通过坚持不懈的努力，她成为了动物城第一只兔子警官，却被分配到开罚单的工作。为了证明自己，她与狐狸尼克联手侦破一桩神秘失踪案...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2315672647.jpg', 'https://movie.douban.com/subject/25662329/'),
('天使爱美丽', 8.7, 870000, '2001', '奥黛丽·塔图,马修·卡索维茨,吕菲斯,洛莱拉·克拉沃塔', '让-皮埃尔·热内', '剧情,喜剧,爱情', '艾米丽是一个生活在自己幻想世界中的年轻女孩，她偶然发现能够通过小小的善行改变身边人的生活。她决定帮助周围的人，并最终找到了自己的真爱...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p803896904.jpg', 'https://movie.douban.com/subject/1292215/'),
('低俗小说', 8.8, 600000, '1994', '约翰·特拉沃尔塔,乌玛·瑟曼,塞缪尔·杰克逊,布鲁斯·威利斯', '昆汀·塔伦蒂诺', '剧情,喜剧,犯罪', '影片由三个相互关联的故事组成：拳击手布奇为黑帮老大华莱士打假拳，但意外获胜；杀手文森特受命招待华莱士的妻子米娅；两个小混混抢劫餐厅遇到了杀手朱尔斯和文森特...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p1910902213.jpg', 'https://movie.douban.com/subject/1291832/'),
('大闹天宫', 9.4, 250000, '1961', '邱岳峰,富润生,毕克,尚华', '万籁鸣,唐澄', '动画,奇幻', '孙悟空诞生于花果山，拜师学艺后自号美猴王。他大闹龙宫，获得金箍棒；大闹地府，勾掉生死簿上的名字；大闹蟠桃宴，偷吃仙丹；最后大闹天宫，与众神展开激战...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2184505167.jpg', 'https://movie.douban.com/subject/1418019/'),
('加勒比海盗', 8.6, 800000, '2003', '约翰尼·德普,杰弗里·拉什,奥兰多·布鲁姆,凯拉·奈特莉', '戈尔·维宾斯基', '动作,奇幻,冒险', '海盗杰克·斯派洛船长丢失了自己的"黑珍珠号"，并得知昔日好友巴博萨已成为亡灵海盗。当总督之女伊丽莎白被巴博萨绑架后，铁匠威尔与杰克联手,寻找黑珍珠号，解救伊丽莎白，并破解诅咒...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p1596085504.jpg', 'https://movie.douban.com/subject/1298070/'),
('我不是药神', 9.0, 1600000, '2018', '徐峥,王传君,周一围,谭卓', '文牧野', '剧情,喜剧', '神油店老板程勇得知印度有廉价抗癌药，便走私到中国卖给白血病患者。他从一个功利主义者变成了救人的英雄，但随着公安部门对他的调查，他面临着法律和道德的抉择...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2561305376.jpg', 'https://movie.douban.com/subject/26752088/'),
('钢琴家', 9.2, 350000, '2002', '艾德里安·布洛迪,托马斯·克莱舒曼,艾米莉娅·福克斯,米哈乌·热布罗夫斯基', '罗曼·波兰斯基', '剧情,传记,战争,音乐', '犹太钢琴家斯皮尔曼在纳粹占领的华沙，靠着音乐和善良的波兰人帮助幸存下来。尽管经历了战争的残酷，他仍然通过钢琴传递出对生活的热爱和对人性的信仰...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p849145291.jpg', 'https://movie.douban.com/subject/1296736/'),
('疯狂原始人', 8.7, 900000, '2013', '尼古拉斯·凯奇,艾玛·斯通,瑞安·雷诺兹,凯瑟琳·基纳', '柯克·德·米科,克里斯·桑德斯', '喜剧,动画,冒险', '原始人咕噜一家守着安全的山洞生活，直到好奇的女儿伊普遇到了更先进的人类盖。当洞穴被毁后，全家不得不面对未知的世界，踏上寻找新家的冒险旅程...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p1867084027.jpg', 'https://movie.douban.com/subject/1907966/'),
('迁徙的鸟', 9.1, 180000, '2001', '雅克·贝汉,菲利普·拉波洛', '雅克·贝汉,雅克·克鲁奥德,米歇尔·德巴', '纪录片', '这部纪录片拍摄了全球各地候鸟的迁徙过程，展现了鸟类为了生存所进行的惊人旅程。通过跟随不同种类的鸟儿飞越大洋、沙漠和山脉，影片揭示了自然界的奇迹和鸟类的生存智慧...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2263512351.jpg', 'https://movie.douban.com/subject/1292281/'),
('完美的世界', 9.1, 140000, '1993', '凯文·科斯特纳,克林特·伊斯特伍德,劳拉·邓恩,T·J·劳瑟', '克林特·伊斯特伍德', '剧情,犯罪', '越狱犯布奇劫持了8岁的男孩菲利普作为人质。在逃亡过程中，布奇与菲利普建立了深厚的感情。德克萨斯州巡警雷德追捕布奇的同时，也在反思自己作为执法者和布奇之间复杂的关系...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2553104888.jpg', 'https://movie.douban.com/subject/1300992/'),
('功夫', 8.7, 800000, '2004', '周星驰,元秋,元华,黄圣依', '周星驰', '喜剧,动作,犯罪', '上世纪40年代的上海，小混混阿星梦想成为一名伟大的功夫高手。他阴差阳错地卷入了黑帮与街区居民的纷争中，并在一系列机缘巧合下，领悟了功夫的真谛，最终对抗邪恶的斧头帮...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2219011938.jpg', 'https://movie.douban.com/subject/1291543/'),
('闻香识女人', 8.9, 650000, '1992', '阿尔·帕西诺,克里斯·奥唐纳,詹姆斯·瑞布霍恩,加布里埃尔·安瓦尔', '马丁·布莱斯特', '剧情', '准备自杀的盲人上校弗兰克·斯莱德雇佣了贫困学生查理作为他的助手。在纽约的周末旅行中，查理见证了上校如何通过感官感受生活，也学会了如何面对自己的道德困境...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2550757929.jpg', 'https://movie.douban.com/subject/1298624/'),
('罗马假日', 8.9, 750000, '1953', '奥黛丽·赫本,格利高里·派克,埃迪·艾伯特,哈特利·鲍尔', '威廉·惠勒', '喜剧,爱情', '欧洲某国的安妮公主在访问罗马时,因不堪繁重的公务,趁机溜出皇宫.美国记者乔巧遇身份不明的安妮,并带她游览罗马.两人度过了浪漫的一天,最终互生情愫,但公主的责任使两人不得不分开...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2656734504.jpg', 'https://movie.douban.com/subject/1293839/'),
('心灵捕手', 8.9, 650000, '1997', '马特·达蒙,罗宾·威廉姆斯,本·阿弗莱克,斯特兰·斯卡斯加德', '格斯·范·桑特', '剧情', '麻省理工学院的数学教授兰博发现清洁工威尔·亨廷在解数学题方面有着惊人的天赋。在心理学家肖恩的帮助下，威尔逐渐面对自己内心的伤痛，找到了生活的方向和爱情...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p480965695.jpg', 'https://movie.douban.com/subject/1292656/'),
('教父2', 9.2, 400000, '1974', '阿尔·帕西诺,罗伯特·德尼罗,罗伯特·杜瓦尔,黛安·基顿', '弗朗西斯·福特·科波拉', '剧情,犯罪', '影片平行叙述了维托·柯里昂的发迹史和其子迈克尔接管家族后的黑帮生涯。迈克尔残酷地铲除敌人，甚至对背叛家族的亲兄弟下手，逐渐失去了人性...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2194138787.jpg', 'https://movie.douban.com/subject/1299131/'),
('当幸福来敲门', 9.0, 1050000, '2006', '威尔·史密斯,贾登·史密斯,坦迪·牛顿,布莱恩·豪威', '加布里尔·穆奇诺', '剧情,家庭,传记', '克里斯·加德纳经历破产、失业、妻子离开等困境，成为了无家可归的单身父亲。他努力争取到一家证券公司的实习机会，白天艰苦工作，晚上带着儿子流落收容所，通过不懈努力最终成为百万富翁...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2614359276.jpg', 'https://movie.douban.com/subject/1849031/'),
('听不到的说话', 8.8, 320000, '1995', '戸田恵子,飞田展男,室井滋,日高法子', '永丘昭典', '动画,爱情', '初中生硝子因听力障碍转学到新的学校，却遭到了同学石田将也的欺负。几年后，悔改的石田想要弥补过去的错误，尝试与硝子重新建立友谊，并帮助她融入社会...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2671475933.jpg', 'https://movie.douban.com/subject/10750517/'),
('银翼杀手2049', 8.3, 380000, '2017', '瑞恩·高斯林,哈里森·福特,安娜·德·阿玛斯,西尔维娅·侯克斯', '丹尼斯·维伦纽瓦', '剧情,科幻,悬疑', '银翼杀手K发现了一个埋藏多年的秘密，这个秘密有可能导致社会混乱。他的发现使他开始寻找已消失30年的前银翼杀手里克·戴克，而这次寻找也让他反思自己的身份与存在...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2501864539.jpg', 'https://movie.douban.com/subject/10512661/'),
('穿条纹睡衣的男孩', 8.8, 400000, '2008', '阿萨·巴特菲尔德,维拉·法米加,大卫·休里斯,杰克·塞隆', '马克·赫尔曼', '剧情,战争', '8岁的德国男孩布鲁诺与家人搬到了乡下，他的父亲是集中营的指挥官。布鲁诺透过窗户看到远处有个"农场"，并结识了穿条纹睡衣的犹太男孩施穆尔。两个男孩天真的友谊导致了悲剧的发生...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p1473670352.jpg', 'https://movie.douban.com/subject/3008247/'),
('海蒂和爷爷', 9.1, 220000, '2015', '阿努克·斯特芬,布鲁诺·甘茨,昆林·艾格匹,伊莎贝尔·奥特曼', '阿兰·葛斯彭纳', '剧情,家庭,冒险', '孤儿海蒂被姑妈送到了住在阿尔卑斯山上的孤僻爷爷家。尽管一开始爷爷并不欢迎她，但海蒂天真烂漫的性格最终融化了爷爷的心。然而，当海蒂被姑妈带到城市生活时，她只想回到爷爷和山上的自由生活...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2332944143.jpg', 'https://movie.douban.com/subject/25958717/'),
('狮子王', 9.0, 600000, '1994', '乔纳森·泰勒·托马斯,马修·布罗德里克,杰瑞米·艾恩斯,詹姆斯·厄尔·琼斯', '罗杰·阿勒斯,罗伯·明可夫', '剧情,动画,冒险', '幼狮王子辛巴在父亲木法沙被叔叔刀疤谋杀后，被诱导相信是自己的错误而逃离家园。在流浪中，他遇到了机智的丁满和善良的彭彭，逐渐长大成狮。最终，在朋友的鼓励下，他回到了荣耀国，夺回了属于自己的王位...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p726659067.jpg', 'https://movie.douban.com/subject/1301753/'),
('美国往事', 9.2, 320000, '1984', '罗伯特·德尼罗,詹姆斯·伍兹,伊丽莎白·麦戈文,乔·佩西', '赛尔乔·莱昂内', '剧情,犯罪', '影片跨越四十余年，讲述了纽约犹太区的几个年轻人从小混混成长为黑帮的故事。诺德尔从少年到中年再到晚年，回忆起自己充满暴力、背叛与友情的一生，以及对黛博拉的爱恋...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p477229647.jpg', 'https://movie.douban.com/subject/1292262/'),
('哈尔的移动城堡', 8.9, 650000, '2004', '倍赏千惠子,木村拓哉,美轮明宏,我修院达也', '宫崎骏', '动画,奇幻,冒险', '年轻的女帽匠苏菲被荒野女巫诅咒变成了90岁的老太婆。她离开家乡，偶然进入了会移动的城堡，遇到了城堡的主人霍尔——一个英俊但自负的魔法师。苏菲决定留下来帮助霍尔，同时寻找解除自己诅咒的方法...', 'https://img3.doubanio.com/view/photo/s_ratio_poster/public/p2174346180.jpg', 'https://movie.douban.com/subject/1308807/'),
('七武士', 9.3, 160000, '1954', '三船敏郎,志村乔,稻叶义男,宫口精二', '黑泽明', '剧情,动作,冒险', '战国时代的日本，农民雇佣了七个武士保护村庄免受强盗的掠夺。这些性格各异的武士在与村民共同生活的过程中教会了他们如何自卫，也最终参与了一场保卫村庄的激烈战斗...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p647099823.jpg', 'https://movie.douban.com/subject/1295399/'),
('小鞋子', 9.2, 280000, '1997', '默罕默德·阿米尔·纳吉,阿米尔·法拉赫·哈什米安,巴哈雷·赛迪奇,纳菲丝·贾法尔-莫哈达斯', '马基德·马基迪', '剧情,家庭,儿童', '家境贫寒的男孩阿里不小心弄丢了妹妹的鞋子。为了不让父母知道，他与妹妹共用一双鞋上学，这给两人的生活带来了诸多不便。当阿里参加一场跑步比赛，希望赢得第三名奖品——一双运动鞋时，却意外地跑了第一...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2173580603.jpg', 'https://movie.douban.com/subject/1303021/'),
('头号玩家', 8.7, 1200000, '2018', '泰伊·谢里丹,奥利维亚·库克,本·门德尔森,马克·里朗斯', '史蒂文·斯皮尔伯格', '动作,科幻,冒险', '2045年，现实世界衰退破败，人们沉迷于VR游戏"绿洲"以逃避现实。绿洲的创始人死后，留下了隐藏在游戏中的彩蛋，谁找到彩蛋谁就能继承他的巨额财产和对绿洲的控制权。韦德·沃兹和他的朋友们开始了寻找彩蛋的冒险...', 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2516578307.jpg', 'https://movie.douban.com/subject/4920389/'),
('幽灵公主', 8.9, 400000, '1997', '松田洋治,石田百合子,田中裕子,小林薰', '宫崎骏', '动画,奇幻,冒险', '为救受诅咒感染的村民，少年阿席达卡离开村子寻找森林之神。在旅途中，他遇到了被狼神养大的少女山犬公主桑。人类与森林的冲突让阿席达卡陷入两难，他努力寻找人与自然和谐共处的方式...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p1613191025.jpg', 'https://movie.douban.com/subject/1297359/'),
('侧耳倾听', 8.9, 350000, '1995', '本名阳子,小林桂树,高山南,高桥一生', '近藤喜文', '剧情,爱情,动画', '爱看书的少女月岛雯偶然发现所有借阅过的图书卡上都有一个叫天泽圣司的名字。一次偶然的相遇后，雯对这个喜欢提琴猫雕像的男孩产生了好感。在追寻梦想的过程中，两人的感情逐渐加深...', 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p456692072.jpg', 'https://movie.douban.com/subject/1297052/'),
('音乐之声', 9.0, 450000, '1965', '朱莉·安德鲁斯,克里斯托弗·普卢默,埃琳诺·帕克,理查德·海顿', '罗伯特·怀斯', '剧情,爱情,歌舞,家庭', '修女玛丽亚被派去当退役海军上校冯·特拉普家的家庭教师，照顾他的七个孩子。通过音乐和爱，她融化了严厉的上校和孩子们的心。当纳粹入侵奥地利时，一家人不得不逃离祖国...', 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p453788577.jpg', 'https://movie.douban.com/subject/1294408/'); 

-- 添加测试用户数据
INSERT INTO `users` (`openid`, `nickname`) VALUES
('oWm2s5K8pJHwsK7Ll2vQaPnDklMs', '电影爱好者小张'),
('oWm2s5PMnU7823Hwe9lKsu37Qm9J', '影评人阿明'),
('oWm2s5LKs923JkliOpe734KsuWmn', '文艺青年小李'),
('oWm2s5TyuQLaie35Kms8Ls9KqWer', '科幻影迷大雄');

-- 添加用户评分数据
-- 用户1的评分 (喜欢剧情片和经典电影)
INSERT INTO `ratings` (`user_id`, `movie_id`, `score`) VALUES
(1, (SELECT id FROM movies WHERE title='肖申克的救赎' LIMIT 1), 9.5),
(1, (SELECT id FROM movies WHERE title='霸王别姬' LIMIT 1), 9.0),
(1, (SELECT id FROM movies WHERE title='阿甘正传' LIMIT 1), 9.2),
(1, (SELECT id FROM movies WHERE title='美丽人生' LIMIT 1), 8.7),
(1, (SELECT id FROM movies WHERE title='这个杀手不太冷' LIMIT 1), 8.9),
(1, (SELECT id FROM movies WHERE title='海上钢琴师' LIMIT 1), 9.3),
(1, (SELECT id FROM movies WHERE title='钢琴家' LIMIT 1), 9.1),
(1, (SELECT id FROM movies WHERE title='低俗小说' LIMIT 1), 7.8),
(1, (SELECT id FROM movies WHERE title='音乐之声' LIMIT 1), 8.5);

-- 用户2的评分 (偏爱动作片和科幻片)
INSERT INTO `ratings` (`user_id`, `movie_id`, `score`) VALUES
(2, (SELECT id FROM movies WHERE title='黑客帝国' LIMIT 1), 9.6),
(2, (SELECT id FROM movies WHERE title='盗梦空间' LIMIT 1), 9.4),
(2, (SELECT id FROM movies WHERE title='星际穿越' LIMIT 1), 9.7),
(2, (SELECT id FROM movies WHERE title='加勒比海盗' LIMIT 1), 8.8),
(2, (SELECT id FROM movies WHERE title='银翼杀手2049' LIMIT 1), 9.2),
(2, (SELECT id FROM movies WHERE title='头号玩家' LIMIT 1), 8.9),
(2, (SELECT id FROM movies WHERE title='功夫' LIMIT 1), 8.3),
(2, (SELECT id FROM movies WHERE title='无双' LIMIT 1), 8.1),
(2, (SELECT id FROM movies WHERE title='疯狂原始人' LIMIT 1), 7.6),
(2, (SELECT id FROM movies WHERE title='肖申克的救赎' LIMIT 1), 8.2);

-- 用户3的评分 (偏好艺术片和文艺片)
INSERT INTO `ratings` (`user_id`, `movie_id`, `score`) VALUES
(3, (SELECT id FROM movies WHERE title='请以你的名字呼唤我' LIMIT 1), 9.4),
(3, (SELECT id FROM movies WHERE title='小偷家族' LIMIT 1), 9.2),
(3, (SELECT id FROM movies WHERE title='海蒂和爷爷' LIMIT 1), 8.7),
(3, (SELECT id FROM movies WHERE title='听不到的说话' LIMIT 1), 8.8),
(3, (SELECT id FROM movies WHERE title='美丽人生' LIMIT 1), 9.3),
(3, (SELECT id FROM movies WHERE title='天使爱美丽' LIMIT 1), 9.1),
(3, (SELECT id FROM movies WHERE title='侧耳倾听' LIMIT 1), 8.9),
(3, (SELECT id FROM movies WHERE title='小鞋子' LIMIT 1), 9.4),
(3, (SELECT id FROM movies WHERE title='霸王别姬' LIMIT 1), 9.5),
(3, (SELECT id FROM movies WHERE title='海上钢琴师' LIMIT 1), 9.2);

-- 用户4的评分 (科幻片和动画片爱好者)
INSERT INTO `ratings` (`user_id`, `movie_id`, `score`) VALUES
(4, (SELECT id FROM movies WHERE title='星际穿越' LIMIT 1), 9.8),
(4, (SELECT id FROM movies WHERE title='盗梦空间' LIMIT 1), 9.6),
(4, (SELECT id FROM movies WHERE title='黑客帝国' LIMIT 1), 9.5),
(4, (SELECT id FROM movies WHERE title='银翼杀手2049' LIMIT 1), 9.4),
(4, (SELECT id FROM movies WHERE title='头号玩家' LIMIT 1), 9.2),
(4, (SELECT id FROM movies WHERE title='机器人总动员' LIMIT 1), 9.1),
(4, (SELECT id FROM movies WHERE title='龙猫' LIMIT 1), 8.8),
(4, (SELECT id FROM movies WHERE title='千与千寻' LIMIT 1), 9.3),
(4, (SELECT id FROM movies WHERE title='头脑特工队' LIMIT 1), 8.7),
(4, (SELECT id FROM movies WHERE title='哈尔的移动城堡' LIMIT 1), 9.0),
(4, (SELECT id FROM movies WHERE title='楚门的世界' LIMIT 1), 9.3);

-- 添加搜索记录数据（可选，用于未来功能扩展）
INSERT INTO `search_logs` (`user_id`, `search_query`) VALUES
(1, '肖申克'),
(1, '经典电影'),
(2, '科幻'),
(2, '动作片'),
(3, '文艺片'),
(3, '小偷家族'),
(4, '宫崎骏'),
(4, '科幻电影推荐');

-- 添加额外索引以优化推荐算法性能
ALTER TABLE `ratings` ADD INDEX `idx_ratings_score` (`score`);