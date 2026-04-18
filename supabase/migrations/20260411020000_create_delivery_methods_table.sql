-- Migration: Create delivery_methods lookup table
-- Purpose: Replace orders.delivery_method (text) with FK to delivery_methods
-- Timeline: Safe transition using parallel columns
-- Created: April 11, 2026

-- Step 1: Create delivery_methods lookup table
CREATE TABLE IF NOT EXISTS delivery_methods (
  delivery_method_id SMALLINT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON TABLE delivery_methods IS 
'Lookup table for delivery method types. Single source of truth for valid delivery methods.';

-- Step 2: Seed with existing values from orders.delivery_method
INSERT INTO delivery_methods (delivery_method_id, code, description, is_active)
VALUES 
  (1, 'delivery', 'Farmer delivers to customer address', true),
  (2, 'pickup', 'Customer picks up from farm location', true)
ON CONFLICT (delivery_method_id) DO NOTHING;

-- Step 3: Add delivery_method_id column to orders (nullable for safety during transition)
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS delivery_method_id SMALLINT;

-- Step 4: Add FK constraint (deferred to allow data migration)
ALTER TABLE orders
ADD CONSTRAINT fk_orders_delivery_method FOREIGN KEY (delivery_method_id)
  REFERENCES delivery_methods(delivery_method_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- Step 5: Migrate data from text column to FK
-- Map existing delivery_method values to delivery_method_id
UPDATE orders
SET delivery_method_id = CASE 
  WHEN delivery_method = 'delivery' THEN 1
  WHEN delivery_method = 'pickup' THEN 2
  ELSE 1  -- Default to 'delivery' for any other values
END
WHERE delivery_method_id IS NULL AND delivery_method IS NOT NULL;

-- Step 6: Set default for new records
ALTER TABLE orders
ALTER COLUMN delivery_method_id SET DEFAULT 1;

-- Step 7: Add deprecation comment to old column
COMMENT ON COLUMN orders.delivery_method IS
'⚠️ DEPRECATED - Use delivery_method_id and join with delivery_methods table instead.
This column will be removed after apps fully migrate to the FK approach.
Deprecated: 2026-04-11';

-- Step 8: Create view for backward compatibility (optional, for gradual migration)
CREATE OR REPLACE VIEW v_orders_with_delivery_method AS
SELECT 
  o.*,
  dm.code AS delivery_method_code,
  dm.description AS delivery_method_description
FROM orders o
LEFT JOIN delivery_methods dm ON o.delivery_method_id = dm.delivery_method_id;

-- Migration guide:
-- Old: SELECT * FROM orders WHERE delivery_method = 'delivery'
-- New: SELECT * FROM orders WHERE delivery_method_id = 1
-- Or use the view: SELECT * FROM v_orders_with_delivery_method WHERE delivery_method_code = 'delivery'

-- Rollback note: To rollback, preserve old data first:
-- ALTER TABLE orders DROP CONSTRAINT fk_orders_delivery_method;
-- ALTER TABLE orders DROP COLUMN delivery_method_id;
-- DROP TABLE IF EXISTS delivery_methods;
