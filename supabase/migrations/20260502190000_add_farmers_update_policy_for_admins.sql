-- Allow admins to update farmer verification flags.
-- Fixes admin panel "Verify Farmer" action failing due to missing UPDATE policy.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'farmers'
      AND policyname = 'farmers_update_admin'
  ) THEN
    CREATE POLICY farmers_update_admin
    ON public.farmers
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
END $$;

