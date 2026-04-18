-- Migration: Hardcode cancellation roles
-- Purpose:
--   - Replace orders.cancelled_by_role_id FK with hardcoded orders.cancelled_by_role text
--   - Preserve existing cancellation-role data
--   - Remove cancellation_roles lookup table

BEGIN;

DROP VIEW IF EXISTS v_cancelled_orders CASCADE;
DROP VIEW IF EXISTS v_orders_with_delivery_method CASCADE;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS cancelled_by_role text;

UPDATE orders
SET cancelled_by_role = CASE
  WHEN lower(coalesce(cancelled_by_role, '')) IN ('customer', 'farmer', 'admin', 'system') THEN lower(cancelled_by_role)
  WHEN cancelled_by_role_id = 1 THEN 'customer'
  WHEN cancelled_by_role_id = 2 THEN 'farmer'
  WHEN cancelled_by_role_id = 3 THEN 'admin'
  WHEN cancelled_by_role_id = 4 THEN 'system'
  ELSE cancelled_by_role
END;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS fk_orders_cancelled_by_role_id,
  DROP CONSTRAINT IF EXISTS fk_orders_cancel_role_lookup,
  DROP CONSTRAINT IF EXISTS orders_cancelled_by_role_id_fkey;

ALTER TABLE orders
  DROP COLUMN IF EXISTS cancelled_by_role_id;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_cancelled_by_role_check,
  ADD CONSTRAINT orders_cancelled_by_role_check
  CHECK (cancelled_by_role IS NULL OR cancelled_by_role IN ('customer', 'farmer', 'admin', 'system'));

DROP TABLE IF EXISTS cancellation_roles CASCADE;

CREATE OR REPLACE VIEW v_cancelled_orders AS
SELECT
  o.order_id,
  o.order_number,
  o.customer_id,
  o.farmer_id,
  o.cancelled_by,
  CASE o.cancelled_by_role
    WHEN 'customer' THEN 1
    WHEN 'farmer' THEN 2
    WHEN 'admin' THEN 3
    WHEN 'system' THEN 4
    ELSE NULL
  END AS cancelled_by_role_id,
  o.cancelled_by_role,
  o.cancellation_reason,
  CASE o.cancelled_by_role
    WHEN 'customer' THEN 'Order cancelled by customer'
    WHEN 'farmer' THEN 'Order cancelled by farmer'
    WHEN 'admin' THEN 'Order cancelled by admin/moderator'
    WHEN 'system' THEN 'Order cancelled by system (timeout, payment failure, etc.)'
    ELSE NULL
  END AS cancellation_role_description,
  o.updated_at AS cancelled_at
FROM orders o
WHERE o.order_status_id = 6;

CREATE OR REPLACE VIEW v_orders_with_delivery_method AS
SELECT
  o.*
FROM orders o;

COMMENT ON VIEW v_cancelled_orders IS
  'Cancelled orders with hardcoded cancelled_by_role values. Compatibility cancelled_by_role_id is derived from role text.';

COMMIT;
