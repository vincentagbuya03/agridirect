-- Migration: Normalize schema toward 2NF/3NF-safe structure
-- Purpose:
--   - Merge lookup tables into lookup_values
--   - Merge crop/livestock, review, forum-like, and media tables
--   - Fold 1:1 inventory / registration data into parent tables
--   - Preserve admins/customers as role-specific tables where appropriate
--   - Remove redundant product_name from order_items
-- Notes:
--   - This is a structural migration and will break code that still expects
--     the legacy tables/columns.
--   - Polymorphic tables use target_type discriminators and cannot enforce
--     every target FK with plain SQL constraints alone.

BEGIN;

-- ============================================================================
-- STEP 1: Expand user_roles so it can absorb admin/customer active metadata
-- ============================================================================

ALTER TABLE user_roles
  ADD COLUMN IF NOT EXISTS role_level smallint NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
DECLARE
  v_admin_role_id uuid;
  v_customer_role_id uuid;
BEGIN
  SELECT role_id INTO v_admin_role_id FROM roles WHERE lower(name) = 'admin' LIMIT 1;
  SELECT role_id INTO v_customer_role_id FROM roles WHERE lower(name) = 'customer' LIMIT 1;

  IF v_admin_role_id IS NOT NULL AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admins') THEN
    INSERT INTO user_roles (user_id, role_id, role_level, is_active, created_at, updated_at)
    SELECT a.user_id, v_admin_role_id, COALESCE(a.role_level, 1), COALESCE(a.is_active, true), COALESCE(a.created_at, now()), now()
    FROM admins a
    ON CONFLICT (user_id, role_id) DO UPDATE
    SET role_level = EXCLUDED.role_level,
        is_active = EXCLUDED.is_active,
        updated_at = now();
  END IF;

  IF v_customer_role_id IS NOT NULL AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
    INSERT INTO user_roles (user_id, role_id, role_level, is_active, created_at, updated_at)
    SELECT c.user_id, v_customer_role_id, 1, COALESCE(c.is_active, true), COALESCE(c.created_at, now()), now()
    FROM customers c
    ON CONFLICT (user_id, role_id) DO UPDATE
    SET is_active = EXCLUDED.is_active,
        updated_at = now();
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Create merged lookup table and seed from legacy lookup tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS lookup_values (
  lookup_type text NOT NULL,
  lookup_value_id smallint NOT NULL,
  code text NOT NULL,
  name text,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (lookup_type, lookup_value_id),
  UNIQUE (lookup_type, code)
);

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'order_status', order_status_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), COALESCE(updated_at, now())
FROM order_statuses
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'payment_status', payment_status_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), COALESCE(updated_at, now())
FROM payment_statuses
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'payment_method', payment_method_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), COALESCE(updated_at, now())
FROM payment_methods
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'delivery_method', delivery_method_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), now()
FROM delivery_methods
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'cancellation_role', cancellation_role_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), now()
FROM cancellation_roles
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'content_type', content_type_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), now()
FROM content_types
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'notification_type', notification_type_id, code, name, description, true, COALESCE(created_at, now()), now()
FROM notification_types
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'registration_status', registration_status_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), now()
FROM registration_statuses
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

INSERT INTO lookup_values (lookup_type, lookup_value_id, code, name, description, is_active, created_at, updated_at)
SELECT 'verification_type', verification_type_id, code, NULL, description, COALESCE(is_active, true), COALESCE(created_at, now()), now()
FROM verification_types
ON CONFLICT (lookup_type, lookup_value_id) DO NOTHING;

-- ============================================================================
-- STEP 3: Fold 1:1 registration data into farmers
-- ============================================================================

ALTER TABLE farmers
  ADD COLUMN IF NOT EXISTS registration_status_type text NOT NULL DEFAULT 'registration_status',
  ADD COLUMN IF NOT EXISTS registration_status_id smallint NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS reviewed_by_user_id uuid,
  ADD COLUMN IF NOT EXISTS review_notes text;

