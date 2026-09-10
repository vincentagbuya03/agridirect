-- Migration: Clarify farmers table attributes
-- Adds explicit `logo_url` (farm store logo) and `cover_url` (farm store banner)
-- Backfills from existing `image_url`, `users.avatar_url`, and `face_photo_path`
BEGIN;

-- 1. Add dedicated columns for farm store logo and cover banner
ALTER TABLE public.farmers 
  ADD COLUMN IF NOT EXISTS logo_url text,
  ADD COLUMN IF NOT EXISTS cover_url text;

-- 2. Backfill logo_url directly from image_url (since image_url is the logo)
UPDATE public.farmers
SET logo_url = image_url
WHERE logo_url IS NULL
  AND image_url IS NOT NULL;

-- 3. If logo_url is still null, fallback to users.avatar_url (NEVER face_photo_path)
UPDATE public.farmers f
SET logo_url = u.avatar_url
FROM public.users u
WHERE f.user_id = u.user_id
  AND f.logo_url IS NULL
  AND u.avatar_url IS NOT NULL;

-- 4. Ensure image_url is kept populated from logo_url (image_url is the logo)
UPDATE public.farmers
SET image_url = logo_url
WHERE image_url IS NULL
  AND logo_url IS NOT NULL;

-- 5. Recreate v_farmer_profiles view to expose logo_url and cover_url
DROP VIEW IF EXISTS v_farmer_profiles CASCADE;

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
  f.logo_url,
  f.cover_url,
  f.image_url,
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
  COALESCE(f.image_url, f.logo_url, u.avatar_url) AS avatar_url,
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

COMMIT;
