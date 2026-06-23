-- Migration: Add video support for forum posts
-- Created at: 2026-06-22 12:09:00

-- 1. Add video_url column to forum_posts
ALTER TABLE public.forum_posts ADD COLUMN IF NOT EXISTS video_url text;

-- 2. Drop existing view to update it
DROP VIEW IF EXISTS v_forum_posts CASCADE;

-- 3. Recreate v_forum_posts view with video_url
CREATE VIEW v_forum_posts AS
SELECT 
    p.post_id,
    p.user_id,
    COALESCE(u.name, 'AgriDirect Member') as author_name,
    p.created_at,
    p.title,
    p.body,
    p.image_url,
    p.video_url,
    p.is_pinned,
    COALESCE(l.likes_count, 0)::int as likes_count,
    COALESCE(c.comments_count, 0)::int as comments_count
FROM forum_posts p
LEFT JOIN users u ON p.user_id = u.user_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as likes_count 
    FROM forum_post_likes GROUP BY post_id
) l ON p.post_id = l.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as comments_count 
    FROM forum_comments GROUP BY post_id
) c ON p.post_id = c.post_id;