UPDATE farmers f
SET
  registration_status_id = COALESCE(fr.registration_status_id, f.registration_status_id),
  reviewed_by_user_id = COALESCE(f.reviewed_by_user_id, a.user_id),
  review_notes = COALESCE(f.review_notes, fr.review_notes),
  updated_at = now()
FROM farmer_registrations fr
LEFT JOIN admins a ON fr.reviewed_by = a.admin_id
WHERE fr.farmer_id = f.farmer_id;

ALTER TABLE farmers
  DROP CONSTRAINT IF EXISTS fk_farmers_registration_status,
  ADD CONSTRAINT fk_farmers_registration_status
  FOREIGN KEY (registration_status_type, registration_status_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id);

ALTER TABLE farmers
  DROP CONSTRAINT IF EXISTS fk_farmers_reviewed_by_user,
  ADD CONSTRAINT fk_farmers_reviewed_by_user
  FOREIGN KEY (reviewed_by_user_id)
  REFERENCES users(user_id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 4: Fold inventory into products
-- ============================================================================

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS available_quantity numeric,
  ADD COLUMN IF NOT EXISTS reserved_quantity numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS low_stock_threshold numeric,
  ADD COLUMN IF NOT EXISTS inventory_updated_at timestamptz;

UPDATE products p
SET
  available_quantity = pi.available_quantity,
  reserved_quantity = COALESCE(pi.reserved_quantity, 0),
  low_stock_threshold = pi.low_stock_threshold,
  inventory_updated_at = pi.updated_at,
  updated_at = now()
FROM product_inventory pi
WHERE pi.product_id = p.product_id;

-- ============================================================================
-- STEP 5: Preserve customer/admin role-specific foreign keys
-- ============================================================================

-- ============================================================================
-- STEP 6: Add lookup_values composite references to live tables
-- ============================================================================

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS order_status_type text NOT NULL DEFAULT 'order_status',
  ADD COLUMN IF NOT EXISTS payment_method_type text NOT NULL DEFAULT 'payment_method',
  ADD COLUMN IF NOT EXISTS delivery_method_type text NOT NULL DEFAULT 'delivery_method',
  ADD COLUMN IF NOT EXISTS cancellation_role_type text NOT NULL DEFAULT 'cancellation_role';

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS payment_status_type text NOT NULL DEFAULT 'payment_status',
  ADD COLUMN IF NOT EXISTS payment_method_type text NOT NULL DEFAULT 'payment_method';

ALTER TABLE order_status_logs
  ADD COLUMN IF NOT EXISTS order_status_type text NOT NULL DEFAULT 'order_status',
  ADD COLUMN IF NOT EXISTS changed_by_user_id uuid;

UPDATE order_status_logs
SET changed_by_user_id = changed_by
WHERE changed_by_user_id IS NULL;

ALTER TABLE verification_codes
  ADD COLUMN IF NOT EXISTS verification_type text NOT NULL DEFAULT 'verification_type';

ALTER TABLE reported_content
  ADD COLUMN IF NOT EXISTS content_type text NOT NULL DEFAULT 'content_type',
  ADD COLUMN IF NOT EXISTS reporter_customer_id uuid,
  ADD COLUMN IF NOT EXISTS resolved_by_admin_id uuid;

UPDATE reported_content rc
SET reporter_customer_id = c.customer_id
FROM customers c
WHERE rc.reporter_id = c.user_id
  AND rc.reporter_customer_id IS NULL;

UPDATE reported_content rc
SET resolved_by_admin_id = a.admin_id
FROM admins a
WHERE rc.resolved_by = a.user_id
  AND rc.resolved_by_admin_id IS NULL;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS fk_orders_status_lookup,
  ADD CONSTRAINT fk_orders_status_lookup
  FOREIGN KEY (order_status_type, order_status_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id),
  DROP CONSTRAINT IF EXISTS fk_orders_payment_method_lookup,
  ADD CONSTRAINT fk_orders_payment_method_lookup
  FOREIGN KEY (payment_method_type, payment_method_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id),
  DROP CONSTRAINT IF EXISTS fk_orders_delivery_method_lookup,
  ADD CONSTRAINT fk_orders_delivery_method_lookup
  FOREIGN KEY (delivery_method_type, delivery_method_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id),
  DROP CONSTRAINT IF EXISTS fk_orders_cancel_role_lookup,
  ADD CONSTRAINT fk_orders_cancel_role_lookup
  FOREIGN KEY (cancellation_role_type, cancelled_by_role_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id);

ALTER TABLE payments
  DROP CONSTRAINT IF EXISTS fk_payments_status_lookup,
  ADD CONSTRAINT fk_payments_status_lookup
  FOREIGN KEY (payment_status_type, payment_status_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id),
  DROP CONSTRAINT IF EXISTS fk_payments_method_lookup,
  ADD CONSTRAINT fk_payments_method_lookup
  FOREIGN KEY (payment_method_type, payment_method_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id);

ALTER TABLE order_status_logs
  DROP CONSTRAINT IF EXISTS fk_order_status_logs_lookup,
  ADD CONSTRAINT fk_order_status_logs_lookup
  FOREIGN KEY (order_status_type, order_status_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id),
  DROP CONSTRAINT IF EXISTS fk_order_status_logs_changed_by_user,
  ADD CONSTRAINT fk_order_status_logs_changed_by_user
  FOREIGN KEY (changed_by_user_id)
  REFERENCES users(user_id) ON DELETE SET NULL;

ALTER TABLE verification_codes
  DROP CONSTRAINT IF EXISTS fk_verification_codes_lookup,
  ADD CONSTRAINT fk_verification_codes_lookup
  FOREIGN KEY (verification_type, verification_type_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id);

ALTER TABLE reported_content
  ALTER COLUMN reporter_customer_id SET NOT NULL,
  DROP CONSTRAINT IF EXISTS fk_reported_content_lookup,
  ADD CONSTRAINT fk_reported_content_lookup
  FOREIGN KEY (content_type, content_type_id)
  REFERENCES lookup_values (lookup_type, lookup_value_id),
  DROP CONSTRAINT IF EXISTS fk_reported_content_reporter_customer,
  ADD CONSTRAINT fk_reported_content_reporter_customer
  FOREIGN KEY (reporter_customer_id)
  REFERENCES customers(customer_id) ON DELETE CASCADE,
  DROP CONSTRAINT IF EXISTS fk_reported_content_resolved_by_admin,
  ADD CONSTRAINT fk_reported_content_resolved_by_admin
  FOREIGN KEY (resolved_by_admin_id)
  REFERENCES admins(admin_id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 7: Create merged tables and backfill data
-- ============================================================================

CREATE TABLE IF NOT EXISTS farmer_produce (
  produce_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  produce_type text NOT NULL CHECK (produce_type IN ('crop', 'livestock')),
  produce_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (farmer_id, produce_type, produce_name)
);

INSERT INTO farmer_produce (farmer_id, produce_type, produce_name, created_at)
SELECT farmer_id, 'crop', crop_type, COALESCE(created_at, now())
FROM farmer_crop_types
ON CONFLICT (farmer_id, produce_type, produce_name) DO NOTHING;

INSERT INTO farmer_produce (farmer_id, produce_type, produce_name, created_at)
SELECT farmer_id, 'livestock', livestock_type, COALESCE(created_at, now())
FROM farmer_livestock
ON CONFLICT (farmer_id, produce_type, produce_name) DO NOTHING;

CREATE TABLE IF NOT EXISTS reviews (
  review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_type text NOT NULL CHECK (review_type IN ('farmer', 'product')),
  reviewer_user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  farmer_id uuid REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(product_id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(order_id) ON DELETE SET NULL,
  rating numeric NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  response_text text,
  response_date timestamptz,
  is_verified_purchase boolean NOT NULL DEFAULT false,
  helpful_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_reviews_target
    CHECK (
      (review_type = 'farmer' AND farmer_id IS NOT NULL AND product_id IS NULL)
      OR
      (review_type = 'product' AND product_id IS NOT NULL AND farmer_id IS NULL)
    )
);

INSERT INTO reviews (
  review_id, review_type, reviewer_user_id, farmer_id, order_id, rating,
  review_text, response_text, response_date, is_verified_purchase,
  helpful_count, created_at, updated_at
)
SELECT
  fr.rating_id,
  'farmer',
  c.user_id,
  fr.farmer_id,
  fr.order_id,
  fr.rating,
  fr.review_text,
  fr.response_text,
  fr.response_date,
  true,
  0,
  COALESCE(fr.created_at, now()),
  COALESCE(fr.created_at, now())
FROM farmer_ratings fr
JOIN customers c ON fr.customer_id = c.customer_id
ON CONFLICT (review_id) DO NOTHING;

INSERT INTO reviews (
  review_id, review_type, reviewer_user_id, product_id, order_id, rating,
  review_text, is_verified_purchase, helpful_count, created_at, updated_at
)
SELECT
  pr.review_id,
  'product',
  c.user_id,
  pr.product_id,
  pr.order_id,
  pr.rating,
  pr.review_text,
  COALESCE(pr.is_verified_purchase, false),
  COALESCE(pr.helpful_count, 0),
  COALESCE(pr.created_at, now()),
  COALESCE(pr.updated_at, COALESCE(pr.created_at, now()))
FROM product_reviews pr
JOIN customers c ON pr.customer_id = c.customer_id
ON CONFLICT (review_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS forum_likes (
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  target_type text NOT NULL CHECK (target_type IN ('post', 'comment')),
  target_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, target_type, target_id)
);

INSERT INTO forum_likes (user_id, target_type, target_id, created_at, updated_at)
SELECT user_id, 'post', post_id, COALESCE(created_at, now()), COALESCE(updated_at, COALESCE(created_at, now()))
FROM forum_post_likes
ON CONFLICT (user_id, target_type, target_id) DO NOTHING;

INSERT INTO forum_likes (user_id, target_type, target_id, created_at, updated_at)
SELECT user_id, 'comment', comment_id, COALESCE(created_at, now()), COALESCE(updated_at, COALESCE(created_at, now()))
FROM forum_comment_likes
ON CONFLICT (user_id, target_type, target_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS media_attachments (
  attachment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type text NOT NULL CHECK (target_type IN ('product', 'review')),
  target_id uuid NOT NULL,
  media_url text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (target_type, target_id, sort_order)
);

INSERT INTO media_attachments (attachment_id, target_type, target_id, media_url, sort_order, created_at)
SELECT image_id, 'product', product_id, image_url, COALESCE(sort_order, 0), COALESCE(created_at, now())
FROM product_images
ON CONFLICT (attachment_id) DO NOTHING;

INSERT INTO media_attachments (attachment_id, target_type, target_id, media_url, sort_order, created_at)
SELECT image_id, 'review', review_id, image_url, COALESCE(sort_order, 0), COALESCE(created_at, now())
FROM review_images
ON CONFLICT (attachment_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS notification_events (
  notification_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_type text NOT NULL DEFAULT 'notification_type',
  notification_type_id smallint NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  link_url text,
  link_type text,
  link_id uuid,
  expires_at timestamptz DEFAULT (now() + interval '90 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_notification_events_type
    FOREIGN KEY (notification_type, notification_type_id)
    REFERENCES lookup_values (lookup_type, lookup_value_id)
);

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_event_id uuid;

WITH inserted_events AS (
  INSERT INTO notification_events (
    notification_event_id, notification_type, notification_type_id, title, body,
    link_url, link_type, link_id, expires_at, created_at
  )
  SELECT
    notification_id,
    'notification_type',
    notification_type_id,
    title,
    body,
    link_url,
    link_type,
    link_id,
    expires_at,
    COALESCE(created_at, now())
  FROM notifications
  ON CONFLICT (notification_event_id) DO NOTHING
  RETURNING notification_event_id
)
UPDATE notifications n
SET notification_event_id = n.notification_id
WHERE n.notification_event_id IS NULL;

ALTER TABLE notifications
  ADD CONSTRAINT fk_notifications_event
  FOREIGN KEY (notification_event_id)
  REFERENCES notification_events(notification_event_id) ON DELETE CASCADE;

-- ============================================================================
-- STEP 8: Remove known redundancy from order_items
-- ============================================================================

ALTER TABLE order_items DROP COLUMN IF EXISTS product_name;

-- ============================================================================
-- STEP 9: Rebuild compatibility views against the normalized structure
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

DROP VIEW IF EXISTS v_users_with_roles CASCADE;
CREATE VIEW v_users_with_roles AS
SELECT
  u.user_id,
  u.email,
  u.name,
  u.phone,
  u.avatar_url,
  u.bio,
  u.email_verified,
  u.created_at,
  u.updated_at,
  r.name AS role_name,
  r.role_id,
  ur.role_level,
  ur.is_active AS role_is_active
FROM users u
LEFT JOIN user_roles ur ON u.user_id = ur.user_id
LEFT JOIN roles r ON ur.role_id = r.role_id;

DROP VIEW IF EXISTS v_products CASCADE;
CREATE VIEW v_products AS
SELECT
  p.product_id,
  p.name,
  p.description,
  p.price,
  p.harvest_days,
  p.is_preorder,
  p.is_featured,
  p.is_active,
  p.farmer_id,
  p.category_id,
  p.unit_id,
  p.created_at,
  p.updated_at,
  f.farm_name,
  c.name AS category_name,
  u.name AS unit_name,
  u.abbreviation AS unit_abbr,
  ma.media_url AS image_url,
  COALESCE(AVG(CASE WHEN r.review_type = 'product' THEN r.rating END), 0) AS average_rating,
  COUNT(CASE WHEN r.review_type = 'product' THEN 1 END)::integer AS review_count,
  COALESCE(SUM(oi.quantity), 0) AS total_sold
FROM products p
LEFT JOIN farmers f ON p.farmer_id = f.farmer_id
LEFT JOIN categories c ON p.category_id = c.category_id
LEFT JOIN units u ON p.unit_id = u.unit_id
LEFT JOIN media_attachments ma ON ma.target_type = 'product' AND ma.target_id = p.product_id AND ma.sort_order = 0
LEFT JOIN reviews r ON r.review_type = 'product' AND r.product_id = p.product_id
LEFT JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY p.product_id, f.farm_name, c.name, u.name, u.abbreviation, ma.media_url;

DROP VIEW IF EXISTS v_farmer_stats CASCADE;
CREATE VIEW v_farmer_stats AS
SELECT
  f.farmer_id,
  COALESCE(SUM(CASE WHEN os.code = 'completed' THEN o.total_amount END), 0) AS total_sales,
  COUNT(DISTINCT p.product_id)::bigint AS total_products,
  COALESCE(AVG(CASE WHEN r.review_type = 'farmer' THEN r.rating END), 0) AS average_rating,
  COUNT(CASE WHEN r.review_type = 'farmer' THEN 1 END)::bigint AS total_reviews
FROM farmers f
LEFT JOIN orders o ON o.farmer_id = f.farmer_id
LEFT JOIN lookup_values os ON os.lookup_type = o.order_status_type AND os.lookup_value_id = o.order_status_id
LEFT JOIN products p ON p.farmer_id = f.farmer_id AND p.is_active = true
LEFT JOIN reviews r ON r.review_type = 'farmer' AND r.farmer_id = f.farmer_id
GROUP BY f.farmer_id;

DROP VIEW IF EXISTS v_farmer_profiles CASCADE;
CREATE VIEW v_farmer_profiles AS
SELECT
  f.farmer_id,
  f.user_id,
  f.farm_name,
  f.specialty,
  f.location,
  f.residential_address,
  f.farming_history,
  f.badge,
  f.image_url,
  f.is_verified,
  f.is_active,
  f.created_at,
  f.updated_at,
  f.birth_date,
  f.years_of_experience,
  f.face_photo_path,
  f.valid_id_path,
  u.name AS farmer_name,
  u.email AS farmer_email,
  u.phone AS farmer_phone,
  u.avatar_url,
  lv.code AS registration_status,
  fs.total_sales,
  fs.total_products,
  fs.average_rating,
  fs.total_reviews
FROM farmers f
JOIN users u ON f.user_id = u.user_id
LEFT JOIN lookup_values lv ON lv.lookup_type = f.registration_status_type AND lv.lookup_value_id = f.registration_status_id
LEFT JOIN v_farmer_stats fs ON fs.farmer_id = f.farmer_id;

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
  o.cancelled_by AS cancelled_by,
  o.created_at,
  o.updated_at,
  cu.name AS customer_name,
  f.farm_name AS farmer_name,
  os.code AS status_code,
  os.description AS status_description,
  pm.description AS payment_method_name
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN users cu ON cu.user_id = c.user_id
LEFT JOIN farmers f ON f.farmer_id = o.farmer_id
LEFT JOIN lookup_values os ON os.lookup_type = o.order_status_type AND os.lookup_value_id = o.order_status_id
LEFT JOIN lookup_values pm ON pm.lookup_type = o.payment_method_type AND pm.lookup_value_id = o.payment_method_id;

-- ============================================================================
-- STEP 10: Drop superseded tables and columns
-- ============================================================================

DROP VIEW IF EXISTS v_schema_validation CASCADE;
DROP VIEW IF EXISTS v_cancelled_orders CASCADE;
DROP VIEW IF EXISTS v_orders_with_delivery_method CASCADE;

DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
DROP POLICY IF EXISTS "Customers can view their own orders" ON orders;

ALTER TABLE order_status_logs DROP CONSTRAINT IF EXISTS order_status_logs_changed_by_fkey;
ALTER TABLE reported_content DROP CONSTRAINT IF EXISTS reported_content_reporter_id_fkey;
ALTER TABLE reported_content DROP CONSTRAINT IF EXISTS reported_content_resolved_by_fkey;

ALTER TABLE order_status_logs DROP COLUMN IF EXISTS changed_by;
ALTER TABLE reported_content DROP COLUMN IF EXISTS reporter_id;
ALTER TABLE reported_content DROP COLUMN IF EXISTS resolved_by;

DROP TABLE IF EXISTS farmer_crop_types CASCADE;
DROP TABLE IF EXISTS farmer_livestock CASCADE;
DROP TABLE IF EXISTS farmer_ratings CASCADE;
DROP TABLE IF EXISTS product_reviews CASCADE;
DROP TABLE IF EXISTS forum_post_likes CASCADE;
DROP TABLE IF EXISTS forum_comment_likes CASCADE;
DROP TABLE IF EXISTS product_images CASCADE;
DROP TABLE IF EXISTS review_images CASCADE;
DROP TABLE IF EXISTS product_inventory CASCADE;
DROP TABLE IF EXISTS farmer_registrations CASCADE;

DROP TABLE IF EXISTS order_statuses CASCADE;
DROP TABLE IF EXISTS payment_statuses CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS delivery_methods CASCADE;
DROP TABLE IF EXISTS cancellation_roles CASCADE;
DROP TABLE IF EXISTS content_types CASCADE;
DROP TABLE IF EXISTS notification_types CASCADE;
DROP TABLE IF EXISTS registration_statuses CASCADE;
DROP TABLE IF EXISTS verification_types CASCADE;

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

CREATE VIEW v_orders_with_delivery_method AS
SELECT
  o.*,
  dm.code AS delivery_method
FROM orders o
LEFT JOIN lookup_values dm
  ON dm.lookup_type = o.delivery_method_type
 AND dm.lookup_value_id = o.delivery_method_id;

CREATE VIEW v_schema_validation AS
SELECT
  'admin_articles'::text AS table_name,
  (SELECT COUNT(*) FROM admin_articles) AS total_rows,
  (SELECT COUNT(*) FROM admin_articles WHERE admin_id IS NULL) AS null_admin_id,
  (SELECT COUNT(*) FROM admin_articles WHERE title IS NULL) AS null_title,
  (SELECT COUNT(*) FROM admin_articles WHERE body IS NULL) AS null_body;

COMMIT;
