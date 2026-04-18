-- Migration: Cleanup legacy compatibility columns
-- Purpose:
--   - Remove old merged-schema compatibility columns
--   - Keep schema aligned with current canonical design in supabase/database.sql
--   - Recreate dependent views after dropping legacy columns

BEGIN;

-- Drop views that may depend on compatibility columns.
DROP VIEW IF EXISTS v_orders_with_delivery_method CASCADE;
DROP VIEW IF EXISTS v_users_with_roles CASCADE;
DROP VIEW IF EXISTS v_farmer_profiles CASCADE;

-- Farmers / registrations: remove old registration lookup compatibility fields.
ALTER TABLE farmers
  DROP COLUMN IF EXISTS registration_status_type,
  DROP COLUMN IF EXISTS registration_status_id;

ALTER TABLE farmer_registrations
  DROP COLUMN IF EXISTS registration_status_id;

-- Orders / status logs: remove merged-lookup type marker fields.
ALTER TABLE orders
  DROP COLUMN IF EXISTS order_status_type,
  DROP COLUMN IF EXISTS delivery_method_type,
  DROP COLUMN IF EXISTS cancellation_role_type;

ALTER TABLE order_status_logs
  DROP COLUMN IF EXISTS order_status_type,
  DROP COLUMN IF EXISTS changed_by_user_id;

-- Reported content: keep canonical reporter_id/resolved_by fields only.
ALTER TABLE reported_content
  DROP COLUMN IF EXISTS content_type,
  DROP COLUMN IF EXISTS reporter_customer_id,
  DROP COLUMN IF EXISTS resolved_by_admin_id;

-- Notifications: remove event compatibility pointer not used in canonical schema.
ALTER TABLE notifications
  DROP COLUMN IF EXISTS notification_event_id;

-- User role bridge table should remain a pure join table.
ALTER TABLE user_roles
  DROP COLUMN IF EXISTS role_level,
  DROP COLUMN IF EXISTS is_active,
  DROP COLUMN IF EXISTS created_at,
  DROP COLUMN IF EXISTS updated_at;

-- Product inventory belongs in product_inventory table, not products.
ALTER TABLE products
  DROP COLUMN IF EXISTS available_quantity,
  DROP COLUMN IF EXISTS reserved_quantity,
  DROP COLUMN IF EXISTS low_stock_threshold,
  DROP COLUMN IF EXISTS inventory_updated_at;

-- Recreate views in canonical shape.
CREATE OR REPLACE VIEW v_orders_with_delivery_method AS
SELECT
  o.*
FROM orders o;

CREATE OR REPLACE VIEW v_users_with_roles AS
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
  r.role_id
FROM users u
LEFT JOIN user_roles ur ON u.user_id = ur.user_id
LEFT JOIN roles r ON ur.role_id = r.role_id;

CREATE OR REPLACE VIEW v_farmer_profiles AS
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
  COALESCE(fr.status, 'pending'::text) AS registration_status,
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
  COALESCE((SELECT SUM(total_amount) FROM orders WHERE farmer_id = f.farmer_id AND order_status_id = (SELECT order_status_id FROM order_statuses WHERE code = 'completed')), 0) AS total_sales,
  COALESCE((SELECT COUNT(*) FROM products WHERE farmer_id = f.farmer_id AND is_active = true), 0) AS total_products,
  COALESCE((SELECT AVG(rating) FROM farmer_ratings WHERE farmer_id = f.farmer_id), 0) AS average_rating,
  COALESCE((SELECT COUNT(*) FROM farmer_ratings WHERE farmer_id = f.farmer_id), 0) AS total_reviews
FROM farmers f
JOIN users u ON f.user_id = u.user_id
LEFT JOIN farmer_registrations fr ON f.farmer_id = fr.farmer_id;

COMMIT;
