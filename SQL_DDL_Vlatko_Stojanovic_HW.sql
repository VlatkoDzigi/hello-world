-- 1) Create schema for this project 
CREATE SCHEMA IF NOT EXISTS social_media;

-- 2) Use this schema as default for this session
SET search_path TO social_media;

-- Drop parent table if it already exists 
DROP TABLE IF EXISTS user_account CASCADE;

-- Main User table (logical entity: User)
CREATE TABLE user_account (
    user_id        BIGSERIAL PRIMARY KEY,
    username       VARCHAR(30)  NOT NULL UNIQUE,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    full_name      VARCHAR(100),
    date_of_birth  DATE,
    status         VARCHAR(20)  NOT NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Reaction types (like, love, angry, etc.)
DROP TABLE IF EXISTS reaction_type CASCADE;

CREATE TABLE reaction_type (
    reaction_type_id SMALLSERIAL PRIMARY KEY,
    name             VARCHAR(20) NOT NULL UNIQUE
);

-- Hashtags used on posts
DROP TABLE IF EXISTS hashtag CASCADE;

CREATE TABLE hashtag (
    hashtag_id BIGSERIAL    PRIMARY KEY,
    tag_text   VARCHAR(100) NOT NULL UNIQUE
);

-- Locations attached to posts
DROP TABLE IF EXISTS location CASCADE;

CREATE TABLE location (
    location_id BIGSERIAL    PRIMARY KEY,
    latitude    DECIMAL(9,6),
    longitude   DECIMAL(9,6),
    city        VARCHAR(100),
    country     VARCHAR(100)
);

-- Posts created by users
DROP TABLE IF EXISTS post CASCADE;

CREATE TABLE post (
    post_id     BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL,
    content     TEXT         NOT NULL,
    visibility  VARCHAR(15)  NOT NULL,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    location_id BIGINT,

    -- Relationships
    CONSTRAINT fk_post_user
        FOREIGN KEY (user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_post_location
        FOREIGN KEY (location_id)
        REFERENCES location(location_id)
        ON DELETE SET NULL,

    -- Check constraints
    CONSTRAINT chk_post_created_at
        CHECK (created_at >= TIMESTAMP '2000-01-01'),

    CONSTRAINT chk_post_visibility
        CHECK (visibility IN ('public', 'friends', 'private'))
);

-- User settings (one-to-one with user)
DROP TABLE IF EXISTS user_settings CASCADE;

CREATE TABLE user_settings (
    user_id       BIGINT PRIMARY KEY,
    language_code CHAR(5),
    timezone      VARCHAR(60),
    is_private    BOOLEAN NOT NULL DEFAULT FALSE,
    allow_tagging BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_settings_user
        FOREIGN KEY (user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE
);

-- Media attached to posts
DROP TABLE IF EXISTS post_media CASCADE;

CREATE TABLE post_media (
    media_id   BIGSERIAL PRIMARY KEY,
    post_id    BIGINT NOT NULL,
    media_url  VARCHAR(500) NOT NULL,
    media_type VARCHAR(20)  NOT NULL,
    width      INT,
    height     INT,

    -- Relationships
    CONSTRAINT fk_media_post
        FOREIGN KEY (post_id)
        REFERENCES post(post_id)
        ON DELETE CASCADE,

    -- Check constraint: measured values cannot be negative
    CONSTRAINT chk_media_size_nonnegative
        CHECK (
            (width  IS NULL OR width  >= 0) AND
            (height IS NULL OR height >= 0)
        )
);

-- Comments on posts 
DROP TABLE IF EXISTS comment CASCADE; 

CREATE TABLE comment (
    comment_id         BIGSERIAL PRIMARY KEY,
    post_id            BIGINT      NOT NULL,
    user_id            BIGINT      NOT NULL,
    content            TEXT        NOT NULL,
    parent_comment_id  BIGINT,
    created_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Relationships
    CONSTRAINT fk_comment_post
        FOREIGN KEY (post_id)
        REFERENCES post(post_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_comment_user
        FOREIGN KEY (user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_comment_parent
        FOREIGN KEY (parent_comment_id)
        REFERENCES comment(comment_id)
        ON DELETE CASCADE,

    -- Check constraint: comment text must not be empty
    CONSTRAINT chk_comment_not_empty
        CHECK (length(trim(content)) > 0)
);

-- Reactions on posts
DROP TABLE IF EXISTS post_reaction CASCADE;

CREATE TABLE post_reaction (
    post_id         BIGINT    NOT NULL,
    user_id         BIGINT    NOT NULL,
    reaction_type_id SMALLINT NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Composite primary key: one reaction per user per post
    CONSTRAINT pk_post_reaction
        PRIMARY KEY (post_id, user_id),

    -- Relationships
    CONSTRAINT fk_post_reaction_post
        FOREIGN KEY (post_id)
        REFERENCES post(post_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_post_reaction_user
        FOREIGN KEY (user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_post_reaction_type
        FOREIGN KEY (reaction_type_id)
        REFERENCES reaction_type(reaction_type_id)
        ON DELETE RESTRICT,

    -- Check constraint: reaction type must be positive
    CONSTRAINT chk_reaction_type_positive
        CHECK (reaction_type_id > 0)
);

-- Mapping between posts and hashtags
DROP TABLE IF EXISTS post_hashtag CASCADE;

CREATE TABLE post_hashtag (
    post_id    BIGINT    NOT NULL,
    hashtag_id BIGINT    NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_post_hashtag
        PRIMARY KEY (post_id, hashtag_id),

    CONSTRAINT fk_post_hashtag_post
        FOREIGN KEY (post_id)
        REFERENCES post(post_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_post_hashtag_tag
        FOREIGN KEY (hashtag_id)
        REFERENCES hashtag(hashtag_id)
        ON DELETE CASCADE
);

-- Follow relationships between users
DROP TABLE IF EXISTS follow CASCADE;

CREATE TABLE follow (
    follower_user_id BIGINT      NOT NULL,
    followed_user_id BIGINT      NOT NULL,
    status           VARCHAR(15) NOT NULL,
    created_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_follow
        PRIMARY KEY (follower_user_id, followed_user_id),

    CONSTRAINT fk_follow_follower
        FOREIGN KEY (follower_user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_follow_followed
        FOREIGN KEY (followed_user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_follow_status
        CHECK (status IN ('pending', 'accepted', 'blocked'))
);


-- Shares of posts
DROP TABLE IF EXISTS share CASCADE;

CREATE TABLE share (
    share_id   BIGSERIAL  PRIMARY KEY,
    post_id    BIGINT     NOT NULL,
    user_id    BIGINT     NOT NULL,
    message    VARCHAR(280),
    created_at TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_share_post
        FOREIGN KEY (post_id)
        REFERENCES post(post_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_share_user
        FOREIGN KEY (user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_share_post_user
        UNIQUE (post_id, user_id)
);

-- Reactions on comments
DROP TABLE IF EXISTS comment_reaction CASCADE;

CREATE TABLE comment_reaction (
    comment_id       BIGINT    NOT NULL,
    user_id          BIGINT    NOT NULL,
    reaction_type_id SMALLINT  NOT NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_comment_reaction
        PRIMARY KEY (comment_id, user_id),

    CONSTRAINT fk_comment_reaction_comment
        FOREIGN KEY (comment_id)
        REFERENCES comment(comment_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_comment_reaction_user
        FOREIGN KEY (user_id)
        REFERENCES user_account(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_comment_reaction_type
        FOREIGN KEY (reaction_type_id)
        REFERENCES reaction_type(reaction_type_id),

    CONSTRAINT chk_comment_reaction_created_at
        CHECK (created_at >= TIMESTAMP '2000-01-01')
);

-- Ensure comment date is not before year 2000
ALTER TABLE comment
ADD CONSTRAINT chk_comment_created_at
CHECK (created_at >= TIMESTAMP '2000-01-01');

-- Ensure share date is not before year 2000
ALTER TABLE share
ADD CONSTRAINT chk_share_created_at
CHECK (created_at >= TIMESTAMP '2000-01-01');

-- Ensure follow date is not before year 2000 
ALTER TABLE follow
ADD CONSTRAINT chk_follow_created_at
CHECK (created_at >= TIMESTAMP '2000-01-01');

-- Track when the row was inserted or last touched (audit column)
ALTER TABLE user_account
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE user_settings
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE reaction_type
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE hashtag
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE location
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE post
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE comment
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE post_media
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE post_reaction
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE comment_reaction
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE follow
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE share
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE post_hashtag
ADD COLUMN record_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Make sure record_ts is set for any existing rows
UPDATE user_account      SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE user_settings     SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE reaction_type     SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE hashtag           SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE location          SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE post              SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE comment           SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE post_media        SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE post_reaction     SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE comment_reaction  SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE follow            SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE share             SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);
UPDATE post_hashtag      SET record_ts = COALESCE(record_ts, CURRENT_TIMESTAMP);

-- Insert users 
INSERT INTO user_account (
    username,
    email,
    password_hash,
    full_name,
    date_of_birth,
    status
)
VALUES
    ('marko',  'marko.petrovic@example.com',  'hash_marko',  'Marko Petrović',  DATE '1995-02-15', 'active'),
    ('jelena', 'jelena.ivanovic@example.com', 'hash_jelena', 'Jelena Ivanović', DATE '1992-11-03', 'active')
ON CONFLICT (username) DO NOTHING;

-- User settings for Marko
INSERT INTO user_settings (
    user_id,
    language_code,
    timezone,
    is_private,
    allow_tagging
)
SELECT
    ua.user_id,
    'en-US',
    'Europe/Belgrade',
    FALSE,
    TRUE
FROM user_account ua
WHERE ua.username = 'marko'
  AND NOT EXISTS (
      SELECT 1
      FROM user_settings us
      WHERE us.user_id = ua.user_id
  );

-- User settings for Jelena
INSERT INTO user_settings (
    user_id,
    language_code,
    timezone,
    is_private,
    allow_tagging
)
SELECT
    ua.user_id,
    'en-US',
    'Europe/Belgrade',
    TRUE,
    TRUE
FROM user_account ua
WHERE ua.username = 'jelena'
  AND NOT EXISTS (
      SELECT 1
      FROM user_settings us
      WHERE us.user_id = ua.user_id
  );

-- Basic reaction types
INSERT INTO reaction_type (reaction_type_id, name)
VALUES
    (1, 'like'),
    (2, 'love'),
    (3, 'laugh')
ON CONFLICT (reaction_type_id) DO NOTHING;

-- Hashtags 
INSERT INTO hashtag (tag_text)
VALUES
    ('#weekend'),
    ('#coffee'),
    ('#study')
ON CONFLICT (tag_text) DO NOTHING;

-- Locations 
INSERT INTO location (latitude, longitude, city, country)
VALUES
    (44.7866, 20.4489, 'Belgrade', 'Serbia'),
    (43.3209, 21.8958, 'Nis',      'Serbia')
ON CONFLICT DO NOTHING;

-- Posts for Marko and Jelena
INSERT INTO post (user_id, content, visibility, location_id)
SELECT ua.user_id,
       'First workout in the gym.',
       'friends',
       loc.location_id
FROM user_account ua
LEFT JOIN location loc ON loc.city = 'Belgrade'
WHERE ua.username = 'marko'
  AND NOT EXISTS (
        SELECT 1 FROM post p
        WHERE p.user_id = ua.user_id
          AND p.content = 'First workout in the gym.'
  );

INSERT INTO post (user_id, content, visibility, location_id)
SELECT ua.user_id,
       'Studying SQL for the exam.',
       'public',
       loc.location_id
FROM user_account ua
LEFT JOIN location loc ON loc.city = 'Nis'
WHERE ua.username = 'jelena'
  AND NOT EXISTS (
        SELECT 1 FROM post p
        WHERE p.user_id = ua.user_id
          AND p.content = 'Studying SQL for the exam.'
  );


-- Comments on posts
-- Jelena comments on Marko's post
INSERT INTO comment (post_id, user_id, content)
SELECT p.post_id,
       ua.user_id,
       'Great job, keep going!'
FROM user_account ua
JOIN post p ON p.content = 'First workout in the gym.'
WHERE ua.username = 'jelena'
  AND NOT EXISTS (
        SELECT 1 FROM comment c
        WHERE c.post_id = p.post_id
          AND c.user_id = ua.user_id
          AND c.content = 'Great job, keep going!'
  );

-- Marko comments on Jelena's post
INSERT INTO comment (post_id, user_id, content)
SELECT p.post_id,
       ua.user_id,
       'Good luck with the exam!'
FROM user_account ua
JOIN post p ON p.content = 'Studying SQL for the exam.'
WHERE ua.username = 'marko'
  AND NOT EXISTS (
        SELECT 1 FROM comment c
        WHERE c.post_id = p.post_id
          AND c.user_id = ua.user_id
          AND c.content = 'Good luck with the exam!'
  );


-- Reactions on posts
-- Jelena likes Marko's post
INSERT INTO post_reaction (post_id, user_id, reaction_type_id)
SELECT p.post_id,
       ua.user_id,
       rt.reaction_type_id
FROM user_account ua
JOIN post p          ON p.content = 'First workout in the gym.'
JOIN reaction_type rt ON rt.name = 'like'
WHERE ua.username = 'jelena'
  AND NOT EXISTS (
        SELECT 1 FROM post_reaction pr
        WHERE pr.post_id = p.post_id
          AND pr.user_id = ua.user_id
  );

-- Marko loves Jelena's post
INSERT INTO post_reaction (post_id, user_id, reaction_type_id)
SELECT p.post_id,
       ua.user_id,
       rt.reaction_type_id
FROM user_account ua
JOIN post p          ON p.content = 'Studying SQL for the exam.'
JOIN reaction_type rt ON rt.name = 'love'
WHERE ua.username = 'marko'
  AND NOT EXISTS (
        SELECT 1 FROM post_reaction pr
        WHERE pr.post_id = p.post_id
          AND pr.user_id = ua.user_id
  );


-- Follow relations
-- Marko follows Jelena
INSERT INTO follow (follower_user_id, followed_user_id, status)
SELECT f.user_id,
       t.user_id,
       'accepted'
FROM user_account f
JOIN user_account t ON t.username = 'jelena'
WHERE f.username = 'marko'
  AND NOT EXISTS (
        SELECT 1 FROM follow fo
        WHERE fo.follower_user_id  = f.user_id
          AND fo.followed_user_id = t.user_id
  );

-- Jelena follows Marko
INSERT INTO follow (follower_user_id, followed_user_id, status)
SELECT f.user_id,
       t.user_id,
       'accepted'
FROM user_account f
JOIN user_account t ON t.username = 'marko'
WHERE f.username = 'jelena'
  AND NOT EXISTS (
        SELECT 1 FROM follow fo
        WHERE fo.follower_user_id  = f.user_id
          AND fo.followed_user_id = t.user_id
  );


-- Shares of posts
-- Jelena shares Marko's post
INSERT INTO share (post_id, user_id, message)
SELECT p.post_id,
       ua.user_id,
       'Take a look at this workout post.'
FROM user_account ua
JOIN post p ON p.content = 'First workout in the gym.'
WHERE ua.username = 'jelena'
  AND NOT EXISTS (
        SELECT 1 FROM share s
        WHERE s.post_id = p.post_id
          AND s.user_id = ua.user_id
  );

-- Marko shares Jelena's post
INSERT INTO share (post_id, user_id, message)
SELECT p.post_id,
       ua.user_id,
       'Nice post about studying SQL.'
FROM user_account ua
JOIN post p ON p.content = 'Studying SQL for the exam.'
WHERE ua.username = 'marko'
  AND NOT EXISTS (
        SELECT 1 FROM share s
        WHERE s.post_id = p.post_id
          AND s.user_id = ua.user_id
  );


-- Media attached to posts
-- Media for Marko's post
INSERT INTO post_media (post_id, media_url, media_type, width, height)
SELECT p.post_id,
       'https://example.com/gym_photo.jpg',
       'image',
       800,
       600
FROM post p
WHERE p.content = 'First workout in the gym.'
  AND NOT EXISTS (
        SELECT 1 FROM post_media m
        WHERE m.post_id  = p.post_id
          AND m.media_url = 'https://example.com/gym_photo.jpg'
  );

-- Media for Jelena's post
INSERT INTO post_media (post_id, media_url, media_type, width, height)
SELECT p.post_id,
       'https://example.com/sql_notes.png',
       'image',
       1024,
       768
FROM post p
WHERE p.content = 'Studying SQL for the exam.'
  AND NOT EXISTS (
        SELECT 1 FROM post_media m
        WHERE m.post_id  = p.post_id
          AND m.media_url = 'https://example.com/sql_notes.png'
  );


-- Hashtags attached to posts
-- Marko's post gets #weekend
INSERT INTO post_hashtag (post_id, hashtag_id)
SELECT p.post_id,
       h.hashtag_id
FROM post p
JOIN hashtag h ON h.tag_text = '#weekend'
WHERE p.content = 'First workout in the gym.'
  AND NOT EXISTS (
        SELECT 1 FROM post_hashtag ph
        WHERE ph.post_id   = p.post_id
          AND ph.hashtag_id = h.hashtag_id
  );

-- Jelena's post gets #study
INSERT INTO post_hashtag (post_id, hashtag_id)
SELECT p.post_id,
       h.hashtag_id
FROM post p
JOIN hashtag h ON h.tag_text = '#study'
WHERE p.content = 'Studying SQL for the exam.'
  AND NOT EXISTS (
        SELECT 1 FROM post_hashtag ph
        WHERE ph.post_id   = p.post_id
          AND ph.hashtag_id = h.hashtag_id
  );


-- Reactions on comments
-- Marko likes Jelena's comment on his post
INSERT INTO comment_reaction (comment_id, user_id, reaction_type_id)
SELECT c.comment_id,
       ua.user_id,
       rt.reaction_type_id
FROM comment c
JOIN user_account ua  ON ua.username = 'marko'
JOIN reaction_type rt ON rt.name = 'like'
WHERE c.content = 'Great job, keep going!'
  AND NOT EXISTS (
        SELECT 1 FROM comment_reaction cr
        WHERE cr.comment_id = c.comment_id
          AND cr.user_id    = ua.user_id
  );

-- Jelena likes Marko's comment on her post
INSERT INTO comment_reaction (comment_id, user_id, reaction_type_id)
SELECT c.comment_id,
       ua.user_id,
       rt.reaction_type_id
FROM comment c
JOIN user_account ua  ON ua.username = 'jelena'
JOIN reaction_type rt ON rt.name = 'like'
WHERE c.content = 'Good luck with the exam!'
  AND NOT EXISTS (
        SELECT 1 FROM comment_reaction cr
        WHERE cr.comment_id = c.comment_id
          AND cr.user_id    = ua.user_id
  );
