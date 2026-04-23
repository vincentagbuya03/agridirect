-- Migration: Fix All Missing Columns and Views
-- Created at: 2026-04-22 01:00:00

-- 1. Fix farmers table identity fields
ALTER TABLE farmers 
ADD COLUMN IF NOT EXISTS id_type TEXT,
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS sex TEXT,
ADD COLUMN IF NOT EXISTS place_of_birth TEXT,
ADD COLUMN IF NOT EXISTS pcn TEXT;

-- 2. Drop existing views to ensure clean recreation
DROP VIEW IF EXISTS v_forum_posts CASCADE;
DROP VIEW IF EXISTS v_articles CASCADE;
DROP VIEW IF EXISTS v_farmer_profiles CASCADE;
DROP VIEW IF EXISTS v_orders CASCADE;

-- 3. Recreate v_forum_posts with correct columns
CREATE VIEW v_forum_posts AS
SELECT 
    p.post_id,
    u.name as author_name,
    p.created_at,
    p.title,
    p.body,
    p.image_url,
    COALESCE(l.likes_count, 0)::int as likes_count,
    COALESCE(c.comments_count, 0)::int as comments_count
FROM forum_posts p
JOIN users u ON p.user_id = u.user_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as likes_count 
    FROM forum_post_likes GROUP BY post_id
) l ON p.post_id = l.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as comments_count 
    FROM forum_comments GROUP BY post_id
) c ON p.post_id = c.post_id;

-- 4. Recreate v_articles with correct columns
CREATE VIEW v_articles AS
SELECT 
    article_id,
    title,
    summary as excerpt,
    'AgriDirect' as author_name,
    CASE 
        WHEN length(body) < 1000 THEN '3 min read'
        WHEN length(body) < 2500 THEN '5 min read'
        ELSE '8 min read'
    END as read_time,
    cover_image_url as image_url,
    is_published as published,
    created_at
FROM admin_articles;

-- 5. Update v_farmer_profiles to include full_name
CREATE VIEW v_farmer_profiles AS
SELECT
  f.farmer_id,
  f.user_id,
  f.farm_name,
  f.full_name,
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
  f.farm_latitude,
  f.farm_longitude
FROM farmers f
JOIN users u ON f.user_id = u.user_id
LEFT JOIN farmer_registrations fr ON f.farmer_id = fr.farmer_id;

-- 6. Update v_orders to include status and better joins
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
  u.name as customer_name,
  u.avatar_url as customer_image,
  f.farm_name as farmer_name,
  os.code as status,
  os.code as status_code,
  os.description as status_description,
  o.payment_method::text as payment_method_name,
  (
    SELECT string_agg(p.name || ' (x' || oi.quantity || ')', ', ')
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE oi.order_id = o.order_id
  ) as items
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN users u ON c.user_id = u.user_id
LEFT JOIN farmers f ON o.farmer_id = f.farmer_id
LEFT JOIN order_statuses os ON o.order_status_id = os.order_status_id;
