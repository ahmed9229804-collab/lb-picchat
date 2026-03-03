CREATE TABLE IF NOT EXISTS `lbpicchat_accounts` (
    `username` VARCHAR(20) NOT NULL,
    `password` VARCHAR(100) NOT NULL,
    `phone_number` VARCHAR(15) NOT NULL,
    `display_name` VARCHAR(50) NOT NULL,
    `avatar` VARCHAR(500) DEFAULT NULL,
    `points` INT UNSIGNED NOT NULL DEFAULT 0,
    `location` VARCHAR(100) DEFAULT NULL,
    `notifications` INT UNSIGNED NOT NULL DEFAULT 0,
    `location_x` SMALLINT DEFAULT NULL,
    `location_y` SMALLINT DEFAULT NULL,
    `story_id` INT UNSIGNED DEFAULT NULL,
    `settings` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`username`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS `lbpicchat_logged_in` (
    `phone_number` VARCHAR(15) NOT NULL,
    `username` VARCHAR(20) NOT NULL,
    PRIMARY KEY (`phone_number`),
    FOREIGN KEY (`phone_number`) REFERENCES phone_phones(`phone_number`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`username`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE ON UPDATE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS `lbpicchat_friends` (
    `username` VARCHAR(20) NOT NULL, -- the person who added the friend
    `friend` VARCHAR(20) NOT NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'pending', -- pending, accepted, blocked
    `last_interaction_type` VARCHAR(10) DEFAULT NULL, -- video, image, chat
    `last_interaction_sender` VARCHAR(20) DEFAULT NULL,
    `last_interaction_opened` BOOLEAN DEFAULT false,
    `last_interaction_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `interaction_streak` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_streak_time` DATETIME DEFAULT NULL, -- the last time a media was sent by a new person
    `last_streak_sender` VARCHAR(20) DEFAULT NULL, -- the last person to have sent a media
    `points` INT UNSIGNED NOT NULL DEFAULT 0, -- points, used to get a list of best friends
    `best_friend_username` BOOLEAN NOT NULL DEFAULT false, -- if "username" has marked "friend" as a best friend
    `best_friend_friend` BOOLEAN NOT NULL DEFAULT false, -- if "friend" has marked "username" as a best friend
    `friend_nickname` VARCHAR(50) DEFAULT NULL, -- the nickname that "username" has set for "friend"
    `username_nickname` VARCHAR(50) DEFAULT NULL, -- the nickname that "friend" has set for "username"
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`username`, `friend`),
    FOREIGN KEY (`username`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE,
    FOREIGN KEY (`friend`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS `lbpicchat_posts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sender` VARCHAR(20) NOT NULL,
    `recipient` VARCHAR(20) NOT NULL,
    `post_type` VARCHAR(10) NOT NULL, -- media, chat
    `link` VARCHAR(500) DEFAULT NULL, -- link to the img/video
    `metadata` TEXT DEFAULT NULL, -- json data of text overlay, etc
    `opened` BOOLEAN NOT NULL DEFAULT false,
    `saved` BOOLEAN NOT NULL DEFAULT false,
    `sent_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `opened_at` TIMESTAMP DEFAULT NULL,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`sender`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE,
    FOREIGN KEY (`recipient`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS `lbpicchat_stories` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(20) NOT NULL,
    `link` VARCHAR(500) NOT NULL, -- link to the img/video
    `metadata` TEXT DEFAULT NULL, -- json data of text overlay, etc
    `posted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`username`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS `lbpicchat_stories_views` (
    `story_id` INT UNSIGNED NOT NULL,
    `viewer` VARCHAR(20) NOT NULL,
    `poster` VARCHAR(20) NOT NULL,
    `viewed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`story_id`, `viewer`),
    FOREIGN KEY (`story_id`) REFERENCES lbpicchat_stories(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`viewer`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE,
    FOREIGN KEY (`poster`) REFERENCES lbpicchat_accounts(`username`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
