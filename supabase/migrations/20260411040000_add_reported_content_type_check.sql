-- Migration: Add CHECK constraint on reported_content.content_type
-- Purpose: Restrict content_type to only known/valid types
-- Valid types: 'post', 'comment', 'product', 'review'
-- Created: April 11, 2026

-- Step 1: Create content_types lookup table for future extensibility
CREATE TABLE IF NOT EXISTS content_types (
  content_type_id SMALLINT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON TABLE content_types IS
'Lookup table for reportable content types. Single source of truth for valid content types.';

-- Step 2: Seed with known content types
INSERT INTO content_types (content_type_id, code, description, is_active)
VALUES
  (1, 'post', 'Forum posts', true),
  (2, 'comment', 'Forum comments', true),
  (3, 'product', 'Product listings', true),
  (4, 'review', 'Product/Farmer reviews', true)
ON CONFLICT (content_type_id) DO NOTHING;

-- Step 3: Add CHECK constraint to reported_content
-- Restricts content_type to only these known values
ALTER TABLE reported_content
ADD CONSTRAINT check_reported_content_type_valid
CHECK (content_type IN ('post', 'comment', 'product', 'review'));

COMMENT ON CONSTRAINT check_reported_content_type_valid ON reported_content IS
'Ensures content_type is one of the valid, known types: post, comment, product, review.
Prevents invalid/typo content types from being stored.';

-- Step 4: Verify no existing invalid records
-- If this query returns rows, those records violate the constraint
-- They must be cleaned up or updated before the constraint becomes fully active
SELECT DISTINCT content_type, COUNT(*) as count
FROM reported_content
WHERE content_type NOT IN ('post', 'comment', 'product', 'review')
GROUP BY content_type;

-- If invalid records exist, either:
-- A) Update content_type to the correct valid value
-- B) Delete the invalid report if it's spam/invalid
-- Example: UPDATE reported_content SET content_type = 'post' WHERE content_type = 'forum_post';

-- Step 5: Optional - add FK to content_types table for stricter enforcement
-- Uncomment if you want to use the lookup table approach instead of CHECK constraint:
-- ALTER TABLE reported_content 
-- ADD COLUMN content_type_id SMALLINT;
-- ALTER TABLE reported_content 
-- ADD CONSTRAINT fk_reported_content_type 
--   FOREIGN KEY (content_type_id) REFERENCES content_types(content_type_id);

-- Migration guide:
-- Valid reports:
-- INSERT INTO reported_content (reporter_id, content_type, content_id, reason, status)
--   VALUES (..., 'post', '123e4567-...', 'Spam', 'pending');
-- INSERT INTO reported_content (reporter_id, content_type, content_id, reason)
--   VALUES (..., 'review', '456e7890-...', 'Offensive language');

-- Invalid report (will FAIL):
-- INSERT INTO reported_content (reporter_id, content_type, content_id, reason)
--   VALUES (..., 'forum_post', '123e4567-...', 'Spam');  -- ERROR: violates check constraint

-- Adding new content type (if needed):
-- 1. Add to content_types table
-- 2. Update CHECK constraint
-- 3. Deploy both changes together

-- Rollback note:
-- ALTER TABLE reported_content DROP CONSTRAINT check_reported_content_type_valid;
-- DROP TABLE IF EXISTS content_types;
