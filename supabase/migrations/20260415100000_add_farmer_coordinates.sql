-- Migration: Add precise farm coordinates to farmers profile
-- Purpose:
--   - Support exact farm pinning and map-based matching
--   - Keep existing text location fields for human-readable display

ALTER TABLE farmers
  ADD COLUMN IF NOT EXISTS farm_latitude double precision,
  ADD COLUMN IF NOT EXISTS farm_longitude double precision;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'farmers_farm_latitude_range'
  ) THEN
    ALTER TABLE farmers
      ADD CONSTRAINT farmers_farm_latitude_range
      CHECK (farm_latitude IS NULL OR (farm_latitude BETWEEN -90 AND 90));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'farmers_farm_longitude_range'
  ) THEN
    ALTER TABLE farmers
      ADD CONSTRAINT farmers_farm_longitude_range
      CHECK (farm_longitude IS NULL OR (farm_longitude BETWEEN -180 AND 180));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_farmers_farm_latitude ON farmers(farm_latitude);
CREATE INDEX IF NOT EXISTS idx_farmers_farm_longitude ON farmers(farm_longitude);

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
  COALESCE((
    SELECT SUM(total_amount)
    FROM orders
    WHERE farmer_id = f.farmer_id
      AND order_status_id = (
        SELECT order_status_id
        FROM order_statuses
        WHERE code = 'completed'
      )
  ), 0) AS total_sales,
  COALESCE((
    SELECT COUNT(*)
    FROM products
    WHERE farmer_id = f.farmer_id
      AND is_active = true
  ), 0) AS total_products,
  COALESCE((
    SELECT AVG(rating)
    FROM farmer_ratings
    WHERE farmer_id = f.farmer_id
  ), 0) AS average_rating,
  COALESCE((
    SELECT COUNT(*)
    FROM farmer_ratings
    WHERE farmer_id = f.farmer_id
  ), 0) AS total_reviews,
  f.farm_latitude,
  f.farm_longitude
FROM farmers f
JOIN users u ON f.user_id = u.user_id
LEFT JOIN farmer_registrations fr ON f.farmer_id = fr.farmer_id;
