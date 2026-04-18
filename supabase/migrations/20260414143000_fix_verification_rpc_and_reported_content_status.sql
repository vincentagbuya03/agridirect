-- Migration: Fix verification RPC and moderation status compatibility
-- Purpose:
--   - Align generate_verification_code RPC with verification_type_id schema
--   - Ensure reported_content supports admin workflow fields/statuses used by app

BEGIN;

-- Ensure moderation workflow column exists for admin resolution timestamps.
ALTER TABLE reported_content
  ADD COLUMN IF NOT EXISTS resolved_at timestamptz;

-- Keep status constraint aligned with current app flow.
ALTER TABLE reported_content
  DROP CONSTRAINT IF EXISTS reported_content_status_check,
  DROP CONSTRAINT IF EXISTS check_reported_content_status,
  DROP CONSTRAINT IF EXISTS chk_reported_status,
  DROP CONSTRAINT IF EXISTS chk_reported_content_status,
  ADD CONSTRAINT chk_reported_content_status
  CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed'));

-- Recreate RPC to use verification_type_id (normalized schema) instead of removed text column.
CREATE OR REPLACE FUNCTION generate_verification_code(p_user_id uuid, p_type text)
RETURNS json AS $$
DECLARE
  v_code text;
  v_expires timestamptz := now() + interval '10 minutes';
  v_type_id smallint;
BEGIN
  SELECT verification_type_id
  INTO v_type_id
  FROM verification_types
  WHERE lower(code) = lower(p_type)
  LIMIT 1;

  IF v_type_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid verification type',
      'type', p_type
    );
  END IF;

  DELETE FROM verification_codes
  WHERE user_id = p_user_id
    AND verification_type_id = v_type_id
    AND used_at IS NULL;

  v_code := lpad(floor(random() * 1000000)::text, 6, '0');

  INSERT INTO verification_codes (user_id, verification_code, verification_type_id, expires_at)
  VALUES (p_user_id, v_code, v_type_id, v_expires);

  RETURN json_build_object(
    'success', true,
    'code', v_code,
    'expires_at', v_expires,
    'verification_type_id', v_type_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
