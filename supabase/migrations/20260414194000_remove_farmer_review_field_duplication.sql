-- Migration: Remove duplicated farmer review fields from farmers
-- Purpose:
--   - Keep review metadata in farmer_registrations only
--   - Preserve existing review data by backfilling latest registration rows first

BEGIN;

-- Backfill latest registration row per farmer using existing farmers review data.
WITH latest_registration AS (
  SELECT DISTINCT ON (fr.farmer_id)
    fr.registration_id,
    fr.farmer_id
  FROM farmer_registrations fr
  ORDER BY fr.farmer_id, fr.created_at DESC, fr.updated_at DESC
)
UPDATE farmer_registrations fr
SET
  reviewed_by = COALESCE(fr.reviewed_by, f.reviewed_by_admin_id),
  review_notes = COALESCE(fr.review_notes, f.review_notes),
  updated_at = now()
FROM latest_registration lr
JOIN farmers f ON f.farmer_id = lr.farmer_id
WHERE fr.registration_id = lr.registration_id
  AND (f.reviewed_by_admin_id IS NOT NULL OR f.review_notes IS NOT NULL);

-- Remove duplicated fields from farmers.
ALTER TABLE farmers
  DROP COLUMN IF EXISTS reviewed_by_admin_id,
  DROP COLUMN IF EXISTS review_notes;

COMMIT;
