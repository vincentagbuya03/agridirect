-- Migration: Hardcode verification types
-- Purpose:
--   - Replace verification_types lookup table with a hardcoded text column
--   - Keep allowed values enforced with a CHECK constraint
--   - Remove verification_type_id dependency from verification_codes

BEGIN;

ALTER TABLE verification_codes
  ADD COLUMN IF NOT EXISTS verification_type text;

UPDATE verification_codes vc
SET verification_type = vt.code
FROM verification_types vt
WHERE vc.verification_type_id = vt.verification_type_id
  AND vc.verification_type IS NULL;

UPDATE verification_codes
SET verification_type = CASE
  WHEN lower(coalesce(verification_type, '')) IN ('email', 'phone', 'password_reset', 'two_factor') THEN lower(verification_type)
  WHEN verification_type_id IS NOT NULL THEN COALESCE(
    (
      SELECT vt.code
      FROM verification_types vt
      WHERE vt.verification_type_id = verification_codes.verification_type_id
      LIMIT 1
    ),
    'email'
  )
  ELSE 'email'
END;

ALTER TABLE verification_codes
  ALTER COLUMN verification_type SET NOT NULL;

ALTER TABLE verification_codes
  DROP CONSTRAINT IF EXISTS verification_codes_verification_type_check,
  DROP CONSTRAINT IF EXISTS fk_verification_codes_type_id,
  DROP CONSTRAINT IF EXISTS verification_codes_verification_type_id_fkey,
  ADD CONSTRAINT verification_codes_verification_type_check
  CHECK (verification_type IN ('email', 'phone', 'password_reset', 'two_factor'));

ALTER TABLE verification_codes
  DROP COLUMN IF EXISTS verification_type_id;

CREATE OR REPLACE FUNCTION generate_verification_code(p_user_id uuid, p_type text)
RETURNS json AS $$
DECLARE
  v_code text;
  v_expires timestamptz := now() + interval '10 minutes';
  v_type text := lower(trim(p_type));
BEGIN
  IF v_type NOT IN ('email', 'phone', 'password_reset', 'two_factor') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid verification type', 'type', p_type);
  END IF;

  DELETE FROM verification_codes
  WHERE user_id = p_user_id
    AND verification_type = v_type
    AND used_at IS NULL;

  v_code := lpad(floor(random() * 1000000)::text, 6, '0');

  INSERT INTO verification_codes (user_id, verification_code, verification_type, expires_at)
  VALUES (p_user_id, v_code, v_type, v_expires);

  RETURN json_build_object(
    'success', true,
    'code', v_code,
    'expires_at', v_expires,
    'verification_type', v_type
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TABLE IF EXISTS verification_types;

COMMIT;
