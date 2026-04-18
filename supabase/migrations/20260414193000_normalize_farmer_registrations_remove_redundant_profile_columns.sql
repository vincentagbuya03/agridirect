-- Migration: Normalize farmer_registrations by removing duplicated profile columns
-- Purpose:
--   - Keep farmers as the single source of truth for farmer profile data
--   - Keep farmer_registrations as workflow/audit table only

BEGIN;

-- Backfill farmer_id for any legacy rows that only had user_id.
UPDATE farmer_registrations fr
SET farmer_id = f.farmer_id
FROM farmers f
WHERE fr.farmer_id IS NULL
  AND fr.user_id IS NOT NULL
  AND f.user_id = fr.user_id;

-- Remove rows that cannot be linked to a farmer profile.
DELETE FROM farmer_registrations
WHERE farmer_id IS NULL;

-- Enforce normalized constraints.
ALTER TABLE farmer_registrations
  ALTER COLUMN farmer_id SET NOT NULL;

-- Drop duplicated profile columns from workflow table.
ALTER TABLE farmer_registrations
  DROP COLUMN IF EXISTS user_id,
  DROP COLUMN IF EXISTS birth_date,
  DROP COLUMN IF EXISTS years_of_experience,
  DROP COLUMN IF EXISTS residential_address,
  DROP COLUMN IF EXISTS farm_name,
  DROP COLUMN IF EXISTS specialty,
  DROP COLUMN IF EXISTS face_photo_path,
  DROP COLUMN IF EXISTS valid_id_path,
  DROP COLUMN IF EXISTS farming_history,
  DROP COLUMN IF EXISTS certification_accepted;

COMMIT;
