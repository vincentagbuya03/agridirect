-- ============================================================================
-- 005_community_tables.sql
-- Forum posts, comments, and likes
-- ============================================================================

-- ============================================================================
-- FORUM_POSTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS forum_posts (
    post_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_forum_posts_user_id ON forum_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_created_at ON forum_posts(created_at DESC);

-- Trigger for auto-update timestamp
CREATE TRIGGER forum_posts_updated_at_trigger
BEFORE UPDATE ON forum_posts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FORUM_COMMENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS forum_comments (
    comment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_forum_comments_post_id ON forum_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_comments_user_id ON forum_comments(user_id);

-- Trigger for auto-update timestamp
CREATE TRIGGER forum_comments_updated_at_trigger
BEFORE UPDATE ON forum_comments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- POST_LIKES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_likes (
    like_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);
