-- Migration to remove obsolete visual columns from categories table
-- These are now handled dynamically on the frontend to maintain 3NF compliance.

ALTER TABLE categories DROP COLUMN IF EXISTS icon;
ALTER TABLE categories DROP COLUMN IF EXISTS image_url;
