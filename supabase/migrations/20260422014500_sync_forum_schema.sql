-- Migration: Sync Forum Posts and Articles Schema
-- Created at: 2026-04-22 01:45:00

-- 1. Drop existing view to allow column changes
DROP VIEW IF EXISTS v_forum_posts CASCADE;

-- 2. Recreate v_forum_posts with is_pinned and user_id
CREATE VIEW v_forum_posts AS
SELECT 
    p.post_id,
    p.user_id,
    u.name as author_name,
    p.created_at,
    p.title,
    p.body,
    p.image_url,
    p.is_pinned,
    COALESCE(l.likes_count, 0)::int as likes_count,
    COALESCE(c.comments_count, 0)::int as comments_count
FROM forum_posts p
JOIN users u ON p.user_id = u.user_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as likes_count 
    FROM forum_post_likes GROUP BY post_id
) l ON p.post_id = l.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as comments_count 
    FROM forum_comments GROUP BY post_id
) c ON p.post_id = c.post_id;
