-- Migration: Update check_phone_availability to support all Philippine phone number formats
-- (handles +639..., 639..., 09..., 9..., cleaned digits, and synthetic emails)

CREATE OR REPLACE FUNCTION public.check_phone_availability(
  p_phone TEXT,
  p_exclude_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_normalized TEXT;
  v_exists BOOLEAN;
BEGIN
  IF p_phone IS NULL OR trim(p_phone) = '' THEN
    RETURN FALSE;
  END IF;

  -- Clean all non-digit characters
  v_normalized := regexp_replace(trim(p_phone), '[^\d]', '', 'g');

  -- Canonicalize to +63 format
  IF v_normalized ~ '^09[0-9]{9}$' THEN
    v_normalized := '+63' || substring(v_normalized from 2);
  ELSIF v_normalized ~ '^9[0-9]{9}$' THEN
    v_normalized := '+63' || v_normalized;
  ELSIF v_normalized ~ '^639[0-9]{9}$' THEN
    v_normalized := '+' || v_normalized;
  ELSIF v_normalized ~ '^\+639[0-9]{9}$' THEN
    NULL;
  ELSE
    v_normalized := '+' || v_normalized;
  END IF;

  -- Check if already taken by another account (checks +63, 63, 09, 10-digit, digit-cleaned, and proxy email)
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE (
      u.phone = v_normalized 
      OR u.phone = substring(v_normalized from 2) -- '639XXXXXXXXX'
      OR u.phone = ('0' || substring(v_normalized from 4)) -- '09XXXXXXXXX'
      OR u.phone = substring(v_normalized from 4) -- '9XXXXXXXXX'
      OR regexp_replace(COALESCE(u.phone, ''), '[^\d]', '', 'g') = regexp_replace(v_normalized, '[^\d]', '', 'g')
      OR u.email = (substring(v_normalized from 2) || '@phone.agridirect.ph')
    )
    AND (p_exclude_user_id IS NULL OR u.user_id != p_exclude_user_id)
  ) INTO v_exists;

  -- Return TRUE if available (NOT exists)
  RETURN NOT v_exists;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_phone_availability(TEXT, UUID) TO anon, authenticated, service_role;
COMMENT ON FUNCTION public.check_phone_availability(TEXT, UUID) IS 'Returns true if the Philippine phone number is free and available to link; false if already taken across all representations.';
