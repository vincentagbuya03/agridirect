-- Migration: Enforce strict physical cash-only payments
-- Purpose:
--   1) Restrict payment_method enum to COD and COP only
--   2) Remove non-physical payment fields from payments table
--
-- Safe behavior:
--   - Any legacy 'OTHER' values are remapped to 'COD' before enum tightening.

BEGIN;

-- ============================================================================
-- STEP 1: Remap legacy enum values that are not allowed anymore
-- ============================================================================

UPDATE orders
SET payment_method = 'COD'::payment_method_enum
WHERE payment_method::text = 'OTHER';

UPDATE payments
SET payment_method = 'COD'::payment_method_enum
WHERE payment_method::text = 'OTHER';

-- ============================================================================
-- STEP 2: Recreate payment_method_enum as COD/COP only
-- Postgres does not support dropping enum labels directly in a portable way.
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method_enum') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method_enum_new') THEN
      CREATE TYPE payment_method_enum_new AS ENUM ('COD', 'COP');
    END IF;
  END IF;
END $$;

-- Drop dependent views before enum cast.
DROP VIEW IF EXISTS v_orders_with_delivery_method;
DROP VIEW IF EXISTS v_orders;

-- Drop defaults temporarily so cast/rename stays clean.
ALTER TABLE orders
  ALTER COLUMN payment_method DROP DEFAULT;

ALTER TABLE payments
  ALTER COLUMN payment_method DROP DEFAULT;

-- Cast columns to new enum.
ALTER TABLE orders
  ALTER COLUMN payment_method TYPE payment_method_enum_new
  USING payment_method::text::payment_method_enum_new;

ALTER TABLE payments
  ALTER COLUMN payment_method TYPE payment_method_enum_new
  USING payment_method::text::payment_method_enum_new;

-- Swap enum names.
DROP TYPE IF EXISTS payment_method_enum;
ALTER TYPE payment_method_enum_new RENAME TO payment_method_enum;

-- Restore defaults.
ALTER TABLE orders
  ALTER COLUMN payment_method SET DEFAULT 'COD'::payment_method_enum;

ALTER TABLE payments
  ALTER COLUMN payment_method SET DEFAULT 'COD'::payment_method_enum;

-- Recreate views dropped for enum cast.
CREATE OR REPLACE VIEW v_orders AS
SELECT
  o.order_id,
  o.order_number,
  o.customer_id,
  o.farmer_id,
  o.delivery_address_id,
  o.order_status_id,
  o.subtotal,
  o.delivery_fee,
  o.total_amount,
  o.payment_method,
  o.special_instructions,
  o.cancellation_reason,
  o.cancelled_by,
  o.created_at,
  o.updated_at,
  u.name as customer_name,
  f.farm_name as farmer_name,
  os.code as status_code,
  os.description as status_description,
  o.payment_method::text as payment_method_name
FROM orders o
LEFT JOIN users u ON o.customer_id = (SELECT user_id FROM customers WHERE customer_id = o.customer_id)
LEFT JOIN farmers f ON o.farmer_id = f.farmer_id
LEFT JOIN order_statuses os ON o.order_status_id = os.order_status_id;

CREATE OR REPLACE VIEW v_orders_with_delivery_method AS
SELECT
  o.*
FROM orders o;

-- ============================================================================
-- STEP 3: Remove non-physical payment fields
-- ============================================================================

ALTER TABLE payments
  DROP COLUMN IF EXISTS transaction_reference,
  DROP COLUMN IF EXISTS proof_of_payment_url;

COMMIT;
