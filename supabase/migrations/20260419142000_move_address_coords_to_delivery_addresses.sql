-- Corrective migration: keep shipping addresses in delivery_addresses,
-- and store coordinates there.

ALTER TABLE public.delivery_addresses
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_delivery_addresses_latitude_range'
  ) THEN
    ALTER TABLE public.delivery_addresses
      ADD CONSTRAINT chk_delivery_addresses_latitude_range
      CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_delivery_addresses_longitude_range'
  ) THEN
    ALTER TABLE public.delivery_addresses
      ADD CONSTRAINT chk_delivery_addresses_longitude_range
      CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180));
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'user_addresses'
  ) THEN
    UPDATE public.delivery_addresses da
    SET latitude = COALESCE(da.latitude, ua.latitude),
        longitude = COALESCE(da.longitude, ua.longitude),
        updated_at = now()
    FROM public.user_addresses ua
    WHERE da.user_id = ua.user_id;

    INSERT INTO public.delivery_addresses (
      user_id,
      label,
      recipient_name,
      recipient_phone,
      street,
      barangay,
      city,
      province,
      zip_code,
      is_default,
      latitude,
      longitude,
      created_at,
      updated_at
    )
    SELECT
      ua.user_id,
      'Home',
      COALESCE(u.name, 'Recipient'),
      COALESCE(NULLIF(u.phone, ''), 'N/A'),
      ua.street,
      ua.barangay,
      ua.city,
      ua.province,
      ua.zip_code,
      true,
      ua.latitude,
      ua.longitude,
      now(),
      now()
    FROM public.user_addresses ua
    LEFT JOIN public.users u ON u.user_id = ua.user_id
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.delivery_addresses da
      WHERE da.user_id = ua.user_id
    );
  END IF;
END $$;

ALTER TABLE public.delivery_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS delivery_addresses_select_own ON public.delivery_addresses;
CREATE POLICY delivery_addresses_select_own
ON public.delivery_addresses
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS delivery_addresses_insert_own ON public.delivery_addresses;
CREATE POLICY delivery_addresses_insert_own
ON public.delivery_addresses
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS delivery_addresses_update_own ON public.delivery_addresses;
CREATE POLICY delivery_addresses_update_own
ON public.delivery_addresses
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS delivery_addresses_delete_own ON public.delivery_addresses;
CREATE POLICY delivery_addresses_delete_own
ON public.delivery_addresses
FOR DELETE
TO authenticated
USING (user_id = auth.uid());
