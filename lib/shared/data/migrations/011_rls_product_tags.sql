-- ============================================================================
-- Migration: Disable RLS on product_tags (lookup/reference table)
-- ============================================================================
-- Purpose: Product tags are reference data that all users should read without restrictions
-- RLS is not needed since tags are not sensitive data
-- ============================================================================

-- Disable RLS on product_tags table (simpler approach - lookup tables don't need RLS)
ALTER TABLE product_tags DISABLE ROW LEVEL SECURITY;

-- Disable RLS on product_tag_mappings table (users need to see tag associations)
ALTER TABLE product_tag_mappings DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- If you prefer to keep RLS enabled, use these policies instead:
-- ============================================================================
/*
-- Enable RLS on product_tags table
ALTER TABLE product_tags ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all users to read product tags
DROP POLICY IF EXISTS "Allow all users to read product tags" ON product_tags;
CREATE POLICY "Allow all users to read product tags"
  ON product_tags FOR SELECT
  USING (true);

-- Enable RLS on product_tag_mappings table (junction table)
ALTER TABLE product_tag_mappings ENABLE ROW LEVEL SECURITY;

-- Policy: Allow users to read product tag mappings
DROP POLICY IF EXISTS "Allow users to read product tag mappings" ON product_tag_mappings;
CREATE POLICY "Allow users to read product tag mappings"
  ON product_tag_mappings FOR SELECT
  USING (true);

-- Policy: Allow farmers to insert tag mappings for their products
DROP POLICY IF EXISTS "Farmers can add tags to their products" ON product_tag_mappings;
CREATE POLICY "Farmers can add tags to their products"
  ON product_tag_mappings FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM products
      WHERE products.product_id = product_tag_mappings.product_id
        AND products.farmer_id = auth.uid()
    )
  );

-- Policy: Allow farmers to delete tag mappings from their products
DROP POLICY IF EXISTS "Farmers can remove tags from their products" ON product_tag_mappings;
CREATE POLICY "Farmers can remove tags from their products"
  ON product_tag_mappings FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM products
      WHERE products.product_id = product_tag_mappings.product_id
        AND products.farmer_id = auth.uid()
    )
  );
*/

-- ============================================================================
-- Verification:
-- product_tags and product_tag_mappings tables now have no RLS restrictions
-- ============================================================================
