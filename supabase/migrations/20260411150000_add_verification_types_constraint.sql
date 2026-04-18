-- Migration: Add verification_types lookup table and FK constraint
-- Purpose: Constrain verification_codes.verification_type to valid values (email, phone)
-- Created: April 11, 2026

-- Step 1: Create verification_types lookup table
CREATE TABLE IF NOT EXISTS verification_types (
  verification_type_id SMALLINT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON TABLE verification_types IS
'Lookup table for verification code types. Tracks what type of verification is being performed.';

-- Step 2: Seed with standard verification types
INSERT INTO verification_types (verification_type_id, code, description, is_active)
VALUES
  (1, 'email', 'Email address verification via code', true),
  (2, 'phone', 'Phone number verification via SMS code', true),
  (3, 'password_reset', 'Password reset request verification', true),
  (4, 'two_factor', 'Two-factor authentication code', true)
ON CONFLICT (verification_type_id) DO NOTHING;

-- Step 3: Add new verification_type_id column to verification_codes table
ALTER TABLE verification_codes
ADD COLUMN IF NOT EXISTS verification_type_id SMALLINT;

-- Step 4: Migrate data from text verification_type to FK
UPDATE verification_codes
SET verification_type_id = vt.verification_type_id
FROM verification_types vt
WHERE verification_codes.verification_type = vt.code 
  AND verification_codes.verification_type_id IS NULL
  AND verification_codes.verification_type IS NOT NULL;

-- Step 5: Handle any unmatched values (set to 'email' as default if exists)
UPDATE verification_codes
SET verification_type_id = 1  -- email as default
WHERE verification_type_id IS NULL 
  AND verification_type IS NOT NULL;

-- Step 6: Add FK constraint
ALTER TABLE verification_codes
ADD CONSTRAINT fk_verification_codes_type_id
FOREIGN KEY (verification_type_id)
REFERENCES verification_types(verification_type_id)
ON DELETE RESTRICT ON UPDATE CASCADE;

-- Step 7: Make verification_type_id NOT NULL
-- Update any remaining NULLs first
UPDATE verification_codes
SET verification_type_id = 1
WHERE verification_type_id IS NULL;

ALTER TABLE verification_codes
ALTER COLUMN verification_type_id SET NOT NULL;

-- Step 8: Update column documentation
COMMENT ON COLUMN verification_codes.verification_type_id IS
'FK to verification_types lookup table. NOT NULL - all codes must specify verification type.
Valid types: 1=email, 2=phone, 3=password_reset, 4=two_factor.
This is the primary way we track verification type; legacy text column kept for backward compatibility.';

COMMENT ON COLUMN verification_codes.verification_type IS
'Legacy text column for backward compatibility. Use verification_type_id FK instead.
Will be deprecated and removed in a future migration.';

-- Step 9: Update table comment
COMMENT ON TABLE verification_codes IS
'User verification codes for email, phone, password reset, and 2FA.
Every code MUST specify a verification type via verification_type_id FK.
Constraint: verification_type_id NOT NULL enforces all codes have a type.
Constraint: fk_verification_codes_type_id ensures only valid types are used.';

-- Queries to verify after migration:
-- 1. Check verification type distribution:
--    SELECT vt.code, COUNT(*) as count
--    FROM verification_codes vc
--    JOIN verification_types vt ON vc.verification_type_id = vt.verification_type_id
--    GROUP BY vt.code;
-- 2. Find pending verifications:
--    SELECT * FROM verification_codes WHERE expires_at > now() ORDER BY created_at DESC;
-- 3. Find by type:
--    SELECT * FROM verification_codes WHERE verification_type_id = 1 LIMIT 20;

-- Future cleanup (after transition period):
-- ALTER TABLE verification_codes DROP COLUMN verification_type;

-- Rollback note:
-- ALTER TABLE verification_codes DROP CONSTRAINT fk_verification_codes_type_id;
-- ALTER TABLE verification_codes ALTER COLUMN verification_type_id DROP NOT NULL;
-- ALTER TABLE verification_codes DROP COLUMN verification_type_id;
-- DROP TABLE verification_types;
