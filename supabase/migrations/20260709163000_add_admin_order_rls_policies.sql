-- Allow admins to select and update all orders and order items.
-- Fixes admin dashboard showing ₱0 revenue and empty order lists due to RLS blocking.

DO $$
BEGIN
  -- 1. Orders SELECT policy for Admin
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'orders'
      AND policyname = 'orders_select_admin'
  ) THEN
    CREATE POLICY orders_select_admin
    ON public.orders
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
    );
  END IF;

  -- 2. Orders UPDATE policy for Admin
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'orders'
      AND policyname = 'orders_update_admin'
  ) THEN
    CREATE POLICY orders_update_admin
    ON public.orders
    FOR UPDATE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
    );
  END IF;

  -- 3. Order Items SELECT policy for Admin
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'order_items'
      AND policyname = 'order_items_select_admin'
  ) THEN
    CREATE POLICY order_items_select_admin
    ON public.order_items
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
    );
  END IF;
END $$;
