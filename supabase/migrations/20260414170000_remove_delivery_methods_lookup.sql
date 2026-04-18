-- Migration: Remove delivery_methods lookup
-- Purpose:
--   - Replace orders.delivery_method_id with a hardcoded text column
--   - Preserve existing data by backfilling from the current lookup values
--   - Drop the delivery_methods table and compatibility view

BEGIN;

DROP VIEW IF EXISTS v_orders_with_delivery_method CASCADE;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_method text;

UPDATE orders
SET delivery_method = CASE
  WHEN lower(coalesce(delivery_method, '')) IN ('delivery', 'pickup') THEN lower(delivery_method)
  WHEN delivery_method_id = 2 THEN 'pickup'
  ELSE 'delivery'
END;

ALTER TABLE orders
  ALTER COLUMN delivery_method SET DEFAULT 'delivery';

ALTER TABLE orders
  ALTER COLUMN delivery_method SET NOT NULL;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS fk_orders_delivery_method,
  DROP CONSTRAINT IF EXISTS fk_orders_delivery_method_lookup,
  DROP CONSTRAINT IF EXISTS orders_delivery_method_id_fkey;

ALTER TABLE orders
  DROP COLUMN IF EXISTS delivery_method_id;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_delivery_method_check,
  ADD CONSTRAINT orders_delivery_method_check
  CHECK (delivery_method IN ('delivery', 'pickup'));

DROP TABLE IF EXISTS delivery_methods CASCADE;

CREATE OR REPLACE VIEW v_orders_with_delivery_method AS
SELECT
  o.*
FROM orders o;

COMMENT ON VIEW v_orders_with_delivery_method IS
  'Compatibility view retained after removing delivery_methods. delivery_method is now a hardcoded checked text field on orders.';

COMMIT;
