-- Migration: Make reported_content.content_type_id NOT NULL and add status constraint
-- Purpose: Enforce data integrity - all reports must have a content type and valid status
-- Context: Old content_type text column was dropped in 20260411110000, so content_type_id is now the only column
-- Created: April 11, 2026

-- Step 1: Add CHECK constraint for status values
-- Valid statuses: pending, resolved, dismissed
ALTER TABLE reported_content
ADD CONSTRAINT check_reported_content_status
CHECK (status IN ('pending', 'resolved', 'dismissed'));

-- Step 2: Make content_type_id NOT NULL
-- First, verify no NULL values exist (safety check)
-- SELECT COUNT(*) as null_content_types FROM reported_content WHERE content_type_id IS NULL;

-- Update any NULL content_type_id to 1 (post) as default if any exist
UPDATE reported_content
SET content_type_id = 1
WHERE content_type_id IS NULL;

-- Now add the NOT NULL constraint
ALTER TABLE reported_content
ALTER COLUMN content_type_id SET NOT NULL;

-- Step 3: Update column comments to reflect constraints
COMMENT ON COLUMN reported_content.content_type_id IS
'FK to content_types lookup table. NOT NULL - all reports must specify content type.
Valid types: 1=post, 2=comment, 3=product, 4=review.
Constraint ensures only valid content type IDs are allowed.';

COMMENT ON COLUMN reported_content.status IS
'Status of the report. Must be one of: pending, resolved, dismissed.
- pending: Report received, awaiting review
- resolved: Issue addressed, content removed or user warned
- dismissed: Report reviewed, determined to not violate policy
Constraint: check_reported_content_status enforces valid values.';

-- Step 4: Update table comment
COMMENT ON TABLE reported_content IS
'User reports for policy violations (offensive content, spam, etc).
Every report MUST have a content type (content_type_id NOT NULL) and valid status.
Constraints:
- content_type_id NOT NULL (all reports must specify what type of content)
- status IN (''pending'', ''resolved'', ''dismissed'') (valid status tracking)
- content_type_id FK to content_types (enforces valid content types)';

-- Queries to verify after migration:
-- 1. Check status distribution:
--    SELECT status, COUNT(*) as count FROM reported_content GROUP BY status;
-- 2. Check content type distribution:
--    SELECT ct.code, COUNT(*) as count
--    FROM reported_content rc
--    JOIN content_types ct ON rc.content_type_id = ct.content_type_id
--    GROUP BY ct.code;
-- 3. Find reports by status:
--    SELECT * FROM reported_content WHERE status = 'pending' ORDER BY created_at DESC;

-- Rollback note:
-- ALTER TABLE reported_content DROP CONSTRAINT check_reported_content_status;
-- ALTER TABLE reported_content ALTER COLUMN content_type_id DROP NOT NULL;
