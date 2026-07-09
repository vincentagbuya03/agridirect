-- Allow admins and owners to update farmer registrations.
-- Fixes admin panel approval failing due to missing UPDATE policy on farmer_registrations.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'farmer_registrations'
      AND policyname = 'farmer_registrations_update_policy'
  ) THEN
    CREATE POLICY farmer_registrations_update_policy
    ON public.farmer_registrations
    FOR UPDATE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
      OR
      farmer_id IN (
        SELECT f.farmer_id
        FROM public.farmers f
        WHERE f.user_id = auth.uid()
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1
        FROM public.admins a
        WHERE a.user_id = auth.uid()
      )
      OR
      farmer_id IN (
        SELECT f.farmer_id
        FROM public.farmers f
        WHERE f.user_id = auth.uid()
      )
    );
  END IF;
END $$;
