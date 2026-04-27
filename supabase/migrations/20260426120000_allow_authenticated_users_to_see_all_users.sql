-- Migration: Allow authenticated users to see each other's basic profile information
-- This is required for messages and orders to display names and avatars correctly.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_select_authenticated'
  ) THEN
    CREATE POLICY users_select_authenticated
    ON public.users
    FOR SELECT
    TO authenticated
    USING (true);
  END IF;
END $$;
