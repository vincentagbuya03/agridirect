-- Migration: Add Audience to Articles
-- Created at: 2026-04-27 22:35:00

-- 1. Add audience column to admin_articles
-- Possible values: 'ALL', 'FARMER'
ALTER TABLE public.admin_articles ADD COLUMN IF NOT EXISTS audience text DEFAULT 'ALL';

-- 2. Drop existing view to allow column changes
DROP VIEW IF EXISTS v_articles CASCADE;

-- 3. Update v_articles view to include audience
CREATE VIEW v_articles AS
SELECT 
    a.article_id,
    a.title,
    a.summary as excerpt,
    a.body,
    u.name as author_name,
    a.read_time,
    a.cover_image_url as image_url,
    a.is_published as published,
    a.created_at,
    a.audience
FROM admin_articles a
JOIN admins adm ON a.admin_id = adm.admin_id
JOIN users u ON adm.user_id = u.user_id;
