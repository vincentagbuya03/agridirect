-- Add latitude/longitude support for user shipping addresses.
-- Safe to run on existing and new deployments.

CREATE TABLE IF NOT EXISTS public.user_addresses (
  address_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.users(user_id) ON DELETE CASCADE,
  street text NOT NULL,
  barangay text NOT NULL,
  city text NOT NULL,
  province text NOT NULL,
  zip_code text,
  latitude double precision CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision CHECK (longitude BETWEEN -180 AND 180),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_addresses
  ADD COLUMN IF NOT EXISTS latitude double precision;

ALTER TABLE public.user_addresses
  ADD COLUMN IF NOT EXISTS longitude double precision;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_user_addresses_latitude_range'
  ) THEN
    ALTER TABLE public.user_addresses
      ADD CONSTRAINT chk_user_addresses_latitude_range
      CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_user_addresses_longitude_range'
  ) THEN
    ALTER TABLE public.user_addresses
      ADD CONSTRAINT chk_user_addresses_longitude_range
      CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180));
  END IF;
END $$;

ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_addresses_select_own ON public.user_addresses;
CREATE POLICY user_addresses_select_own
ON public.user_addresses
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_addresses_insert_own ON public.user_addresses;
CREATE POLICY user_addresses_insert_own
ON public.user_addresses
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_addresses_update_own ON public.user_addresses;
CREATE POLICY user_addresses_update_own
ON public.user_addresses
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_addresses_delete_own ON public.user_addresses;
CREATE POLICY user_addresses_delete_own
ON public.user_addresses
FOR DELETE
TO authenticated
USING (user_id = auth.uid());
