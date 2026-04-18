-- Migration: Drop old reported_content.content_type text column
-- Purpose: Remove duplicate/old content_type column now that content_type_id FK is in place
-- Prerequisite: content_type_id FK and CHECK constraint already in place from migration 20260411090000
-- Created: April 11, 2026

-- Step 1: Verify all content_type_id values are populated (safety check)
-- SELECT COUNT(*) as missing_content_type_id FROM reported_content WHERE content_type_id IS NULL;

-- Step 2: Drop the old content_type text column
ALTER TABLE reported_content
DROP COLUMN IF EXISTS content_type;

-- Step 3: Update table comment
COMMENT ON TABLE reported_content IS
'User-reported content (posts, comments, products, reviews). All content type tracking now done via content_type_id FK to content_types table.
Tracks status (pending, reviewing, resolved, dismissed) and includes detail notes and reporter block status.';

COMMENT ON COLUMN reported_content.content_type_id IS
'FK to content_types lookup table. Tracks what type of content is being reported (1=post, 2=comment, 3=product, 4=review).
This is the primary way we track content type; legacy text column has been removed.';

-- Queries to verify after migration:
-- 1. Check content type distribution:
--    SELECT ct.code, COUNT(*) as report_count
--    FROM reported_content rc
--    JOIN content_types ct ON rc.content_type_id = ct.content_type_id
--    GROUP BY ct.code;
-- 2. View recent reports:
--    SELECT rc.id, ct.code as content_type, rc.status, rc.notes
--    FROM reported_content rc
--    JOIN content_types ct ON rc.content_type_id = ct.content_type_id
--    ORDER BY rc.created_at DESC LIMIT 20;

-- Rollback note:
-- ALTER TABLE reported_content ADD COLUMN content_type TEXT;
-- UPDATE reported_content SET content_type = ct.code FROM content_types ct WHERE content_type_id = ct.content_type_id;
