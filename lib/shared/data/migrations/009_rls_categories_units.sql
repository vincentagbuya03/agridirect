-- ============================================================================
-- Migration: Enable RLS and add read policies for categories and units tables
-- ============================================================================
-- Purpose: Allow authenticated users to read categories and units
-- These are lookup tables that should be readable by all users
-- ============================================================================

-- Enable RLS on categories table
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all users to read categories
CREATE POLICY "Allow all users to read categories"
  ON categories FOR SELECT
  USING (true);

-- Enable RLS on units table
ALTER TABLE units ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all users to read units
CREATE POLICY "Allow all users to read units"
  ON units FOR SELECT
  USING (true);

-- ============================================================================
-- Verification:
-- These policies allow any user (authenticated or anonymous) to SELECT from
-- categories and units tables, which is necessary for the Add Product form
-- to populate the dropdowns with available categories and units.
-- ============================================================================
