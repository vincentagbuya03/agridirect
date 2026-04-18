-- Migration: Add persistent rate-limit table for security-sensitive actions
-- Purpose:
--   - Enable brute-force protection for Edge Functions (e.g., password reset code verification)
--   - Track attempts by scoped key (ip/email hash/action)

BEGIN;

CREATE TABLE IF NOT EXISTS security_rate_limits (
  rate_key text PRIMARY KEY,
  action text NOT NULL,
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  window_started_at timestamptz NOT NULL DEFAULT now(),
  blocked_until timestamptz,
  last_attempt_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_security_rate_limits_action
  ON security_rate_limits(action);

CREATE INDEX IF NOT EXISTS idx_security_rate_limits_blocked_until
  ON security_rate_limits(blocked_until);

COMMIT;
