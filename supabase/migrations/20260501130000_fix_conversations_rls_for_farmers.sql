-- Migration: Fix conversations RLS to allow farmers to initiate conversations
-- Purpose: Resolve 42501 error when a farmer tries to start a message thread with a customer

BEGIN;

-- 1. Create a policy for farmers to insert conversations
-- (This is in addition to the existing conversations_insert_customer_own policy)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'conversations'
      AND policyname = 'conversations_insert_farmer_own'
  ) THEN
    CREATE POLICY conversations_insert_farmer_own
    ON public.conversations
    FOR INSERT
    TO authenticated
    WITH CHECK (
      farmer_id IN (
        SELECT f.farmer_id
        FROM public.farmers f
        WHERE f.user_id = auth.uid()
      )
    );
  END IF;
END $$;

COMMIT;
