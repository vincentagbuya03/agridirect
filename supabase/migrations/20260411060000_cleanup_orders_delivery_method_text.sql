-- Migration: Drop old orders.delivery_method text column
-- Purpose: Remove duplicate/old delivery_method column now that delivery_method_id FK is in place
-- Safety: All data should be migrated to delivery_method_id before dropping
-- Created: April 11, 2026

-- Step 1: Drop dependent views first
DROP VIEW IF EXISTS v_orders_with_delivery_method CASCADE;

-- Step 2: Add any missing delivery_method_id mappings from old text values (if needed)
-- This is a safety measure if some rows still have NULL delivery_method_id
UPDATE orders
SET delivery_method_id = CASE 
  WHEN delivery_method ILIKE '%delivery%' THEN 1
  WHEN delivery_method ILIKE '%pickup%' THEN 2
  ELSE NULL
END
WHERE delivery_method_id IS NULL AND delivery_method IS NOT NULL;

-- Step 3: Drop the old delivery_method text column
ALTER TABLE orders
DROP COLUMN IF EXISTS delivery_method;

-- Step 4: Recreate the view using the new FK column (if needed)
CREATE OR REPLACE VIEW v_orders_with_delivery_method AS
SELECT 
  o.*,
  dm.code as delivery_method
FROM orders o
LEFT JOIN delivery_methods dm ON o.delivery_method_id = dm.delivery_method_id;

COMMENT ON TABLE orders IS
'Updated: Removed legacy delivery_method text column. All delivery method tracking now done via delivery_method_id FK to delivery_methods table.';

COMMENT ON VIEW v_orders_with_delivery_method IS
'Backward compatibility view. Maps delivery_method_id (FK) back to delivery_method (text code) for consistency.';

-- Rollback note:
-- ALTER TABLE orders ADD COLUMN delivery_method TEXT;
-- UPDATE orders SET delivery_method = dm.code FROM delivery_methods dm WHERE delivery_method_id = dm.delivery_method_id;
-- DROP VIEW v_orders_with_delivery_method;
