-- ============================================================================
-- 001_init_core_tables.sql
-- Core authentication and user management tables
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for generation of random data
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ROLES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Insert default roles
INSERT INTO roles (name) VALUES 
    ('consumer'),
    ('seller'),
    ('admin')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- USERS TABLE (integrates with Supabase Auth)
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    bio TEXT,
    email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================================================
-- USER_ROLES TABLE (Junction table for many-to-many)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Index for role lookups
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);

-- ============================================================================
-- USER_ADDRESSES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_addresses (
    address_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    street TEXT NOT NULL,
    barangay TEXT NOT NULL,
    city TEXT NOT NULL,
    province TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_user_addresses_user_id ON user_addresses(user_id);

-- ============================================================================
-- VERIFICATION_CODES TABLE (for email verification)
-- ============================================================================
CREATE TABLE IF NOT EXISTS verification_codes (
    verification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_email TEXT NOT NULL UNIQUE,
    code TEXT NOT NULL,
    attempts INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_verification_codes_expires_at ON verification_codes(expires_at);

-- ============================================================================
-- AUTO-UPDATE TIMESTAMP FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for users
CREATE TRIGGER users_updated_at_trigger
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for user_addresses
CREATE TRIGGER user_addresses_updated_at_trigger
BEFORE UPDATE ON user_addresses
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
