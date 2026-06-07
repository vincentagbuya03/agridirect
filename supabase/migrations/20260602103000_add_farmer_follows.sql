CREATE TABLE IF NOT EXISTS public.farmer_follows (
  follow_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  farmer_id uuid NOT NULL REFERENCES public.farmers(farmer_id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (follower_user_id, farmer_id)
);

ALTER TABLE public.farmer_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS farmer_follows_select_authenticated ON public.farmer_follows;
CREATE POLICY farmer_follows_select_authenticated
ON public.farmer_follows
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS farmer_follows_insert_customer_own ON public.farmer_follows;
CREATE POLICY farmer_follows_insert_customer_own
ON public.farmer_follows
FOR INSERT
TO authenticated
WITH CHECK (
  follower_user_id = auth.uid()
  AND public.current_user_is_customer()
);

DROP POLICY IF EXISTS farmer_follows_delete_own ON public.farmer_follows;
CREATE POLICY farmer_follows_delete_own
ON public.farmer_follows
FOR DELETE
TO authenticated
USING (follower_user_id = auth.uid() OR public.current_user_is_admin());
