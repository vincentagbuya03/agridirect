-- Add missing products write RLS policies for farmer sync and admin moderation.
-- Safe to run multiple times.

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'products'
      AND policyname = 'products_insert_farmer_own_or_admin'
  ) THEN
    CREATE POLICY products_insert_farmer_own_or_admin
    ON public.products
    FOR INSERT
    TO authenticated
    WITH CHECK (
      EXISTS (
        SELECT 1
        FROM public.farmers f
        WHERE f.farmer_id = products.farmer_id
          AND f.user_id = auth.uid()
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
      AND policyname = 'products_update_farmer_own_or_admin'
  ) THEN
    CREATE POLICY products_update_farmer_own_or_admin
    ON public.products
    FOR UPDATE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.farmers f
        WHERE f.farmer_id = products.farmer_id
          AND f.user_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1
        FROM public.farmers f
        WHERE f.farmer_id = products.farmer_id
          AND f.user_id = auth.uid()
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
      AND policyname = 'products_delete_farmer_own_or_admin'
  ) THEN
    CREATE POLICY products_delete_farmer_own_or_admin
    ON public.products
    FOR DELETE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.farmers f
        WHERE f.farmer_id = products.farmer_id
          AND f.user_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
    );
  END IF;
END $$;
