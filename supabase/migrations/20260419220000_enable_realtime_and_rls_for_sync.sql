-- Ensure realtime publication + RLS policies required by app realtime sync.
-- This migration is idempotent and safe to run multiple times.

-- 1) Realtime publication membership
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'farmers'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.farmers;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'farmer_registrations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.farmer_registrations;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;
END $$;

-- 2) Ensure RLS is enabled for watched tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farmers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farmer_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- 3) Add minimum SELECT policies used by realtime sync
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_select_self'
  ) THEN
    CREATE POLICY users_select_self
    ON public.users
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'farmers'
      AND policyname = 'farmers_select_authenticated'
  ) THEN
    CREATE POLICY farmers_select_authenticated
    ON public.farmers
    FOR SELECT
    TO authenticated
    USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'farmer_registrations'
      AND policyname = 'farmer_registrations_select_own_or_admin'
  ) THEN
    CREATE POLICY farmer_registrations_select_own_or_admin
    ON public.farmer_registrations
    FOR SELECT
    TO authenticated
    USING (
      farmer_id IN (
        SELECT f.farmer_id
        FROM public.farmers f
        WHERE f.user_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'products'
      AND policyname = 'products_select_authenticated'
  ) THEN
    CREATE POLICY products_select_authenticated
    ON public.products
    FOR SELECT
    TO authenticated
    USING (true);
  END IF;
END $$;
