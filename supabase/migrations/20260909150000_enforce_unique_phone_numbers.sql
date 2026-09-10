-- Migration: 20260909150000_enforce_unique_phone_numbers.sql
-- Description: Enforces strict uniqueness on user phone numbers so no two accounts can share the same phone number ("don't make it same with others").
-- Also provides canonical normalization and an authoritative RPC for fast availability checks without OTP.

-- ============================================================================
-- 1. Clean and Normalize Existing Phone Numbers in `users` Table
-- ============================================================================

-- Trim whitespace and clean empty strings to NULL
UPDATE public.users
SET phone = NULL
WHERE phone IS NOT NULL AND trim(phone) = '';

UPDATE public.users
SET phone = trim(phone)
WHERE phone IS NOT NULL;

-- Normalize local 09XXXXXXXXX (11 digits) to +639XXXXXXXXX
UPDATE public.users
SET phone = '+63' || substring(phone from 2)
WHERE phone ~ '^09[0-9]{9}$';

-- Normalize 9XXXXXXXXX (10 digits) to +639XXXXXXXXX
UPDATE public.users
SET phone = '+63' || phone
WHERE phone ~ '^9[0-9]{9}$';

-- Normalize 639XXXXXXXXX (12 digits without +) to +639XXXXXXXXX
UPDATE public.users
SET phone = '+' || phone
WHERE phone ~ '^639[0-9]{9}$';

-- ============================================================================
-- 2. Deduplicate Existing Collisions (Keep Newest / Most Active Account)
-- ============================================================================
-- If any existing test records have duplicate phone numbers, clear phone on the older duplicates
-- so that creating the UNIQUE INDEX will succeed without error.
WITH ranked_duplicates AS (
  SELECT 
    user_id,
    phone,
    ROW_NUMBER() OVER (
      PARTITION BY phone 
      ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
    ) AS rank_num
  FROM public.users
  WHERE phone IS NOT NULL AND trim(phone) != ''
)
UPDATE public.users u
SET phone = NULL
FROM ranked_duplicates r
WHERE u.user_id = r.user_id
  AND r.rank_num > 1;

-- ============================================================================
-- 3. Create Unique Index on Active Registered Phone Numbers
-- ============================================================================
-- Ensures no two user accounts can ever share the same phone number.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_unique_active_phone
ON public.users (phone)
WHERE phone IS NOT NULL AND trim(phone) != '';

COMMENT ON INDEX idx_users_unique_active_phone IS 'Ensures every registered phone number is strictly unique across all user accounts in AgriDirect.';

-- ============================================================================
-- 4. Authoritative Phone Availability RPC Function
-- ============================================================================
-- Allows client apps (web & mobile) to quickly verify if a phone number is available
-- without exposing full users table data.
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
    -- already canonical
    NULL;
  ELSE
    v_normalized := '+' || v_normalized;
  END IF;

  -- Check if already taken by another account
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE (
      u.phone = v_normalized 
      OR u.phone = ('0' || substring(v_normalized from 4)) -- check 09 format fallback
    )
    AND (p_exclude_user_id IS NULL OR u.user_id != p_exclude_user_id)
  ) INTO v_exists;

  -- Return TRUE if available (NOT exists)
  RETURN NOT v_exists;
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.check_phone_availability(TEXT, UUID) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.check_phone_availability(TEXT, UUID) IS 'Returns true if the Philippine phone number is free and available to link; false if already taken.';
