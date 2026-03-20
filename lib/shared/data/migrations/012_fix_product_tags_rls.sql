-- ============================================================================
-- Migration: Fix product_tags RLS permissions
-- ============================================================================
-- Purpose: Fix "permission denied for table product_tags" error
-- The product_tags table is a reference/lookup table that all authenticated
-- users should be able to read without restrictions
-- ============================================================================

-- Step 1: Disable RLS on product_tags table (recommended for lookup tables)
ALTER TABLE product_tags DISABLE ROW LEVEL SECURITY;

-- Step 2: Disable RLS on product_tag_mappings table
ALTER TABLE product_tag_mappings DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Verification
-- ============================================================================
-- After running this migration, the following should succeed:
-- SELECT * FROM product_tags;
-- SELECT * FROM product_tag_mappings;
-- ============================================================================
