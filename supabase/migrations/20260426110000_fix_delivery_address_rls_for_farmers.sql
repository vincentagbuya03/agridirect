-- Migration: Fix delivery_addresses RLS to allow farmers to view order locations
-- Purpose: Addresses an issue where farmers could not see delivery locations because
-- the original RLS policy only allowed the customer (user_id = auth.uid()) to view them.

BEGIN;

-- Add a policy that allows a farmer to view a delivery address if an order exists
-- for their farm that uses this delivery address.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'delivery_addresses'
      AND policyname = 'delivery_addresses_select_farmer'
  ) THEN
    CREATE POLICY delivery_addresses_select_farmer
    ON public.delivery_addresses
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.orders o
        JOIN public.farmers f ON o.farmer_id = f.farmer_id
        WHERE o.delivery_address_id = delivery_addresses.address_id
          AND f.user_id = auth.uid()
      )
    );
  END IF;
END $$;

COMMIT;
