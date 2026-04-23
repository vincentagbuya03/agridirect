-- Migration: Add Read Time and Fix Article View
-- Created at: 2026-04-22 01:35:00

-- 1. Add read_time column to admin_articles
ALTER TABLE public.admin_articles ADD COLUMN IF NOT EXISTS read_time text DEFAULT '3 min read';

-- 2. Drop existing view to allow column changes
DROP VIEW IF EXISTS v_articles CASCADE;

-- 3. Update v_articles view to be fully dynamic
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
    a.created_at
FROM admin_articles a
JOIN admins adm ON a.admin_id = adm.admin_id
JOIN users u ON adm.user_id = u.user_id;

-- 4. Update existing seed data to have varied read times
UPDATE admin_articles SET read_time = '5 min read' WHERE title = 'Modern Irrigation Techniques';
UPDATE admin_articles SET read_time = '4 min read' WHERE title = 'Organic Pest Management';
