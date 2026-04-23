-- Migration: Create Community Views (Updated)
-- Created at: 2026-04-22 00:50:00

-- 1. Create v_forum_posts view
CREATE OR REPLACE VIEW v_forum_posts AS
SELECT 
    p.post_id,
    u.name as author_name,
    p.created_at,
    p.title,
    p.body,
    p.image_url,
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

-- 2. Create v_articles view
CREATE OR REPLACE VIEW v_articles AS
SELECT 
    article_id,
    title,
    summary as excerpt,
    'AgriDirect' as author_name,
    CASE 
        WHEN length(body) < 1000 THEN '3 min read'
        WHEN length(body) < 2500 THEN '5 min read'
        ELSE '8 min read'
    END as read_time,
    cover_image_url as image_url,
    is_published as published,
    created_at
FROM admin_articles;
