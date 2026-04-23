-- Migration: Enable Realtime for Forum and Fix View Joins
-- Created at: 2026-04-22 01:50:00

-- 1. Enable Realtime for Forum Tables
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'forum_posts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.forum_posts;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'forum_comments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.forum_comments;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'forum_post_likes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.forum_post_likes;
  END IF;
END $$;

-- 2. Drop existing view to allow join change and fallback
DROP VIEW IF EXISTS v_forum_posts CASCADE;

-- 3. Update v_forum_posts view to use LEFT JOIN on users
-- This ensures posts show up even if the public.users record is missing or slow to sync
CREATE VIEW v_forum_posts AS
SELECT 
    p.post_id,
    p.user_id,
    COALESCE(u.name, 'AgriDirect Member') as author_name,
    p.created_at,
    p.title,
    p.body,
    p.image_url,
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
