-- Enforce community role rules:
-- - Farmers can create posts.
-- - Farmers and customers can comment and like.
-- - Authenticated users can read community content.

CREATE TABLE IF NOT EXISTS public.forum_comment_likes (
  user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  comment_id uuid NOT NULL REFERENCES public.forum_comments(comment_id) ON DELETE CASCADE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, comment_id)
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'forum_comment_likes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.forum_comment_likes;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.current_user_is_farmer()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.farmers f
    WHERE f.user_id = auth.uid()
      AND COALESCE(f.is_active, true)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_is_customer()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE c.user_id = auth.uid()
      AND COALESCE(c.is_active, true)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admins a
    WHERE a.user_id = auth.uid()
      AND COALESCE(a.is_active, true)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_engage_forum()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_user_is_farmer()
      OR public.current_user_is_customer()
      OR public.current_user_is_admin();
$$;

ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS forum_posts_select_authenticated ON public.forum_posts;
CREATE POLICY forum_posts_select_authenticated
ON public.forum_posts
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_posts_insert_farmer ON public.forum_posts;
CREATE POLICY forum_posts_insert_farmer
ON public.forum_posts
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_is_farmer());

DROP POLICY IF EXISTS forum_posts_update_owner_or_admin ON public.forum_posts;
CREATE POLICY forum_posts_update_owner_or_admin
ON public.forum_posts
FOR UPDATE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin())
WITH CHECK (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_posts_delete_owner_or_admin ON public.forum_posts;
CREATE POLICY forum_posts_delete_owner_or_admin
ON public.forum_posts
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_comments_select_authenticated ON public.forum_comments;
CREATE POLICY forum_comments_select_authenticated
ON public.forum_comments
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_comments_insert_farmer_or_customer ON public.forum_comments;
CREATE POLICY forum_comments_insert_farmer_or_customer
ON public.forum_comments
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_can_engage_forum());

DROP POLICY IF EXISTS forum_comments_update_owner_or_admin ON public.forum_comments;
CREATE POLICY forum_comments_update_owner_or_admin
ON public.forum_comments
FOR UPDATE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin())
WITH CHECK (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_comments_delete_owner_or_admin ON public.forum_comments;
CREATE POLICY forum_comments_delete_owner_or_admin
ON public.forum_comments
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_post_likes_select_authenticated ON public.forum_post_likes;
CREATE POLICY forum_post_likes_select_authenticated
ON public.forum_post_likes
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_post_likes_insert_farmer_or_customer ON public.forum_post_likes;
CREATE POLICY forum_post_likes_insert_farmer_or_customer
ON public.forum_post_likes
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_can_engage_forum());

DROP POLICY IF EXISTS forum_post_likes_delete_own ON public.forum_post_likes;
CREATE POLICY forum_post_likes_delete_own
ON public.forum_post_likes
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_comment_likes_select_authenticated ON public.forum_comment_likes;
CREATE POLICY forum_comment_likes_select_authenticated
ON public.forum_comment_likes
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_comment_likes_insert_farmer_or_customer ON public.forum_comment_likes;
CREATE POLICY forum_comment_likes_insert_farmer_or_customer
ON public.forum_comment_likes
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_can_engage_forum());

DROP POLICY IF EXISTS forum_comment_likes_delete_own ON public.forum_comment_likes;
CREATE POLICY forum_comment_likes_delete_own
ON public.forum_comment_likes
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

GRANT EXECUTE ON FUNCTION public.current_user_is_farmer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_customer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_engage_forum() TO authenticated;
