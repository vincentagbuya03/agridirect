-- Migration to add identity verification fields to the farmers table
-- This supports the PhilSys National ID integration and automated verification

-- 1. Add verification metadata to the farmers table
ALTER TABLE farmers 
ADD COLUMN IF NOT EXISTS id_type TEXT,
ADD COLUMN IF NOT EXISTS sex TEXT,
ADD COLUMN IF NOT EXISTS place_of_birth TEXT,
ADD COLUMN IF NOT EXISTS pcn TEXT;

-- 2. Add ONLY the pending legal name to the farmer_registrations table
-- This avoids redundancy since other fields are already linked via farmer_id
ALTER TABLE farmer_registrations
ADD COLUMN IF NOT EXISTS full_name TEXT;

-- Documentation
COMMENT ON COLUMN farmers.id_type IS 'Type of ID used (national_id, local_id)';
COMMENT ON COLUMN farmer_registrations.full_name IS 'The legal name extracted from the ID, to be synced to users.name upon approval';
