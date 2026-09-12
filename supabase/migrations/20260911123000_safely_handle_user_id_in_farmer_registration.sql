-- Migration: Safely handle user ID in submit_complete_farmer_registration RPC
-- Prevents 22P02 invalid input syntax for type uuid: "" by accepting text and resolving to valid UUID / auth.uid()

BEGIN;

-- 1. Dynamically drop all existing overloads of submit_complete_farmer_registration in public schema
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc
        WHERE proname = 'submit_complete_farmer_registration'
          AND pronamespace = 'public'::regnamespace
    )
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE;';
    END LOOP;
END $$;

-- 2. Create the definitive single submit_complete_farmer_registration function
CREATE OR REPLACE FUNCTION public.submit_complete_farmer_registration(
  p_user_id text DEFAULT NULL,
  p_full_name text DEFAULT NULL,
  p_birth_date date DEFAULT NULL,
  p_sex text DEFAULT NULL,
  p_place_of_birth text DEFAULT NULL,
  p_pcn text DEFAULT NULL,
  p_id_type text DEFAULT NULL,
  p_years_of_experience integer DEFAULT 0,
  p_residential_address text DEFAULT NULL,
  p_farm_name text DEFAULT NULL,
  p_specialty text DEFAULT NULL,
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
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_effective_user_id uuid;
  v_farmer_id uuid;
  v_registration_id uuid;
  v_status text;
BEGIN
  -- Safely resolve effective user UUID from p_user_id or auth.uid()
  IF p_user_id IS NOT NULL AND trim(p_user_id) <> '' THEN
    BEGIN
      v_effective_user_id := trim(p_user_id)::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_effective_user_id := auth.uid();
    END;
  ELSE
    v_effective_user_id := auth.uid();
  END IF;

  IF v_effective_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Authentication required: User ID could not be determined. Please sign in.'
    );
  END IF;

  -- Determine registration status based on AI verification result
  IF p_is_verified IS TRUE THEN
    v_status := 'approved';
  ELSE
    v_status := 'pending';
  END IF;

  -- 0. Sync legal verified name from ID directly into users table (replaces Google OAuth name)
  IF p_full_name IS NOT NULL AND trim(p_full_name) <> '' THEN
    UPDATE public.users
    SET name = trim(p_full_name),
        updated_at = now()
    WHERE user_id = v_effective_user_id;
  END IF;

  -- 1. Upsert farmer master record
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
    v_effective_user_id,
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
    COALESCE(p_years_of_experience, 0),
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

  -- 4. Sync crops
  DELETE FROM public.farmer_crop_types WHERE farmer_id = v_farmer_id;
  INSERT INTO public.farmer_crop_types (farmer_id, crop_type)
  SELECT v_farmer_id, x.crop_type
  FROM jsonb_to_recordset(COALESCE(p_crop_rows, '[]'::jsonb))
    AS x(crop_type text);

  -- 5. Sync livestock
  DELETE FROM public.farmer_livestock WHERE farmer_id = v_farmer_id;
  INSERT INTO public.farmer_livestock (farmer_id, livestock_type)
  SELECT v_farmer_id, x.livestock_type
  FROM jsonb_to_recordset(COALESCE(p_livestock_rows, '[]'::jsonb))
    AS x(livestock_type text);

  -- 6. Return standard success payload
  RETURN jsonb_build_object(
    'success', true,
    'farmer_id', v_farmer_id,
    'registration_id', v_registration_id,
    'status', v_status,
    'is_verified', p_is_verified,
    'verification_method', p_verification_method,
    'confidence_score', p_confidence_score
  );
END;
$$;

-- Grant execution privileges
GRANT EXECUTE ON FUNCTION public.submit_complete_farmer_registration TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_complete_farmer_registration TO service_role;

COMMIT;
