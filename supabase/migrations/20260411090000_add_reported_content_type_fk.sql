-- Migration: Add FK constraint from reported_content.content_type to content_types
-- Purpose: Enforce data integrity by ensuring only valid content types are stored
-- Note: The content_types lookup table was created in earlier migration (20260411040000)
-- Created: April 11, 2026

-- Step 1: Ensure content_types table exists with required data
CREATE TABLE IF NOT EXISTS content_types (
  content_type_id SMALLINT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

INSERT INTO content_types (content_type_id, code, description, is_active)
VALUES
  (1, 'post', 'Community post/discussion', true),
  (2, 'comment', 'Comment on a post or product', true),
  (3, 'product', 'Product listing', true),
  (4, 'review', 'Product or farmer review', true)
ON CONFLICT (content_type_id) DO NOTHING;

-- Step 2: Create new column for FK (avoid dropping and recreating content_type)
ALTER TABLE reported_content
ADD COLUMN IF NOT EXISTS content_type_id SMALLINT;

-- Step 3: Migrate data from text content_type to new FK column
UPDATE reported_content
SET content_type_id = ct.content_type_id
FROM content_types ct
WHERE reported_content.content_type = ct.code 
  AND reported_content.content_type_id IS NULL
  AND reported_content.content_type IS NOT NULL;

-- Step 4: Handle any unmatched values (shouldn't happen if only valid values in DB)
-- Set to NULL if no match found - you may need to review these manually
-- Or set to 1 (post) as default if you prefer
UPDATE reported_content
SET content_type_id = COALESCE(content_type_id, 1)
WHERE content_type_id IS NULL;

-- Step 5: Add FK constraint
ALTER TABLE reported_content
ADD CONSTRAINT fk_reported_content_type_id
FOREIGN KEY (content_type_id)
REFERENCES content_types(content_type_id)
ON DELETE RESTRICT ON UPDATE CASCADE;

-- Step 6: Once all data is migrated and FK works, you can drop the old text column
-- ALTER TABLE reported_content DROP COLUMN content_type;
-- For now, keeping text column for backward compatibility during transition

-- Step 7: Add CHECK to ensure one of them is used (or both during transition)
ALTER TABLE reported_content
ADD CONSTRAINT check_content_type_values
CHECK (content_type_id IS NOT NULL);

COMMENT ON COLUMN reported_content.content_type_id IS
'FK to content_types lookup table. Tracks what type of content is being reported (1=post, 2=comment, 3=product, 4=review).
Primary way to track content type. Legacy content_type text column kept for backward compatibility.';

-- Queries to verify:
-- 1. Check for any missing content_type_id values:
--    SELECT COUNT(*) FROM reported_content WHERE content_type_id IS NULL;
-- 2. Find reports by content type:
--    SELECT ct.code, COUNT(*) as report_count
--    FROM reported_content rc
--    JOIN content_types ct ON rc.content_type_id = ct.content_type_id
--    GROUP BY ct.code;
-- 3. Find unmatched content types:
--    SELECT DISTINCT content_type FROM reported_content
--    WHERE content_type NOT IN (SELECT code FROM content_types);

-- Future cleanup (after transition period):
-- ALTER TABLE reported_content DROP COLUMN content_type;
-- RENAME TABLE reported_content.content_type_id TO content_type;

-- Rollback note:
-- ALTER TABLE reported_content DROP CONSTRAINT check_content_type_values;
-- ALTER TABLE reported_content DROP CONSTRAINT fk_reported_content_type_id;
-- ALTER TABLE reported_content DROP COLUMN content_type_id;
