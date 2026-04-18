-- 1. Create the Multi-Attempt Audit Table
CREATE TABLE IF NOT EXISTS farmer_registrations (
  registration_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  registration_status_id smallint NOT NULL DEFAULT 1 
    REFERENCES registration_statuses(registration_status_id),  -- ADDED
  reviewed_by uuid REFERENCES admins(admin_id),
  review_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. Define the refined Submission RPC
CREATE OR REPLACE FUNCTION submit_complete_farmer_registration(
    p_user_id uuid,
    p_birth_date date,
    p_years_of_experience integer,
    p_location text,              -- ADDED (farm location)
    p_residential_address text,
    p_farm_name text,
    p_specialty text,
    p_face_photo_path text,
    p_valid_id_path text,
    p_farming_history text,
    p_education_rows jsonb,
    p_crop_rows jsonb,
    p_livestock_rows jsonb
) RETURNS json AS $$
DECLARE
    v_registration_id uuid;
    v_farmer_id uuid;
BEGIN
    -- 1. UPSERT into Farmers
    INSERT INTO farmers (
        user_id, farm_name, specialty, location, birth_date, 
        years_of_experience, face_photo_path, valid_id_path, 
        residential_address, farming_history, is_verified, 
        is_active, registration_status_id
    ) VALUES (
        p_user_id, p_farm_name, p_specialty, p_location, p_birth_date,  -- FIXED: p_location
        p_years_of_experience, p_face_photo_path, p_valid_id_path,
        p_residential_address, p_farming_history, false, true, 1
    ) 
    ON CONFLICT (user_id) DO UPDATE SET
        farm_name = EXCLUDED.farm_name,
        specialty = EXCLUDED.specialty,
        location = EXCLUDED.location,          -- ADDED
        birth_date = EXCLUDED.birth_date,
        years_of_experience = EXCLUDED.years_of_experience,
        face_photo_path = EXCLUDED.face_photo_path,
        valid_id_path = EXCLUDED.valid_id_path,
        residential_address = EXCLUDED.residential_address,
        farming_history = EXCLUDED.farming_history,
        registration_status_id = 1,
        updated_at = now()
    RETURNING farmer_id INTO v_farmer_id;

    -- 2. ALWAYS INSERT a new audit record
    INSERT INTO farmer_registrations (farmer_id)  -- status defaults to 1 (pending)
    VALUES (v_farmer_id)
    RETURNING registration_id INTO v_registration_id;

    -- 3. Sync metadata tables
    DELETE FROM farmer_education WHERE farmer_id = v_farmer_id;
    INSERT INTO farmer_education (farmer_id, degree, institution, year_graduated)
    SELECT v_farmer_id, degree, institution, year_graduated 
    FROM jsonb_to_recordset(p_education_rows) AS x(degree text, institution text, year_graduated integer);

    DELETE FROM farmer_crop_types WHERE farmer_id = v_farmer_id;
    INSERT INTO farmer_crop_types (farmer_id, crop_type)
    SELECT v_farmer_id, crop_type 
    FROM jsonb_to_recordset(p_crop_rows) AS x(crop_type text);  -- REMOVED ON CONFLICT DO NOTHING

    DELETE FROM farmer_livestock WHERE farmer_id = v_farmer_id;
    INSERT INTO farmer_livestock (farmer_id, livestock_type)
    SELECT v_farmer_id, livestock_type 
    FROM jsonb_to_recordset(p_livestock_rows) AS x(livestock_type text);  -- REMOVED ON CONFLICT DO NOTHING

    RETURN json_build_object('success', true, 'registration_id', v_registration_id, 'farmer_id', v_farmer_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;