-- Migration: Add cancelled_by_role column to orders
-- Purpose: Track who cancelled an order (customer, farmer, admin)
-- Complements existing cancelled_by UUID column
-- Created: April 11, 2026

-- Step 1: Create cancellation_roles lookup table
CREATE TABLE IF NOT EXISTS cancellation_roles (
  cancellation_role_id SMALLINT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON TABLE cancellation_roles IS
'Lookup table for who can cancel an order. Tracks the role that initiated cancellation.';

-- Step 2: Seed with valid cancellation roles
INSERT INTO cancellation_roles (cancellation_role_id, code, description, is_active)
VALUES
  (1, 'customer', 'Order cancelled by customer', true),
  (2, 'farmer', 'Order cancelled by farmer', true),
  (3, 'admin', 'Order cancelled by admin/moderator', true),
  (4, 'system', 'Order cancelled by system (e.g., timeout, payment failure)', true)
ON CONFLICT (cancellation_role_id) DO NOTHING;

-- Step 3: Add cancelled_by_role column to orders table
-- Using TEXT for flexibility, or use SMALLINT FK for stricter enforcement
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS cancelled_by_role TEXT;

-- Step 4: Add CHECK constraint to validate role values
ALTER TABLE orders
ADD CONSTRAINT check_cancelled_by_role_valid
CHECK (
  cancelled_by_role IS NULL OR 
  cancelled_by_role IN ('customer', 'farmer', 'admin', 'system')
);

COMMENT ON COLUMN orders.cancelled_by_role IS
'Role that initiated the order cancellation. One of: customer, farmer, admin, system.
Only populated when order_status_id indicates cancelled.
Works with cancelled_by UUID to track both WHO and WHAT ROLE cancelled the order.';

-- Step 5: Add trigger to enforce data consistency
-- Ensure cancelled_by_role is only set when order is actually cancelled
CREATE OR REPLACE FUNCTION validate_cancellation_data()
RETURNS TRIGGER AS $$
BEGIN
  -- If setting cancelled_by_role, ensure cancelled_by is also set
  IF NEW.cancelled_by_role IS NOT NULL AND NEW.cancelled_by IS NULL THEN
    RAISE EXCEPTION 'cancelled_by must be set when cancelled_by_role is specified';
  END IF;
  
  -- If clearing cancellation, clear both columns
  IF NEW.order_status_id != 6 AND NEW.cancelled_by IS NOT NULL THEN
    -- Status 6 is typically 'cancelled', adjust if different in your system
    -- This is a safety measure - commented out to not break existing logic
    -- NEW.cancelled_by := NULL;
    -- NEW.cancelled_by_role := NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS orders_cancellation_validation ON orders;
CREATE TRIGGER orders_cancellation_validation
BEFORE UPDATE ON orders
FOR EACH ROW
WHEN (OLD.cancelled_by IS DISTINCT FROM NEW.cancelled_by OR 
      OLD.cancelled_by_role IS DISTINCT FROM NEW.cancelled_by_role)
EXECUTE FUNCTION validate_cancellation_data();

-- Step 6: Optional - Create better tracking view
CREATE OR REPLACE VIEW v_cancelled_orders AS
SELECT 
  o.order_id,
  o.order_number,
  o.customer_id,
  o.farmer_id,
  o.cancelled_by,
  o.cancelled_by_role,
  o.cancellation_reason,
  cr.description AS cancellation_role_description,
  o.updated_at AS cancelled_at
FROM orders o
LEFT JOIN cancellation_roles cr ON o.cancelled_by_role = cr.code
WHERE o.order_status_id = 6;  -- Adjust status ID if different

-- Migration guide:
-- When cancelling an order, set BOTH columns:
-- UPDATE orders 
-- SET 
--   order_status_id = 6,  -- 'cancelled'
--   cancelled_by = auth.uid(),
--   cancelled_by_role = 'customer',
--   cancellation_reason = 'Changed my mind'
-- WHERE order_id = '123e4567-...';

-- Queries:
-- 1. Find customer-cancelled orders:
--    SELECT * FROM orders WHERE cancelled_by_role = 'customer';
-- 2. Find orders cancelled by specific farmer:
--    SELECT * FROM orders WHERE cancelled_by_role = 'farmer' AND cancelled_by = 'farmer-uuid';
-- 3. Track cancellation patterns:
--    SELECT cancelled_by_role, COUNT(*) as count FROM orders WHERE order_status_id = 6 GROUP BY cancelled_by_role;
-- 4. Use the view:
--    SELECT * FROM v_cancelled_orders WHERE cancelled_by_role = 'admin';

-- Data backfill (if migrating from old system without this data):
-- You may need to infer the role based on who made the cancellation:
-- UPDATE orders 
-- SET cancelled_by_role = 'customer'
-- WHERE cancelled_by IS NOT NULL 
--   AND cancelled_by IN (SELECT user_id FROM users WHERE user_id = any(SELECT customer_id FROM customers))
--   AND order_status_id = 6;

-- Rollback note:
-- ALTER TABLE orders DROP CONSTRAINT check_cancelled_by_role_valid;
-- ALTER TABLE orders DROP COLUMN cancelled_by_role;
-- DROP TRIGGER IF EXISTS orders_cancellation_validation ON orders;
-- DROP FUNCTION IF EXISTS validate_cancellation_data();
-- DROP TABLE IF EXISTS cancellation_roles;
-- DROP VIEW IF EXISTS v_cancelled_orders;
