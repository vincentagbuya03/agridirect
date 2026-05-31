-- Allow users and farmers to update their own profile details.
-- Fixes "Rows affected: 0" issue when updating image_url or avatar_url.

DO $$
BEGIN
  -- 1) Farmers table update policy
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'farmers'
      AND policyname = 'farmers_update_owner'
  ) THEN
    CREATE POLICY farmers_update_owner
    ON public.farmers
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
  END IF;

  -- 2) Users table update policy
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_update_self'
  ) THEN
    CREATE POLICY users_update_self
    ON public.users
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
  END IF;
END $$;
