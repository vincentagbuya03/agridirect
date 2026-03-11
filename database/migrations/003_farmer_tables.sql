-- ============================================================================
-- 003_farmer_tables.sql
-- Farmer profile and registration management
-- ============================================================================

-- ============================================================================
-- FARMER_PROFILES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_profiles (
    profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    farm_name TEXT NOT NULL,
    specialty TEXT,
    location TEXT,
    badge TEXT,
    image_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_farmer_profiles_user_id ON farmer_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_farmer_profiles_is_verified ON farmer_profiles(is_verified);

-- Trigger for auto-update timestamp
CREATE TRIGGER farmer_profiles_updated_at_trigger
BEFORE UPDATE ON farmer_profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FARMER_SPECIALIZATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_specializations (
    specialization_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    specialization TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for farmer lookups
CREATE INDEX IF NOT EXISTS idx_farmer_specializations_farmer_id ON farmer_specializations(farmer_id);

-- ============================================================================
-- FARMER_REGISTRATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_registrations (
    registration_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    birth_date TEXT,
    years_of_experience INTEGER,
    residential_address TEXT,
    face_photo_path TEXT,
    valid_id_path TEXT,
    farming_history TEXT,
    certification_accepted BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_farmer_registrations_user_id ON farmer_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_farmer_registrations_status ON farmer_registrations(status);

-- Trigger for auto-update timestamp
CREATE TRIGGER farmer_registrations_updated_at_trigger
BEFORE UPDATE ON farmer_registrations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FARMER_EDUCATION TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_education (
    education_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_id UUID NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
    level TEXT NOT NULL CHECK (level IN ('elementary', 'high_school', 'college', 'vocational', 'other')),
    school_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for registration lookups
CREATE INDEX IF NOT EXISTS idx_farmer_education_registration_id ON farmer_education(registration_id);

-- ============================================================================
-- FARMER_CROP_TYPES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_crop_types (
    crop_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_id UUID NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
    crop_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for registration lookups
CREATE INDEX IF NOT EXISTS idx_farmer_crop_types_registration_id ON farmer_crop_types(registration_id);

-- ============================================================================
-- FARMER_LIVESTOCK TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_livestock (
    livestock_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_id UUID NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
    livestock_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for registration lookups
CREATE INDEX IF NOT EXISTS idx_farmer_livestock_registration_id ON farmer_livestock(registration_id);
