-- Migration: Use reviewed_by_admin_id for farmer reviews
-- Purpose:
--   - Replace legacy reviewed_by_user_id on farmers with reviewed_by_admin_id
--   - Keep the farmer owner relation separate via farmers.user_id
--   - Remove ambiguous user-to-farmer reviewer embedding

BEGIN;

ALTER TABLE farmers
  ADD COLUMN IF NOT EXISTS reviewed_by_admin_id uuid,
  ADD COLUMN IF NOT EXISTS review_notes text;

UPDATE farmers f
SET reviewed_by_admin_id = COALESCE(f.reviewed_by_admin_id, a.admin_id)
FROM admins a
WHERE a.user_id = f.reviewed_by_user_id
  AND f.reviewed_by_admin_id IS NULL;

ALTER TABLE farmers
  DROP CONSTRAINT IF EXISTS fk_farmers_reviewed_by_user;

ALTER TABLE farmers
  DROP CONSTRAINT IF EXISTS fk_farmers_reviewed_by_admin,
  ADD CONSTRAINT fk_farmers_reviewed_by_admin
  FOREIGN KEY (reviewed_by_admin_id)
  REFERENCES admins(admin_id)
  ON DELETE SET NULL;

ALTER TABLE farmers
  DROP COLUMN IF EXISTS reviewed_by_user_id;

COMMENT ON COLUMN farmers.reviewed_by_admin_id IS
  'Admin who reviewed or approved the farmer profile. Separate from farmers.user_id, which stores the farmer owner account.';

COMMIT;
