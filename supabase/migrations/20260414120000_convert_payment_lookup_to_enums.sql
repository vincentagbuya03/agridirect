-- Migration: Convert payment lookup tables to enums and drop payment lookups
-- Purpose:
--   - Replace payment_methods/payment_statuses table lookups with enum columns
--   - Remove payment_method_id/payment_status_id dependencies
--   - Keep payment methods/statuses static and DB-enforced

BEGIN;

-- ============================================================================
-- STEP 1: Create enum types for static payment values
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'payment_method_enum'
  ) THEN
    CREATE TYPE payment_method_enum AS ENUM ('COD', 'COP', 'OTHER');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'payment_status_enum'
  ) THEN
    CREATE TYPE payment_status_enum AS ENUM (
      'offline_pending',
      'pending',
      'paid',
      'failed',
      'cancelled',
      'refunded',
      'unknown'
    );
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Add enum-backed columns
-- ============================================================================

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS payment_method payment_method_enum;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS payment_method payment_method_enum,
  ADD COLUMN IF NOT EXISTS payment_status payment_status_enum;

-- ============================================================================
-- STEP 3: Backfill enum values from lookup tables
-- ============================================================================

UPDATE orders o
SET payment_method = CASE
  WHEN UPPER(pm.code) IN ('COD', 'COP') THEN UPPER(pm.code)::payment_method_enum
  ELSE 'OTHER'::payment_method_enum
END
FROM payment_methods pm
WHERE o.payment_method IS NULL
  AND o.payment_method_id = pm.payment_method_id;

UPDATE orders
SET payment_method = 'COD'::payment_method_enum
WHERE payment_method IS NULL;

UPDATE payments p
SET payment_method = CASE
  WHEN UPPER(pm.code) IN ('COD', 'COP') THEN UPPER(pm.code)::payment_method_enum
  ELSE 'OTHER'::payment_method_enum
END
FROM payment_methods pm
WHERE p.payment_method IS NULL
  AND p.payment_method_id = pm.payment_method_id;

UPDATE payments
SET payment_method = 'COD'::payment_method_enum
WHERE payment_method IS NULL;

UPDATE payments p
SET payment_status = CASE
  WHEN LOWER(ps.code) IN ('offline_pending', 'pending', 'paid', 'failed', 'cancelled', 'refunded')
    THEN LOWER(ps.code)::payment_status_enum
  ELSE 'unknown'::payment_status_enum
END
FROM payment_statuses ps
WHERE p.payment_status IS NULL
  AND p.payment_status_id = ps.payment_status_id;

UPDATE payments
SET payment_status = 'offline_pending'::payment_status_enum
WHERE payment_status IS NULL;

ALTER TABLE orders
  ALTER COLUMN payment_method SET DEFAULT 'COD'::payment_method_enum,
  ALTER COLUMN payment_method SET NOT NULL;

ALTER TABLE payments
  ALTER COLUMN payment_method SET DEFAULT 'COD'::payment_method_enum,
  ALTER COLUMN payment_status SET DEFAULT 'offline_pending'::payment_status_enum,
  ALTER COLUMN payment_method SET NOT NULL,
  ALTER COLUMN payment_status SET NOT NULL;

-- ============================================================================
-- STEP 4: Remove old payment FK constraints and ID/type columns
-- ============================================================================

-- Drop dependent views first so old ID columns can be removed safely.
DROP VIEW IF EXISTS v_orders CASCADE;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS fk_orders_payment_method_lookup,
  DROP CONSTRAINT IF EXISTS fk_orders_payment_method_id;

ALTER TABLE payments
  DROP CONSTRAINT IF EXISTS fk_payments_method_lookup,
  DROP CONSTRAINT IF EXISTS fk_payments_status_lookup,
  DROP CONSTRAINT IF EXISTS fk_payments_method_id,
  DROP CONSTRAINT IF EXISTS fk_payments_status_id;

ALTER TABLE orders
  DROP COLUMN IF EXISTS payment_method_id,
  DROP COLUMN IF EXISTS payment_method_type;

ALTER TABLE payments
  DROP COLUMN IF EXISTS payment_method_id,
  DROP COLUMN IF EXISTS payment_method_type,
  DROP COLUMN IF EXISTS payment_status_id,
  DROP COLUMN IF EXISTS payment_status_type;

-- ============================================================================
-- STEP 5: Rebuild views that depended on payment lookup tables
-- ============================================================================

DROP VIEW IF EXISTS v_orders CASCADE;
CREATE VIEW v_orders AS
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
  cu.name AS customer_name,
  f.farm_name AS farmer_name,
  os.code AS status_code,
  os.description AS status_description,
  o.payment_method::text AS payment_method_name
FROM orders o
LEFT JOIN customers c
  ON c.customer_id = o.customer_id
LEFT JOIN users cu
  ON cu.user_id = c.user_id
LEFT JOIN farmers f
  ON f.farmer_id = o.farmer_id
LEFT JOIN order_statuses os
  ON os.order_status_id = o.order_status_id;

-- ============================================================================
-- STEP 6: Drop static payment lookup tables
-- ============================================================================

DROP TABLE IF EXISTS payment_methods;
DROP TABLE IF EXISTS payment_statuses;

COMMIT;
