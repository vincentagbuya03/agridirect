-- Password Reset Codes Table
-- Stores temporary verification codes for password reset

CREATE TABLE IF NOT EXISTS password_reset_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_email ON password_reset_codes(email);
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_code ON password_reset_codes(code);
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_expires ON password_reset_codes(expires_at);

-- Auto-delete expired codes (optional, for cleanup)
CREATE OR REPLACE FUNCTION delete_expired_reset_codes()
RETURNS void AS $$
BEGIN
  DELETE FROM password_reset_codes
  WHERE expires_at < NOW() OR used = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access
GRANT ALL ON password_reset_codes TO authenticated;
GRANT ALL ON password_reset_codes TO anon;

ALTER TABLE password_reset_codes ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own reset codes"
  ON password_reset_codes FOR SELECT
  USING (auth.email() = email);

CREATE POLICY "Anyone can create reset codes"
  ON password_reset_codes FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update their own reset codes"
  ON password_reset_codes FOR UPDATE
  USING (auth.email() = email);
