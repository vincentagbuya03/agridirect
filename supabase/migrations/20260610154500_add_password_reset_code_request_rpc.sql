-- Migration: Add password reset code request RPC
-- Purpose:
--   - Lets the web email API request a reset code by email without direct table reads.
--   - Reuses active unexpired reset codes and the existing generate_verification_code rate limit.

BEGIN;

CREATE OR REPLACE FUNCTION public.request_password_reset_code(p_email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text := lower(trim(coalesce(p_email, '')));
  v_user_id uuid;
  v_existing_code text;
  v_generated json;
BEGIN
  IF v_email = '' OR position('@' in v_email) = 0 THEN
    RETURN json_build_object('success', false, 'message', 'A valid email address is required.');
  END IF;

  SELECT u.user_id
  INTO v_user_id
  FROM public.users u
  WHERE lower(u.email) = v_email
  LIMIT 1;

  IF v_user_id IS NULL THEN
    SELECT v.user_id
    INTO v_user_id
    FROM public.v_users_with_roles v
    WHERE lower(v.email) = v_email
    LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No account was found for that email.');
  END IF;

  SELECT vc.verification_code
  INTO v_existing_code
  FROM public.verification_codes vc
  WHERE vc.user_id = v_user_id
    AND vc.verification_type = 'password_reset'
    AND vc.used_at IS NULL
    AND vc.expires_at > now()
  ORDER BY vc.created_at DESC
  LIMIT 1;

  IF v_existing_code IS NOT NULL THEN
    RETURN json_build_object(
      'success', true,
      'code', v_existing_code,
      'reused', true
    );
  END IF;

  v_generated := public.generate_verification_code(v_user_id, 'password_reset');

  IF coalesce((v_generated->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_generated;
  END IF;

  RETURN json_build_object(
    'success', true,
    'code', v_generated->>'code',
    'reused', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_password_reset_code(text) TO anon, authenticated;

COMMIT;
