-- Migration: Remove parent_category_id (hierarchical categories) from categories table
-- Rationale: Categories are now flat lookups without hierarchy support
-- Date: April 17, 2026

BEGIN;

-- Drop the self-referencing foreign key and column
ALTER TABLE categories DROP COLUMN IF EXISTS parent_category_id;

COMMIT;
