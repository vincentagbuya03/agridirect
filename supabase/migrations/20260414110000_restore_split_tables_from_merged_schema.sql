-- Migration: Restore split tables from merged schema and repair app-facing compatibility
-- Purpose:
--   - Recreate the original split lookup tables from lookup_values
--   - Restore split app-facing tables that were merged in 20260413130000
--   - Rebuild core views against the split schema
--   - Add compatibility columns expected by the current Flutter codebase
-- Notes:
--   - This migration is intentionally additive and conservative.
--   - Deprecated merged tables are left in place for now to avoid another destructive rewrite.

BEGIN;

-- ============================================================================
-- STEP 1: Restore separate lookup tables from lookup_values
-- ============================================================================

CREATE TABLE IF NOT EXISTS order_statuses (
  order_status_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_methods (
  payment_method_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_statuses (
  payment_status_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS delivery_methods (
  delivery_method_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cancellation_roles (
  cancellation_role_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS content_types (
  content_type_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_types (
  notification_type_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS registration_statuses (
  registration_status_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS verification_types (
  verification_type_id smallint PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO order_statuses (order_status_id, code, description, is_active, created_at, updated_at)
SELECT lookup_value_id, code, description, is_active, created_at, updated_at
FROM lookup_values
WHERE lookup_type = 'order_status'
ON CONFLICT (order_status_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = EXCLUDED.updated_at;

INSERT INTO payment_methods (payment_method_id, code, description, is_active, created_at, updated_at)
SELECT lookup_value_id, code, description, is_active, created_at, updated_at
FROM lookup_values
WHERE lookup_type = 'payment_method'
ON CONFLICT (payment_method_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = EXCLUDED.updated_at;

INSERT INTO payment_statuses (payment_status_id, code, description, is_active, created_at, updated_at)
SELECT lookup_value_id, code, description, is_active, created_at, updated_at
FROM lookup_values
WHERE lookup_type = 'payment_status'
ON CONFLICT (payment_status_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = EXCLUDED.updated_at;

INSERT INTO delivery_methods (delivery_method_id, code, description, is_active, created_at)
SELECT lookup_value_id, code, description, is_active, created_at
FROM lookup_values
WHERE lookup_type = 'delivery_method'
ON CONFLICT (delivery_method_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

INSERT INTO cancellation_roles (cancellation_role_id, code, description, is_active, created_at)
SELECT lookup_value_id, code, description, is_active, created_at
FROM lookup_values
WHERE lookup_type = 'cancellation_role'
ON CONFLICT (cancellation_role_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

INSERT INTO content_types (content_type_id, code, description, is_active, created_at)
SELECT lookup_value_id, code, description, is_active, created_at
FROM lookup_values
WHERE lookup_type = 'content_type'
ON CONFLICT (content_type_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

INSERT INTO notification_types (notification_type_id, code, name, description, created_at)
SELECT lookup_value_id, code, name, description, created_at
FROM lookup_values
WHERE lookup_type = 'notification_type'
ON CONFLICT (notification_type_id) DO UPDATE
SET code = EXCLUDED.code,
    name = EXCLUDED.name,
    description = EXCLUDED.description;

INSERT INTO registration_statuses (registration_status_id, code, description, is_active, created_at)
SELECT lookup_value_id, code, description, is_active, created_at
FROM lookup_values
WHERE lookup_type = 'registration_status'
ON CONFLICT (registration_status_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

INSERT INTO verification_types (verification_type_id, code, description, is_active, created_at)
SELECT lookup_value_id, code, description, is_active, created_at
FROM lookup_values
WHERE lookup_type = 'verification_type'
ON CONFLICT (verification_type_id) DO UPDATE
SET code = EXCLUDED.code,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

-- ============================================================================
-- STEP 2: Restore split app-facing tables and backfill them
-- ============================================================================

CREATE TABLE IF NOT EXISTS farmer_registrations (
  registration_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(user_id) ON DELETE CASCADE,
  farmer_id uuid UNIQUE REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  birth_date date,
  years_of_experience integer DEFAULT 0,
  residential_address text,
  farm_name text,
  specialty text,
  face_photo_path text,
  valid_id_path text,
  farming_history text,
  certification_accepted boolean DEFAULT false,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
  registration_status_id smallint NOT NULL DEFAULT 1,
  reviewed_by uuid REFERENCES admins(admin_id),
  review_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO farmer_registrations (
  farmer_id,
  user_id,
  birth_date,
  years_of_experience,
  residential_address,
  farm_name,
  specialty,
  face_photo_path,
  valid_id_path,
  farming_history,
  status,
  registration_status_id,
  reviewed_by,
  review_notes,
  created_at,
  updated_at
)
SELECT
  f.farmer_id,
  f.user_id,
  f.birth_date,
  COALESCE(f.years_of_experience, 0),
  f.residential_address,
  f.farm_name,
  f.specialty,
  f.face_photo_path,
  f.valid_id_path,
  f.farming_history,
  COALESCE(rs.code, 'pending'),
  f.registration_status_id,
  a.admin_id,
  f.review_notes,
  f.created_at,
  f.updated_at
FROM farmers f
LEFT JOIN registration_statuses rs
  ON rs.registration_status_id = f.registration_status_id
LEFT JOIN admins a
  ON a.user_id = f.reviewed_by_user_id
ON CONFLICT (farmer_id) DO UPDATE
SET user_id = EXCLUDED.user_id,
    birth_date = EXCLUDED.birth_date,
    years_of_experience = EXCLUDED.years_of_experience,
    residential_address = EXCLUDED.residential_address,
    farm_name = EXCLUDED.farm_name,
    specialty = EXCLUDED.specialty,
    face_photo_path = EXCLUDED.face_photo_path,
    valid_id_path = EXCLUDED.valid_id_path,
    farming_history = EXCLUDED.farming_history,
    status = EXCLUDED.status,
    registration_status_id = EXCLUDED.registration_status_id,
    reviewed_by = EXCLUDED.reviewed_by,
    review_notes = EXCLUDED.review_notes,
    updated_at = EXCLUDED.updated_at;

ALTER TABLE farmer_registrations
  DROP CONSTRAINT IF EXISTS fk_farmer_registrations_status,
  ADD CONSTRAINT fk_farmer_registrations_status
  FOREIGN KEY (registration_status_id)
  REFERENCES registration_statuses(registration_status_id);

CREATE TABLE IF NOT EXISTS farmer_crop_types (
  crop_type_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  crop_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (farmer_id, crop_type)
);

INSERT INTO farmer_crop_types (farmer_id, crop_type, created_at)
SELECT farmer_id, produce_name, created_at
FROM farmer_produce
WHERE produce_type = 'crop'
ON CONFLICT (farmer_id, crop_type) DO NOTHING;

CREATE TABLE IF NOT EXISTS farmer_livestock (
  livestock_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  livestock_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (farmer_id, livestock_type)
);

INSERT INTO farmer_livestock (farmer_id, livestock_type, created_at)
SELECT farmer_id, produce_name, created_at
FROM farmer_produce
WHERE produce_type = 'livestock'
ON CONFLICT (farmer_id, livestock_type) DO NOTHING;

CREATE TABLE IF NOT EXISTS product_inventory (
  inventory_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid UNIQUE NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  available_quantity numeric,
  reserved_quantity numeric,
  low_stock_threshold numeric,
  updated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO product_inventory (
  product_id,
  available_quantity,
  reserved_quantity,
  low_stock_threshold,
  updated_at,
  created_at
)
SELECT
  p.product_id,
  p.available_quantity,
  p.reserved_quantity,
  p.low_stock_threshold,
  p.inventory_updated_at,
  p.created_at
FROM products p
ON CONFLICT (product_id) DO UPDATE
SET available_quantity = EXCLUDED.available_quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    low_stock_threshold = EXCLUDED.low_stock_threshold,
    updated_at = EXCLUDED.updated_at;

CREATE TABLE IF NOT EXISTS product_images (
  image_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  image_url text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO product_images (image_id, product_id, image_url, sort_order, created_at)
SELECT attachment_id, target_id, media_url, sort_order, created_at
FROM media_attachments
WHERE target_type = 'product'
ON CONFLICT (image_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS product_reviews (
  review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(order_id) ON DELETE SET NULL,
  rating numeric NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  is_verified_purchase boolean NOT NULL DEFAULT false,
  helpful_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO product_reviews (
  review_id,
  product_id,
  customer_id,
  order_id,
  rating,
  review_text,
  is_verified_purchase,
  helpful_count,
  created_at,
  updated_at
)
SELECT
  r.review_id,
  r.product_id,
  c.customer_id,
  r.order_id,
  r.rating,
  r.review_text,
  r.is_verified_purchase,
  r.helpful_count,
  r.created_at,
  r.updated_at
FROM reviews r
JOIN customers c
  ON c.user_id = r.reviewer_user_id
WHERE r.review_type = 'product'
  AND r.product_id IS NOT NULL
ON CONFLICT (review_id) DO UPDATE
SET product_id = EXCLUDED.product_id,
    customer_id = EXCLUDED.customer_id,
    order_id = EXCLUDED.order_id,
    rating = EXCLUDED.rating,
    review_text = EXCLUDED.review_text,
    is_verified_purchase = EXCLUDED.is_verified_purchase,
    helpful_count = EXCLUDED.helpful_count,
    updated_at = EXCLUDED.updated_at;

CREATE TABLE IF NOT EXISTS review_images (
  image_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES product_reviews(review_id) ON DELETE CASCADE,
  image_url text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO review_images (image_id, review_id, image_url, sort_order, created_at)
SELECT attachment_id, target_id, media_url, sort_order, created_at
FROM media_attachments
WHERE target_type = 'review'
ON CONFLICT (image_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS farmer_ratings (
  rating_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(order_id) ON DELETE SET NULL,
  rating numeric NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  response_text text,
  response_date timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO farmer_ratings (
  rating_id,
  farmer_id,
  customer_id,
  order_id,
  rating,
  review_text,
  response_text,
  response_date,
  created_at
)
SELECT
  r.review_id,
  r.farmer_id,
  c.customer_id,
  r.order_id,
  r.rating,
  r.review_text,
  r.response_text,
  r.response_date,
  r.created_at
FROM reviews r
JOIN customers c
  ON c.user_id = r.reviewer_user_id
WHERE r.review_type = 'farmer'
  AND r.farmer_id IS NOT NULL
ON CONFLICT (rating_id) DO UPDATE
SET farmer_id = EXCLUDED.farmer_id,
    customer_id = EXCLUDED.customer_id,
    order_id = EXCLUDED.order_id,
    rating = EXCLUDED.rating,
    review_text = EXCLUDED.review_text,
    response_text = EXCLUDED.response_text,
    response_date = EXCLUDED.response_date,
    created_at = EXCLUDED.created_at;

CREATE TABLE IF NOT EXISTS forum_post_likes (
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

INSERT INTO forum_post_likes (user_id, post_id, created_at, updated_at)
SELECT user_id, target_id, created_at, updated_at
FROM forum_likes
WHERE target_type = 'post'
ON CONFLICT (user_id, post_id) DO UPDATE
SET updated_at = EXCLUDED.updated_at;

CREATE TABLE IF NOT EXISTS forum_comment_likes (
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  comment_id uuid NOT NULL REFERENCES forum_comments(comment_id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, comment_id)
);

INSERT INTO forum_comment_likes (user_id, comment_id, created_at, updated_at)
SELECT user_id, target_id, created_at, updated_at
FROM forum_likes
WHERE target_type = 'comment'
ON CONFLICT (user_id, comment_id) DO UPDATE
SET updated_at = EXCLUDED.updated_at;

-- ============================================================================
-- STEP 3: Restore compatibility columns on live tables
-- ============================================================================

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS notification_type_id smallint,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS body text,
  ADD COLUMN IF NOT EXISTS link_url text,
  ADD COLUMN IF NOT EXISTS link_type text,
  ADD COLUMN IF NOT EXISTS link_id uuid,
  ADD COLUMN IF NOT EXISTS expires_at timestamptz DEFAULT (now() + interval '90 days'),
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

UPDATE notifications n
SET
  notification_type_id = COALESCE(n.notification_type_id, ne.notification_type_id),
  title = COALESCE(n.title, ne.title),
  body = COALESCE(n.body, ne.body),
  link_url = COALESCE(n.link_url, ne.link_url),
  link_type = COALESCE(n.link_type, ne.link_type),
  link_id = COALESCE(n.link_id, ne.link_id),
  expires_at = COALESCE(n.expires_at, ne.expires_at)
FROM notification_events ne
WHERE ne.notification_event_id = n.notification_event_id;

ALTER TABLE notifications
  DROP CONSTRAINT IF EXISTS fk_notifications_type_id,
  ADD CONSTRAINT fk_notifications_type_id
  FOREIGN KEY (notification_type_id)
  REFERENCES notification_types(notification_type_id);

ALTER TABLE reported_content
  ADD COLUMN IF NOT EXISTS reporter_id uuid,
  ADD COLUMN IF NOT EXISTS resolved_by uuid,
  ADD COLUMN IF NOT EXISTS resolved_at timestamptz;

UPDATE reported_content rc
SET reporter_id = c.user_id
FROM customers c
WHERE c.customer_id = rc.reporter_customer_id
  AND rc.reporter_id IS NULL;

UPDATE reported_content rc
SET resolved_by = a.user_id
FROM admins a
WHERE a.admin_id = rc.resolved_by_admin_id
  AND rc.resolved_by IS NULL;

ALTER TABLE reported_content
  DROP CONSTRAINT IF EXISTS reported_content_status_check,
  DROP CONSTRAINT IF EXISTS chk_reported_content_status,
  ADD CONSTRAINT chk_reported_content_status
  CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed'));

ALTER TABLE reported_content
  DROP CONSTRAINT IF EXISTS fk_reported_content_reporter_id,
  ADD CONSTRAINT fk_reported_content_reporter_id
  FOREIGN KEY (reporter_id)
  REFERENCES users(user_id) ON DELETE CASCADE,
  DROP CONSTRAINT IF EXISTS fk_reported_content_resolved_by,
  ADD CONSTRAINT fk_reported_content_resolved_by
  FOREIGN KEY (resolved_by)
  REFERENCES users(user_id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 4: Rewire live foreign keys back to separate lookup tables
-- ============================================================================

ALTER TABLE farmers
  DROP CONSTRAINT IF EXISTS fk_farmers_registration_status,
  ADD CONSTRAINT fk_farmers_registration_status_id
  FOREIGN KEY (registration_status_id)
  REFERENCES registration_statuses(registration_status_id);

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS fk_orders_status_lookup,
  DROP CONSTRAINT IF EXISTS fk_orders_payment_method_lookup,
  DROP CONSTRAINT IF EXISTS fk_orders_delivery_method_lookup,
  DROP CONSTRAINT IF EXISTS fk_orders_cancel_role_lookup,
  DROP CONSTRAINT IF EXISTS fk_orders_order_status_id,
  DROP CONSTRAINT IF EXISTS fk_orders_payment_method_id,
  DROP CONSTRAINT IF EXISTS fk_orders_delivery_method_id,
  DROP CONSTRAINT IF EXISTS fk_orders_cancelled_by_role_id,
  ADD CONSTRAINT fk_orders_order_status_id
  FOREIGN KEY (order_status_id)
  REFERENCES order_statuses(order_status_id),
  ADD CONSTRAINT fk_orders_payment_method_id
  FOREIGN KEY (payment_method_id)
  REFERENCES payment_methods(payment_method_id),
  ADD CONSTRAINT fk_orders_delivery_method_id
  FOREIGN KEY (delivery_method_id)
  REFERENCES delivery_methods(delivery_method_id),
  ADD CONSTRAINT fk_orders_cancelled_by_role_id
  FOREIGN KEY (cancelled_by_role_id)
  REFERENCES cancellation_roles(cancellation_role_id);

ALTER TABLE payments
  DROP CONSTRAINT IF EXISTS fk_payments_status_lookup,
  DROP CONSTRAINT IF EXISTS fk_payments_method_lookup,
  DROP CONSTRAINT IF EXISTS fk_payments_status_id,
  DROP CONSTRAINT IF EXISTS fk_payments_method_id,
  ADD CONSTRAINT fk_payments_status_id
  FOREIGN KEY (payment_status_id)
  REFERENCES payment_statuses(payment_status_id),
  ADD CONSTRAINT fk_payments_method_id
  FOREIGN KEY (payment_method_id)
  REFERENCES payment_methods(payment_method_id);

ALTER TABLE order_status_logs
  DROP CONSTRAINT IF EXISTS fk_order_status_logs_lookup,
  DROP CONSTRAINT IF EXISTS fk_order_status_logs_order_status_id,
  ADD CONSTRAINT fk_order_status_logs_order_status_id
  FOREIGN KEY (order_status_id)
  REFERENCES order_statuses(order_status_id);

ALTER TABLE verification_codes
  DROP CONSTRAINT IF EXISTS fk_verification_codes_lookup,
  DROP CONSTRAINT IF EXISTS fk_verification_codes_type_id,
  ADD CONSTRAINT fk_verification_codes_type_id
  FOREIGN KEY (verification_type_id)
  REFERENCES verification_types(verification_type_id);

ALTER TABLE reported_content
  DROP CONSTRAINT IF EXISTS fk_reported_content_lookup,
  DROP CONSTRAINT IF EXISTS fk_reported_content_content_type_id,
  ADD CONSTRAINT fk_reported_content_content_type_id
  FOREIGN KEY (content_type_id)
  REFERENCES content_types(content_type_id);

-- ============================================================================
-- STEP 5: Rebuild views against the split schema
-- ============================================================================

DROP VIEW IF EXISTS v_customer_stats CASCADE;
CREATE VIEW v_customer_stats AS
SELECT
  c.user_id,
  COUNT(*)::bigint AS total_orders,
  COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM orders o
JOIN customers c
  ON c.customer_id = o.customer_id
GROUP BY c.user_id;

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
  (
    SELECT pi.image_url
    FROM product_images pi
    WHERE pi.product_id = p.product_id
    ORDER BY pi.sort_order ASC, pi.created_at ASC
    LIMIT 1
  ) AS image_url,
  COALESCE((
    SELECT AVG(pr.rating)
    FROM product_reviews pr
    WHERE pr.product_id = p.product_id
  ), 0) AS average_rating,
  COALESCE((
    SELECT COUNT(*)
    FROM product_reviews pr
    WHERE pr.product_id = p.product_id
  ), 0)::integer AS review_count,
  COALESCE((
    SELECT SUM(oi.quantity)
    FROM order_items oi
    WHERE oi.product_id = p.product_id
  ), 0) AS total_sold
FROM products p
LEFT JOIN farmers f
  ON f.farmer_id = p.farmer_id
LEFT JOIN categories c
  ON c.category_id = p.category_id
LEFT JOIN units u
  ON u.unit_id = p.unit_id;

DROP VIEW IF EXISTS v_farmer_stats CASCADE;
CREATE VIEW v_farmer_stats AS
SELECT
  f.farmer_id,
  COALESCE((
    SELECT SUM(o.total_amount)
    FROM orders o
    JOIN order_statuses os
      ON os.order_status_id = o.order_status_id
    WHERE o.farmer_id = f.farmer_id
      AND os.code = 'completed'
  ), 0) AS total_sales,
  COALESCE((
    SELECT COUNT(*)
    FROM products p
    WHERE p.farmer_id = f.farmer_id
      AND p.is_active = true
  ), 0)::bigint AS total_products,
  COALESCE((
    SELECT AVG(fr.rating)
    FROM farmer_ratings fr
    WHERE fr.farmer_id = f.farmer_id
  ), 0) AS average_rating,
  COALESCE((
    SELECT COUNT(*)
    FROM farmer_ratings fr
    WHERE fr.farmer_id = f.farmer_id
  ), 0)::bigint AS total_reviews
FROM farmers f;

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
  rs.code AS registration_status,
  fs.total_sales,
  fs.total_products,
  fs.average_rating,
  fs.total_reviews
FROM farmers f
JOIN users u
  ON u.user_id = f.user_id
LEFT JOIN registration_statuses rs
  ON rs.registration_status_id = f.registration_status_id
LEFT JOIN v_farmer_stats fs
  ON fs.farmer_id = f.farmer_id;

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
  cu.name AS customer_name,
  f.farm_name AS farmer_name,
  os.code AS status_code,
  os.description AS status_description,
  pm.description AS payment_method_name
FROM orders o
LEFT JOIN customers c
  ON c.customer_id = o.customer_id
LEFT JOIN users cu
  ON cu.user_id = c.user_id
LEFT JOIN farmers f
  ON f.farmer_id = o.farmer_id
LEFT JOIN order_statuses os
  ON os.order_status_id = o.order_status_id
LEFT JOIN payment_methods pm
  ON pm.payment_method_id = o.payment_method_id;

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
LEFT JOIN cancellation_roles cr
  ON cr.cancellation_role_id = o.cancelled_by_role_id
LEFT JOIN order_statuses os
  ON os.order_status_id = o.order_status_id
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
