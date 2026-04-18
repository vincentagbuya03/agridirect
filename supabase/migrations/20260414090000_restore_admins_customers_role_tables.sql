-- Migration: Restore admins/customers role tables and rewire role-specific FKs
-- Purpose:
--   - Reintroduce admins and customers as role-specific entities
--   - Replace generic user FKs where a role-specific relationship is preferred
--   - Keep the rest of the normalized schema intact
-- Notes:
--   - This migration is intended to run after 20260413130000_normalize_schema_to_2nf.sql
--   - It does not attempt to undo lookup_values or other merged structures

BEGIN;

-- ============================================================================
-- STEP 1: Recreate role-specific tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS customers (
  customer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS admins (
  admin_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
  role_level smallint NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

DO $$
DECLARE
  v_customer_role_id uuid;
  v_admin_role_id uuid;
BEGIN
  SELECT role_id INTO v_customer_role_id
  FROM roles
  WHERE lower(name) = 'customer'
  LIMIT 1;

  SELECT role_id INTO v_admin_role_id
  FROM roles
  WHERE lower(name) = 'admin'
  LIMIT 1;

  IF v_customer_role_id IS NOT NULL THEN
    INSERT INTO customers (user_id, is_active, created_at)
    SELECT ur.user_id, ur.is_active, ur.created_at
    FROM user_roles ur
    WHERE ur.role_id = v_customer_role_id
    ON CONFLICT (user_id) DO UPDATE
    SET is_active = EXCLUDED.is_active;
  END IF;

  IF v_admin_role_id IS NOT NULL THEN
    INSERT INTO admins (user_id, role_level, is_active, created_at)
    SELECT ur.user_id, ur.role_level, ur.is_active, ur.created_at
    FROM user_roles ur
    WHERE ur.role_id = v_admin_role_id
    ON CONFLICT (user_id) DO UPDATE
    SET role_level = EXCLUDED.role_level,
        is_active = EXCLUDED.is_active;
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Add role-specific foreign keys back to business tables
-- ============================================================================

ALTER TABLE cart_items
  ADD COLUMN IF NOT EXISTS customer_id uuid;

UPDATE cart_items ci
SET customer_id = c.customer_id
FROM customers c
WHERE c.user_id = ci.user_id
  AND ci.customer_id IS NULL;

ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS customer_id uuid;

UPDATE conversations cv
SET customer_id = c.customer_id
FROM customers c
WHERE c.user_id = cv.customer_user_id
  AND cv.customer_id IS NULL;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS customer_id uuid;

UPDATE orders o
SET customer_id = c.customer_id
FROM customers c
WHERE c.user_id = o.customer_user_id
  AND o.customer_id IS NULL;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS customer_id uuid;

UPDATE payments p
SET customer_id = c.customer_id
FROM customers c
WHERE c.user_id = p.payer_user_id
  AND p.customer_id IS NULL;

ALTER TABLE admin_articles
  ADD COLUMN IF NOT EXISTS admin_id uuid;

UPDATE admin_articles aa
SET admin_id = a.admin_id
FROM admins a
WHERE a.user_id = aa.author_user_id
  AND aa.admin_id IS NULL;

ALTER TABLE admin_logs
  ADD COLUMN IF NOT EXISTS admin_id uuid;

UPDATE admin_logs al
SET admin_id = a.admin_id
FROM admins a
WHERE a.user_id = al.actor_user_id
  AND al.admin_id IS NULL;

ALTER TABLE reported_content
  ADD COLUMN IF NOT EXISTS reporter_customer_id uuid,
  ADD COLUMN IF NOT EXISTS resolved_by_admin_id uuid;

UPDATE reported_content rc
SET reporter_customer_id = c.customer_id
FROM customers c
WHERE c.user_id = rc.reporter_user_id
  AND rc.reporter_customer_id IS NULL;

UPDATE reported_content rc
SET resolved_by_admin_id = a.admin_id
FROM admins a
WHERE a.user_id = rc.resolved_by_user_id
  AND rc.resolved_by_admin_id IS NULL;

-- ============================================================================
-- STEP 3: Enforce role-specific constraints
-- ============================================================================

ALTER TABLE cart_items
  DROP CONSTRAINT IF EXISTS fk_cart_items_customer_id,
  ADD CONSTRAINT fk_cart_items_customer_id
  FOREIGN KEY (customer_id)
  REFERENCES customers(customer_id) ON DELETE CASCADE;

ALTER TABLE conversations
  DROP CONSTRAINT IF EXISTS fk_conversations_customer_id,
  ADD CONSTRAINT fk_conversations_customer_id
  FOREIGN KEY (customer_id)
  REFERENCES customers(customer_id) ON DELETE CASCADE;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS fk_orders_customer_id,
  ADD CONSTRAINT fk_orders_customer_id
  FOREIGN KEY (customer_id)
  REFERENCES customers(customer_id) ON DELETE CASCADE;

ALTER TABLE payments
  DROP CONSTRAINT IF EXISTS fk_payments_customer_id,
  ADD CONSTRAINT fk_payments_customer_id
  FOREIGN KEY (customer_id)
  REFERENCES customers(customer_id) ON DELETE CASCADE;

ALTER TABLE admin_articles
  DROP CONSTRAINT IF EXISTS fk_admin_articles_admin_id,
  ADD CONSTRAINT fk_admin_articles_admin_id
  FOREIGN KEY (admin_id)
  REFERENCES admins(admin_id) ON DELETE RESTRICT;

ALTER TABLE admin_logs
  DROP CONSTRAINT IF EXISTS fk_admin_logs_admin_id,
  ADD CONSTRAINT fk_admin_logs_admin_id
  FOREIGN KEY (admin_id)
  REFERENCES admins(admin_id) ON DELETE RESTRICT;

ALTER TABLE reported_content
  DROP CONSTRAINT IF EXISTS fk_reported_content_reporter_customer,
  ADD CONSTRAINT fk_reported_content_reporter_customer
  FOREIGN KEY (reporter_customer_id)
  REFERENCES customers(customer_id) ON DELETE CASCADE,
  DROP CONSTRAINT IF EXISTS fk_reported_content_resolved_by_admin,
  ADD CONSTRAINT fk_reported_content_resolved_by_admin
  FOREIGN KEY (resolved_by_admin_id)
  REFERENCES admins(admin_id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 4: Make role-specific columns required where the relationship is mandatory
-- ============================================================================

ALTER TABLE cart_items
  ALTER COLUMN customer_id SET NOT NULL;

ALTER TABLE conversations
  ALTER COLUMN customer_id SET NOT NULL;

ALTER TABLE orders
  ALTER COLUMN customer_id SET NOT NULL;

ALTER TABLE payments
  ALTER COLUMN customer_id SET NOT NULL;

ALTER TABLE admin_articles
  ALTER COLUMN admin_id SET NOT NULL;

ALTER TABLE admin_logs
  ALTER COLUMN admin_id SET NOT NULL;

ALTER TABLE reported_content
  ALTER COLUMN reporter_customer_id SET NOT NULL;

-- ============================================================================
-- STEP 5: Remove generic user-based role columns
-- ============================================================================

DROP VIEW IF EXISTS v_customer_stats CASCADE;
DROP VIEW IF EXISTS v_orders CASCADE;
DROP VIEW IF EXISTS v_cancelled_orders CASCADE;
DROP VIEW IF EXISTS v_schema_validation CASCADE;

ALTER TABLE cart_items
  DROP COLUMN IF EXISTS user_id;

ALTER TABLE conversations
  DROP COLUMN IF EXISTS customer_user_id;

ALTER TABLE orders
  DROP COLUMN IF EXISTS customer_user_id;

ALTER TABLE payments
  DROP COLUMN IF EXISTS payer_user_id;

ALTER TABLE admin_articles
  DROP COLUMN IF EXISTS author_user_id;

ALTER TABLE admin_logs
  DROP COLUMN IF EXISTS actor_user_id;

ALTER TABLE reported_content
  DROP COLUMN IF EXISTS reporter_user_id,
  DROP COLUMN IF EXISTS resolved_by_user_id;

-- ============================================================================
-- STEP 6: Rebuild affected views
-- ============================================================================

DROP VIEW IF EXISTS v_customer_stats CASCADE;
CREATE VIEW v_customer_stats AS
SELECT
  c.user_id,
  COUNT(*)::bigint AS total_orders,
  COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.user_id;

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
  o.payment_method_id,
  o.special_instructions,
  o.cancellation_reason,
  o.cancelled_by,
  o.created_at,
  o.updated_at,
  u.name AS customer_name,
  f.farm_name AS farmer_name,
  os.code AS status_code,
  os.description AS status_description,
  pm.description AS payment_method_name
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN users u ON u.user_id = c.user_id
LEFT JOIN farmers f ON f.farmer_id = o.farmer_id
LEFT JOIN lookup_values os
  ON os.lookup_type = o.order_status_type
 AND os.lookup_value_id = o.order_status_id
LEFT JOIN lookup_values pm
  ON pm.lookup_type = o.payment_method_type
 AND pm.lookup_value_id = o.payment_method_id;

DROP VIEW IF EXISTS v_cancelled_orders CASCADE;
CREATE VIEW v_cancelled_orders AS
SELECT
  o.order_id,
  o.order_number,
  o.customer_id,
  o.farmer_id,
  o.cancelled_by,
  o.cancelled_by_role_id,
  cr.code AS cancelled_by_role,
  o.cancellation_reason,
  cr.description AS cancellation_role_description,
  o.updated_at AS cancelled_at
FROM orders o
LEFT JOIN lookup_values cr
  ON cr.lookup_type = o.cancellation_role_type
 AND cr.lookup_value_id = o.cancelled_by_role_id
LEFT JOIN lookup_values os
  ON os.lookup_type = o.order_status_type
 AND os.lookup_value_id = o.order_status_id
WHERE os.code = 'cancelled';

DROP VIEW IF EXISTS v_schema_validation CASCADE;
CREATE VIEW v_schema_validation AS
SELECT
  'admin_articles'::text AS table_name,
  (SELECT COUNT(*) FROM admin_articles) AS total_rows,
  (SELECT COUNT(*) FROM admin_articles WHERE admin_id IS NULL) AS null_admin_id,
  (SELECT COUNT(*) FROM admin_articles WHERE title IS NULL) AS null_title,
  (SELECT COUNT(*) FROM admin_articles WHERE body IS NULL) AS null_body;

COMMIT;
