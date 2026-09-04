-- Migration: Add AI Auto-Verification columns and update submit_complete_farmer_registration RPC
-- Created at: 2026-09-04 00:00:00

BEGIN;

-- 1. Add AI Auto-Verification columns to farmers table
ALTER TABLE public.farmers
  ADD COLUMN IF NOT EXISTS verification_method text DEFAULT 'manual_admin',
  ADD COLUMN IF NOT EXISTS ai_confidence_score double precision DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ai_verification_notes text DEFAULT NULL;

-- 2. Add AI Auto-Verification columns to farmer_registrations table
ALTER TABLE public.farmer_registrations
  ADD COLUMN IF NOT EXISTS verification_method text DEFAULT 'manual_admin',
  ADD COLUMN IF NOT EXISTS ai_confidence_score double precision DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ai_verification_notes text DEFAULT NULL;

-- 3. Drop existing submit_complete_farmer_registration functions to avoid overload signature conflicts
DROP FUNCTION IF EXISTS public.submit_complete_farmer_registration(uuid, text, date, text, text, text, text, integer, text, text, text, double precision, double precision, text, text, text, text, jsonb, jsonb, jsonb);

-- 4. Recreate submit_complete_farmer_registration with AI Auto-Verification parameters
CREATE OR REPLACE FUNCTION public.submit_complete_farmer_registration(
  p_user_id uuid,
  p_full_name text,
  p_birth_date date,
  p_sex text,
  p_place_of_birth text,
  p_pcn text,
  p_id_type text,
  p_years_of_experience integer,
  p_residential_address text,
  p_farm_name text,
  p_specialty text,
  p_farm_latitude double precision DEFAULT NULL,
  p_farm_longitude double precision DEFAULT NULL,
  p_face_photo_path text DEFAULT NULL,
  p_valid_id_path text DEFAULT NULL,
  p_valid_id_back_path text DEFAULT NULL,
  p_farming_history text DEFAULT NULL,
  p_education_rows jsonb DEFAULT '[]'::jsonb,
  p_crop_rows jsonb DEFAULT '[]'::jsonb,
  p_livestock_rows jsonb DEFAULT '[]'::jsonb,
  p_is_verified boolean DEFAULT false,
  p_verification_method text DEFAULT 'manual_admin',
  p_confidence_score double precision DEFAULT NULL,
  p_review_notes text DEFAULT NULL
) RETURNS json AS $$
DECLARE
  v_registration_id uuid;
  v_farmer_id uuid;
  v_status text;
BEGIN
  -- Determine registration status
  IF p_is_verified IS TRUE THEN
    v_status := 'approved';
  ELSE
    v_status := 'pending';
  END IF;

  -- 1. UPSERT into Farmers (Source of Truth)
  INSERT INTO public.farmers (
    user_id,
    full_name,
    birth_date,
    sex,
    place_of_birth,
    pcn,
    id_type,
    farm_name,
    specialty,
    residential_address,
    farm_latitude,
    farm_longitude,
    years_of_experience,
    face_photo_path,
    valid_id_path,
    valid_id_back_path,
    farming_history,
    is_verified,
    verification_method,
    ai_confidence_score,
    ai_verification_notes,
    is_active,
    updated_at
  ) VALUES (
    p_user_id,
    p_full_name,
    p_birth_date,
    p_sex,
    p_place_of_birth,
    p_pcn,
    p_id_type,
    p_farm_name,
    p_specialty,
    p_residential_address,
    p_farm_latitude,
    p_farm_longitude,
    p_years_of_experience,
    p_face_photo_path,
    p_valid_id_path,
    p_valid_id_back_path,
    p_farming_history,
    p_is_verified,
    p_verification_method,
    p_confidence_score,
    p_review_notes,
    true,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    birth_date = EXCLUDED.birth_date,
    sex = EXCLUDED.sex,
    place_of_birth = EXCLUDED.place_of_birth,
    pcn = EXCLUDED.pcn,
    id_type = EXCLUDED.id_type,
    farm_name = EXCLUDED.farm_name,
    specialty = EXCLUDED.specialty,
    residential_address = EXCLUDED.residential_address,
    farm_latitude = COALESCE(EXCLUDED.farm_latitude, farmers.farm_latitude),
    farm_longitude = COALESCE(EXCLUDED.farm_longitude, farmers.farm_longitude),
    years_of_experience = EXCLUDED.years_of_experience,
    face_photo_path = EXCLUDED.face_photo_path,
    valid_id_path = EXCLUDED.valid_id_path,
    valid_id_back_path = EXCLUDED.valid_id_back_path,
    farming_history = EXCLUDED.farming_history,
    is_verified = EXCLUDED.is_verified,
    verification_method = EXCLUDED.verification_method,
    ai_confidence_score = EXCLUDED.ai_confidence_score,
    ai_verification_notes = EXCLUDED.ai_verification_notes,
    is_active = true,
    updated_at = now()
  RETURNING farmer_id INTO v_farmer_id;

  -- 2. Create audit record (Status tracking)
  INSERT INTO public.farmer_registrations (
    farmer_id,
    status,
    verification_method,
    ai_confidence_score,
    ai_verification_notes,
    review_notes,
    reviewed_at
  )
  VALUES (
    v_farmer_id,
    v_status,
    p_verification_method,
    p_confidence_score,
    p_review_notes,
    p_review_notes,
    CASE WHEN p_is_verified IS TRUE THEN now() ELSE NULL END
  )
  RETURNING registration_id INTO v_registration_id;

  -- 3. Sync metadata tables
  DELETE FROM public.farmer_education WHERE farmer_id = v_farmer_id;
  INSERT INTO public.farmer_education (farmer_id, degree, institution, year_graduated)
  SELECT v_farmer_id, x.degree, x.institution, x.year_graduated
  FROM jsonb_to_recordset(COALESCE(p_education_rows, '[]'::jsonb))
    AS x(degree text, institution text, year_graduated integer);

  DELETE FROM public.farmer_crop_types WHERE farmer_id = v_farmer_id;
  INSERT INTO public.farmer_crop_types (farmer_id, crop_type)
  SELECT v_farmer_id, x.crop_type
  FROM jsonb_to_recordset(COALESCE(p_crop_rows, '[]'::jsonb))
    AS x(crop_type text);

  DELETE FROM public.farmer_livestock WHERE farmer_id = v_farmer_id;
  INSERT INTO public.farmer_livestock (farmer_id, livestock_type)
  SELECT v_farmer_id, x.livestock_type
  FROM jsonb_to_recordset(COALESCE(p_livestock_rows, '[]'::jsonb))
    AS x(livestock_type text);

  RETURN json_build_object(
    'success', true,
    'registration_id', v_registration_id,
    'farmer_id', v_farmer_id,
    'is_verified', p_is_verified,
    'status', v_status
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Recreate v_farmer_profiles view to include AI verification details
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
  u.avatar_url,
  f.farm_latitude,
  f.farm_longitude,
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
