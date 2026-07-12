-- Migration: Allow public read access (authenticated and anon) for community forum
-- This ensures that posts, comments, likes, and user profiles (for author names/avatars) can be viewed by everyone, fixing the issue where comments would load as empty due to RLS restrictions.

-- 1. Forum Posts SELECT Policy
DROP POLICY IF EXISTS forum_posts_select_authenticated ON public.forum_posts;
CREATE POLICY forum_posts_select_public
ON public.forum_posts
FOR SELECT
USING (true);

-- 2. Forum Comments SELECT Policy
DROP POLICY IF EXISTS forum_comments_select_authenticated ON public.forum_comments;
CREATE POLICY forum_comments_select_public
ON public.forum_comments
FOR SELECT
USING (true);

-- 3. Users SELECT Policy (basic info for names and avatars)
DROP POLICY IF EXISTS users_select_authenticated ON public.users;
CREATE POLICY users_select_public
ON public.users
FOR SELECT
USING (true);

-- 4. Post Likes SELECT Policy
DROP POLICY IF EXISTS forum_post_likes_select_authenticated ON public.forum_post_likes;
CREATE POLICY forum_post_likes_select_public
ON public.forum_post_likes
FOR SELECT
USING (true);

-- 5. Comment Likes SELECT Policy
DROP POLICY IF EXISTS forum_comment_likes_select_authenticated ON public.forum_comment_likes;
CREATE POLICY forum_comment_likes_select_public
ON public.forum_comment_likes
FOR SELECT
USING (true);
