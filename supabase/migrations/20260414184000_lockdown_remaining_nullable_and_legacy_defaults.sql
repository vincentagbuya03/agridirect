-- Migration: Lock down remaining nullable and legacy-default anomalies
-- Purpose:
--   - Remove legacy default from verification_codes.verification_type
--   - Enforce NOT NULL on farmer_ratings.order_id
--   - Enforce NOT NULL on reported_content.reporter_id

BEGIN;

-- 1) verification_codes.verification_type should not have a legacy marker default.
ALTER TABLE verification_codes
  ALTER COLUMN verification_type DROP DEFAULT;

-- Normalize any unexpected values before enforcing the CHECK again.
UPDATE verification_codes
SET verification_type = CASE
  WHEN lower(coalesce(verification_type, '')) IN ('email', 'phone', 'password_reset', 'two_factor') THEN lower(verification_type)
  WHEN verification_type IS NULL THEN 'email'
  ELSE 'email'
END;

ALTER TABLE verification_codes
  DROP CONSTRAINT IF EXISTS verification_codes_verification_type_check,
  ADD CONSTRAINT verification_codes_verification_type_check
  CHECK (verification_type IN ('email', 'phone', 'password_reset', 'two_factor'));

-- 2) farmer_ratings.order_id must be present for referential traceability.
-- If any NULLs exist, map them to a deterministic order owned by the same customer/farmer pair.
DO $$
DECLARE
  v_rating_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM farmer_ratings WHERE order_id IS NULL) THEN
    FOR v_rating_id IN
      SELECT fr.rating_id
      FROM farmer_ratings fr
      WHERE fr.order_id IS NULL
    LOOP
      UPDATE farmer_ratings fr
      SET order_id = (
        SELECT o.order_id
        FROM orders o
        WHERE o.customer_id = fr.customer_id
          AND o.farmer_id = fr.farmer_id
        ORDER BY o.created_at DESC
        LIMIT 1
      )
      WHERE fr.rating_id = v_rating_id
        AND fr.order_id IS NULL;
    END LOOP;
  END IF;
END $$;

-- Remove any rows that still cannot be linked to an order (data corruption edge case).
DELETE FROM farmer_ratings
WHERE order_id IS NULL;

ALTER TABLE farmer_ratings
  ALTER COLUMN order_id SET NOT NULL;

-- 3) reported_content.reporter_id must always be present.
-- Backfill from resolved_by when available, otherwise remove orphaned rows.
UPDATE reported_content
SET reporter_id = resolved_by
WHERE reporter_id IS NULL
  AND resolved_by IS NOT NULL;

DELETE FROM reported_content
WHERE reporter_id IS NULL;

ALTER TABLE reported_content
  ALTER COLUMN reporter_id SET NOT NULL;

COMMIT;
