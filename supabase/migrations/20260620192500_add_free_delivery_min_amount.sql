-- Migration: Add free_delivery_min_amount to farmers table and update v_farmer_profiles view
-- Created at: 2026-06-20 19:25:00

-- Add column to farmers table
ALTER TABLE public.farmers ADD COLUMN IF NOT EXISTS free_delivery_min_amount numeric DEFAULT 0 CHECK (free_delivery_min_amount >= 0);

-- Recreate view v_farmer_profiles to select the new column
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
  f.valid_id_back_path,
  u.name AS farmer_name,
  u.email AS farmer_email,
  u.phone AS farmer_phone,
  u.avatar_url,
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
