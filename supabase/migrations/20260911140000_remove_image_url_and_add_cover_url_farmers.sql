-- Migration: Remove image_url from farmers table and ensure cover_url exists
-- Move all image_url values to logo_url before dropping image_url
BEGIN;

-- 1. Ensure logo_url and cover_url columns exist on public.farmers
ALTER TABLE public.farmers 
  ADD COLUMN IF NOT EXISTS logo_url text,
  ADD COLUMN IF NOT EXISTS cover_url text;

-- 2. Backfill logo_url from image_url if not already set
UPDATE public.farmers
SET logo_url = image_url
WHERE logo_url IS NULL
  AND image_url IS NOT NULL;

-- 3. Drop dependent views that reference f.image_url
DROP VIEW IF EXISTS public.v_farmer_profiles CASCADE;
DROP VIEW IF EXISTS public.v_orders CASCADE;

-- 4. Drop image_url column from farmers table
ALTER TABLE public.farmers DROP COLUMN IF EXISTS image_url CASCADE;

-- 5. Recreate v_farmer_profiles with logo_url and cover_url
CREATE VIEW public.v_farmer_profiles AS
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
  f.logo_url,
  f.cover_url,
  f.is_verified,
  f.verification_method,
  f.ai_confidence_score,
  f.ai_verification_notes,
  f.is_active,
  COALESCE(fr.status, 'pending'::text) AS registration_status,
  fr.review_notes,
  f.created_at,
  f.updated_at,
  f.birth_date,
  f.years_of_experience,
  f.face_photo_path,
  f.valid_id_path,
  f.valid_id_back_path,
  u.name AS farmer_name,
  u.email AS farmer_email,
  u.phone AS farmer_phone,
  COALESCE(f.logo_url, u.avatar_url) AS avatar_url,
  f.farm_latitude,
  f.farm_longitude,
  f.free_delivery_min_amount,
  -- Real Metrics
  COALESCE((
    SELECT SUM(o.total_amount) 
    FROM orders o 
    JOIN order_statuses os ON o.order_status_id = os.order_status_id
    WHERE o.farmer_id = f.farmer_id AND os.code = 'completed'
  ), 0) as total_sales,
  COALESCE((
    SELECT COUNT(*) 
    FROM products p 
    WHERE p.farmer_id = f.farmer_id AND p.is_active = true
  ), 0) as total_products,
  COALESCE((
    SELECT AVG(rating) 
    FROM farmer_ratings fr2 
    WHERE fr2.farmer_id = f.farmer_id
  ), 0.0) as average_rating,
  COALESCE((
    SELECT COUNT(*) 
    FROM farmer_ratings fr2 
    WHERE fr2.farmer_id = f.farmer_id
  ), 0) as total_reviews
FROM farmers f
JOIN users u ON f.user_id = u.user_id
LEFT JOIN farmer_registrations fr ON f.farmer_id = fr.farmer_id;

-- 6. Recreate v_orders using logo_url
CREATE VIEW public.v_orders AS
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
  f.farm_name as farm_name,
  f.farm_name as farmer_name,
  COALESCE(f.logo_url, fu.avatar_url) as farmer_avatar_url,
  os.code as status,
  os.code as status_code,
  os.description as status_description,
  (
    SELECT string_agg(p.name || ' (x' || oi.quantity || ')', ', ')
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE oi.order_id = o.order_id
  ) as items,
  (
    SELECT COUNT(*)::int
    FROM order_items
    WHERE order_id = o.order_id
  ) as item_count,
  EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE oi.order_id = o.order_id
      AND p.is_preorder = true
  ) as is_preorder
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN users u ON c.user_id = u.user_id
LEFT JOIN farmers f ON o.farmer_id = f.farmer_id
LEFT JOIN users fu ON f.user_id = fu.user_id
LEFT JOIN order_statuses os ON o.order_status_id = os.order_status_id;

COMMIT;
