-- Migration: Normalize farmer schema and fix redundancy
-- Purpose:
--   - Remove duplicated 'full_name' from farmer_registrations
--   - Ensure farmers table is the single source of truth for profile and identity data
--   - Update submit_complete_farmer_registration RPC to handle all identity fields
--   - Add coordinate constraints for farm location

BEGIN;

-- 1. Remove redundancy from farmer_registrations
ALTER TABLE public.farmer_registrations DROP COLUMN IF EXISTS full_name;

-- 2. Ensure farmers table has all required fields and constraints
DO $$ 
BEGIN
    -- Add columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='farmers' AND column_name='full_name') THEN
        ALTER TABLE public.farmers ADD COLUMN full_name text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='farmers' AND column_name='id_type') THEN
        ALTER TABLE public.farmers ADD COLUMN id_type text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='farmers' AND column_name='sex') THEN
        ALTER TABLE public.farmers ADD COLUMN sex text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='farmers' AND column_name='place_of_birth') THEN
        ALTER TABLE public.farmers ADD COLUMN place_of_birth text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='farmers' AND column_name='pcn') THEN
        ALTER TABLE public.farmers ADD COLUMN pcn text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='farmers' AND column_name='valid_id_back_path') THEN
        ALTER TABLE public.farmers ADD COLUMN valid_id_back_path text;
    END IF;

    -- Add constraints (safely)
    ALTER TABLE public.farmers DROP CONSTRAINT IF EXISTS farmers_farm_latitude_check;
    ALTER TABLE public.farmers ADD CONSTRAINT farmers_farm_latitude_check 
        CHECK (farm_latitude IS NULL OR (farm_latitude >= -90 AND farm_latitude <= 90));

    ALTER TABLE public.farmers DROP CONSTRAINT IF EXISTS farmers_farm_longitude_check;
    ALTER TABLE public.farmers ADD CONSTRAINT farmers_farm_longitude_check 
        CHECK (farm_longitude IS NULL OR (farm_longitude >= -180 AND farm_longitude <= 180));
END $$;

-- 3. Update the RPC to handle all fields and fix the 'location' bug
-- Drop all possible old signatures to be clean
DROP FUNCTION IF EXISTS public.submit_complete_farmer_registration(uuid, date, integer, text, text, text, text, text, text, text, jsonb, jsonb, jsonb);
DROP FUNCTION IF EXISTS public.submit_complete_farmer_registration(uuid, date, integer, text, text, text, double precision, double precision, text, text, text, jsonb, jsonb, jsonb);

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
  p_livestock_rows jsonb DEFAULT '[]'::jsonb
) RETURNS json AS $$
DECLARE
  v_registration_id uuid;
  v_farmer_id uuid;
BEGIN
  -- UPSERT into Farmers (Source of Truth)
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
    false, -- Reset verification on re-apply
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
    is_verified = false,
    is_active = true,
    updated_at = now()
  RETURNING farmer_id INTO v_farmer_id;

  -- 2. Create audit record (Status tracking)
  INSERT INTO public.farmer_registrations (farmer_id, status)
  VALUES (v_farmer_id, 'pending')
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
    'farmer_id', v_farmer_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
