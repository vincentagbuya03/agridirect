-- Migration: Convert orders.cancelled_by_role to FK (cancelled_by_role_id)
-- Purpose: Replace text column with proper foreign key to cancellation_roles lookup table
-- Improves: Data integrity via FK constraints
-- Created: April 11, 2026

-- Step 1: Drop dependent objects first
DROP TRIGGER IF EXISTS orders_cancellation_validation ON orders;
DROP VIEW IF EXISTS v_cancelled_orders CASCADE;
DROP VIEW IF EXISTS v_orders_with_delivery_method CASCADE;

-- Step 2: Create the new cancelled_by_role_id column
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS cancelled_by_role_id SMALLINT;

-- Step 3: Migrate data from text to FK using lookup table
UPDATE orders
SET cancelled_by_role_id = cr.cancellation_role_id
FROM cancellation_roles cr
WHERE orders.cancelled_by_role = cr.code 
  AND orders.cancelled_by_role IS NOT NULL
  AND orders.cancelled_by_role_id IS NULL;

-- Step 4: Add default for unmatched roles (system-cancelled)
UPDATE orders
SET cancelled_by_role_id = 4  -- system role
WHERE cancelled_by_role IS NOT NULL 
  AND orders.cancelled_by_role_id IS NULL;

-- Step 5: Add FK constraint
ALTER TABLE orders
ADD CONSTRAINT fk_orders_cancelled_by_role_id
FOREIGN KEY (cancelled_by_role_id)
REFERENCES cancellation_roles(cancellation_role_id)
ON DELETE RESTRICT ON UPDATE CASCADE;

-- Step 6: Drop the old text column
ALTER TABLE orders
DROP COLUMN IF EXISTS cancelled_by_role;

-- Step 7: Recreate the view with FK column
CREATE OR REPLACE VIEW v_cancelled_orders AS
SELECT 
  o.order_id,
  o.order_number,
  o.customer_id,
  o.farmer_id,
  o.cancelled_by,
  o.cancelled_by_role_id,
  cr.code as cancelled_by_role,
  o.cancellation_reason,
  cr.description AS cancellation_role_description,
  o.updated_at AS cancelled_at
FROM orders o
LEFT JOIN cancellation_roles cr ON o.cancelled_by_role_id = cr.cancellation_role_id
WHERE o.order_status_id = 6;

-- Step 8: Recreate v_orders_with_delivery_method view (using FK delivery_method_id now)
CREATE OR REPLACE VIEW v_orders_with_delivery_method AS
SELECT 
  o.*,
  dm.code as delivery_method
FROM orders o
LEFT JOIN delivery_methods dm ON o.delivery_method_id = dm.delivery_method_id;

-- Step 9: Update comments
COMMENT ON COLUMN orders.cancelled_by_role_id IS
'FK to cancellation_roles table. Tracks the role that initiated order cancellation (1=customer, 2=farmer, 3=admin, 4=system).
Only populated when order_status_id indicates cancelled. Works with cancelled_by UUID to track both role and user.';

-- Queries to verify data integrity:
-- 1. Check cancellation tracking:
--    SELECT o.order_id, o.order_number, u.email as cancelled_by_user, cr.code as role
--    FROM orders o
--    LEFT JOIN users u ON o.cancelled_by = u.user_id
--    LEFT JOIN cancellation_roles cr ON o.cancelled_by_role_id = cr.cancellation_role_id
--    WHERE o.cancelled_by IS NOT NULL;
-- 2. Count cancellations by role:
--    SELECT cr.code, COUNT(*) as count FROM orders o
--    LEFT JOIN cancellation_roles cr ON o.cancelled_by_role_id = cr.cancellation_role_id
--    WHERE o.cancelled_by IS NOT NULL
--    GROUP BY cr.code;

-- Rollback note:
-- ALTER TABLE orders ADD COLUMN cancelled_by_role TEXT;
-- UPDATE orders SET cancelled_by_role = cr.code FROM cancellation_roles cr WHERE cancelled_by_role_id = cr.cancellation_role_id;
-- ALTER TABLE orders DROP CONSTRAINT fk_orders_cancelled_by_role_id;
-- ALTER TABLE orders DROP COLUMN cancelled_by_role_id;
