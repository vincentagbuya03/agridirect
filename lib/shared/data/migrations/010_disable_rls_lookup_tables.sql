-- ============================================================================
-- Disable RLS on categories and units tables
-- These are public lookup tables that should be readable by everyone
-- ============================================================================

-- Disable RLS on categories
ALTER TABLE categories DISABLE ROW LEVEL SECURITY;

-- Disable RLS on units
ALTER TABLE units DISABLE ROW LEVEL SECURITY;
