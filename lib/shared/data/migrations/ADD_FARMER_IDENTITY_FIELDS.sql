-- Migration to add identity verification fields to the farmers table
-- This supports the PhilSys National ID integration and automated verification

ALTER TABLE farmers 
ADD COLUMN IF NOT EXISTS id_type TEXT,
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS sex TEXT,
ADD COLUMN IF NOT EXISTS place_of_birth TEXT,
ADD COLUMN IF NOT EXISTS pcn TEXT;

-- Comment for documentation
COMMENT ON COLUMN farmers.id_type IS 'Type of ID used for registration (e.g., national_id, local_id)';
COMMENT ON COLUMN farmers.full_name IS 'Verified legal full name extracted from the identity document';
COMMENT ON COLUMN farmers.sex IS 'Verified sex from identity document';
COMMENT ON COLUMN farmers.place_of_birth IS 'Verified place of birth from identity document';
COMMENT ON COLUMN farmers.pcn IS 'PhilSys Card Number (PCN) for National ID verification';
