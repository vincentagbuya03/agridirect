-- Migration: Apply Server-Side Rate Limiting to OTP Generation
-- Purpose:
--   - Protects the `generate_verification_code` RPC from brute-force spam.
--   - Reuses the `security_rate_limits` table to track OTP requests per user.
--   - Enforces a max of 5 requests per 15-minute window, with a 30-minute penalty block.

BEGIN;

CREATE OR REPLACE FUNCTION generate_verification_code(p_user_id uuid, p_type text)
RETURNS json AS $$
DECLARE
  v_code text;
  v_expires timestamptz := now() + interval '10 minutes';
  v_type text := lower(trim(p_type));
  
  -- Rate limiting variables
  v_rate_key text := 'generate_otp:user:' || p_user_id::text;
  v_action text := 'generate_otp';
  v_max_attempts int := 5;
  v_window interval := interval '15 minutes';
  v_block interval := interval '30 minutes';
  v_attempt_count int;
  v_window_started_at timestamptz;
  v_blocked_until timestamptz;
BEGIN
  IF v_type NOT IN ('email', 'phone', 'password_reset', 'two_factor') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid verification type', 'type', p_type);
  END IF;

  -- 1. Check Rate Limits
  SELECT attempt_count, window_started_at, blocked_until
  INTO v_attempt_count, v_window_started_at, v_blocked_until
  FROM security_rate_limits
  WHERE rate_key = v_rate_key FOR UPDATE;

  IF FOUND THEN
    -- If currently blocked, reject immediately
    IF v_blocked_until IS NOT NULL AND v_blocked_until > now() THEN
      RETURN json_build_object(
        'success', false, 
        'message', 'Too many OTP requests. Please try again later.',
        'retry_after_seconds', EXTRACT(EPOCH FROM (v_blocked_until - now()))::int
      );
    END IF;

    -- Update tracking window
    IF now() - v_window_started_at < v_window THEN
      v_attempt_count := v_attempt_count + 1;
    ELSE
      v_attempt_count := 1;
      v_window_started_at := now();
      v_blocked_until := NULL;
    END IF;

    -- Enforce block if attempts exceeded
    IF v_attempt_count > v_max_attempts THEN
      v_blocked_until := now() + v_block;
      
      UPDATE security_rate_limits
      SET attempt_count = v_attempt_count,
          window_started_at = v_window_started_at,
          blocked_until = v_blocked_until,
          last_attempt_at = now(),
          updated_at = now()
      WHERE rate_key = v_rate_key;

      RETURN json_build_object(
        'success', false, 
        'message', 'Too many OTP requests. Please try again later.',
        'retry_after_seconds', EXTRACT(EPOCH FROM v_block)::int
      );
    ELSE
      -- Register valid attempt
      UPDATE security_rate_limits
      SET attempt_count = v_attempt_count,
          window_started_at = v_window_started_at,
          last_attempt_at = now(),
          updated_at = now()
      WHERE rate_key = v_rate_key;
    END IF;
  ELSE
    -- First time tracking this user's OTP requests
    INSERT INTO security_rate_limits (rate_key, action, attempt_count, window_started_at, last_attempt_at)
    VALUES (v_rate_key, v_action, 1, now(), now());
  END IF;

  -- 2. Generate and Store OTP
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

COMMIT;
