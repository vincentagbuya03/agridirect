-- Migration: Remove deprecated registration_status_id columns from farmers table
-- Purpose: Complete deprecation by dropping the columns entirely (not just marking deprecated)
-- Note: Use registration_status view or trigger if status tracking is still needed elsewhere
-- Created: April 11, 2026

-- Step 1: Check if any data still references the old registration_status_id
-- This is informational only - helps understand what was in there
-- SELECT registration_status_id, COUNT(*) FROM farmers GROUP BY registration_status_id;

-- Step 2: Drop the deprecated columns
ALTER TABLE farmers
DROP COLUMN IF EXISTS registration_status_id CASCADE;

ALTER TABLE farmers
DROP COLUMN IF EXISTS registration_status_id_deprecated_at;

-- Step 3: Update table comment
COMMENT ON TABLE farmers IS
'Farmer profiles. Registration status is now tracked via farmer_registrations table and v_farmer_profiles view. 
Deprecated: registration_status_id was removed in favor of registration_status view/table approach.';

-- Migration history note:
-- 1. registration_status_id was originally in farmers table
-- 2. Created farmer_registrations table to properly track registration workflow
-- 3. Marked as deprecated with registration_status_id_deprecated_at timestamp
-- 4. Now removing entirely as all registrations tracked via farmer_registrations table

-- Queries to verify registration status tracking still works:
-- 1. Get farmer registration details:
--    SELECT f.farmer_id, f.farm_name, fr.status, fr.submitted_at, fr.verified_at, fr.notes
--    FROM farmers f
--    LEFT JOIN farmer_registrations fr ON f.farmer_id = fr.farmer_id
--    WHERE fr.id = (SELECT MAX(id) FROM farmer_registrations WHERE farmer_id = f.farmer_id);
-- 2. Use the view:
--    SELECT * FROM v_farmer_profiles WHERE is_verified = true;

-- Rollback note (if needed, restore from backup):
-- ALTER TABLE farmers ADD COLUMN registration_status_id SMALLINT;
-- ALTER TABLE farmers ADD COLUMN registration_status_id_deprecated_at TIMESTAMP WITH TIME ZONE;
-- This would require restoring data mapping from farmer_registrations table if not available elsewhere
