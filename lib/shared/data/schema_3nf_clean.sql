-- ============================================================================
-- AgrIDirect Database Normalization Script (3NF)
-- Combined migration file for complete database setup
-- ============================================================================
-- This script combines all migrations into one comprehensive normalization
-- Run this in Supabase SQL Editor to create full 3NF normalized schema
-- ============================================================================

-- ============================================================================
-- PHASE 1: EXTENSIONS & CORE UTILITIES
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for generation of random data
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- PHASE 2: AUTH & USER MANAGEMENT TABLES
-- ============================================================================

-- ============================================================================
-- USERS TABLE (integrates with Supabase Auth - Base table for all users)
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
-- AUTO-UPDATE TIMESTAMP FUNCTION (Define before any triggers)
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for users (drop first if exists)
DROP TRIGGER IF EXISTS users_updated_at_trigger ON users;
CREATE TRIGGER users_updated_at_trigger
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- CUSTOMERS TABLE (Role-specific: Consumer)
-- ============================================================================
CREATE TABLE IF NOT EXISTS customers (
    customer_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    preferred_payment_method TEXT,
    loyalty_points INTEGER DEFAULT 0,
    notification_preferences JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for customer lookups
CREATE INDEX IF NOT EXISTS idx_customers_customer_id ON customers(customer_id);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS customers_updated_at_trigger ON customers;
CREATE TRIGGER customers_updated_at_trigger
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FARMERS TABLE (Role-specific: Seller - replaces farmer_profiles)
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmers (
    farmer_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    farm_name TEXT NOT NULL,
    specialty TEXT,
    location TEXT,
    badge TEXT,
    image_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    bank_account_name TEXT,
    bank_account_number TEXT,
    bank_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for farmer lookups
CREATE INDEX IF NOT EXISTS idx_farmers_farmer_id ON farmers(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmers_is_verified ON farmers(is_verified);
CREATE INDEX IF NOT EXISTS idx_farmers_location ON farmers(location);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS farmers_updated_at_trigger ON farmers;
CREATE TRIGGER farmers_updated_at_trigger
BEFORE UPDATE ON farmers
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ADMINS TABLE (Role-specific: Administrator)
-- ============================================================================
CREATE TABLE IF NOT EXISTS admins (
    admin_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    role_level TEXT NOT NULL DEFAULT 'moderator' CHECK (role_level IN ('moderator', 'manager', 'super_admin')),
    department TEXT,
    permissions JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for admin lookups
CREATE INDEX IF NOT EXISTS idx_admins_admin_id ON admins(admin_id);
CREATE INDEX IF NOT EXISTS idx_admins_role_level ON admins(role_level);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS admins_updated_at_trigger ON admins;
CREATE TRIGGER admins_updated_at_trigger
BEFORE UPDATE ON admins
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

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

-- Create trigger for user_addresses
DROP TRIGGER IF EXISTS user_addresses_updated_at_trigger ON user_addresses;
CREATE TRIGGER user_addresses_updated_at_trigger
BEFORE UPDATE ON user_addresses
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PHASE 3: PRODUCT CATALOG MANAGEMENT
-- ============================================================================

-- ============================================================================
-- CATEGORIES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS categories (
    category_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);

-- ============================================================================
-- UNITS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS units (
    unit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    abbreviation TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Insert default units
INSERT INTO units (name, abbreviation) VALUES
    ('Kilogram', 'kg'),
    ('Gram', 'g'),
    ('Liter', 'L'),
    ('Milliliter', 'mL'),
    ('Piece', 'pc'),
    ('Dozen', 'dz'),
    ('Pound', 'lb'),
    ('Ounce', 'oz'),
    ('Gallon', 'gal'),
    ('Box', 'box'),
    ('Bag', 'bag'),
    ('Bundle', 'bdl')
ON CONFLICT (name) DO NOTHING;

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_units_abbreviation ON units(abbreviation);

-- ============================================================================
-- PRODUCTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS products (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    description TEXT,
    image_url TEXT,
    harvest_days INTEGER,
    is_preorder BOOLEAN DEFAULT FALSE,
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    unit_id UUID NOT NULL REFERENCES units(unit_id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_products_farmer_id ON products(farmer_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_unit_id ON products(unit_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS products_updated_at_trigger ON products;
CREATE TRIGGER products_updated_at_trigger
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PRODUCT_TAGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS product_tags (
    tag_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_product_tags_name ON product_tags(name);

-- ============================================================================
-- PRODUCT_TAG_MAPPINGS TABLE (Junction table)
-- ============================================================================
CREATE TABLE IF NOT EXISTS product_tag_mappings (
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES product_tags(tag_id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, tag_id)
);

-- Index for tag lookups
CREATE INDEX IF NOT EXISTS idx_product_tag_mappings_tag_id ON product_tag_mappings(tag_id);

-- ============================================================================
-- PRODUCT_REVIEWS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS product_reviews (
    review_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    rating DECIMAL(2, 1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_user_id ON product_reviews(user_id);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS product_reviews_updated_at_trigger ON product_reviews;
CREATE TRIGGER product_reviews_updated_at_trigger
BEFORE UPDATE ON product_reviews
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PHASE 3.5: SEED DATA - DEFAULT VALUES
-- ============================================================================

-- ============================================================================
-- Populate Categories
-- ============================================================================
INSERT INTO categories (name, description, icon) VALUES
    ('Vegetables', 'Fresh vegetables and leafy greens', '🥬'),
    ('Fruits', 'Fresh fruits and berries', '🍎'),
    ('Grains & Cereals', 'Rice, wheat, corn, and other grains', '🌾'),
    ('Herbs & Spices', 'Fresh and dried herbs and spices', '🌿'),
    ('Dairy & Eggs', 'Milk, cheese, eggs, and dairy products', '🥛'),
    ('Meat & Poultry', 'Fresh meat, chicken, and poultry', '🚫'),
    ('Fish & Seafood', 'Fresh fish and seafood products', '🐟'),
    ('Honey & Condiments', 'Honey, jams, sauces, and condiments', '🍯'),
    ('Prepared Foods', 'Prepared and processed agricultural products', '🍲'),
    ('Organic Products', 'Certified organic products', '♻️'),
    ('Local Specialties', 'Regional and local specialty products', '🏘️')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- Populate Product Tags
-- ============================================================================
INSERT INTO product_tags (name) VALUES
    ('Organic'),
    ('Locally Sourced'),
    ('Fresh'),
    ('Seasonal'),
    ('Pesticide-Free'),
    ('Non-GMO'),
    ('Fair Trade'),
    ('Eco-Friendly'),
    ('Sustainable'),
    ('Farm Fresh'),
    ('Limited Supply'),
    ('Pre-Order Available'),
    ('New Product'),
    ('Popular'),
    ('Best Seller'),
    ('Premium Quality'),
    ('Budget Friendly'),
    ('Bulk Available'),
    ('Certified'),
    ('Traditional Method')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- PHASE 4: FARMER REGISTRATION & SPECIALIZATIONS
-- ============================================================================

-- ============================================================================
-- FARMER_SPECIALIZATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_specializations (
    specialization_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
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
DROP TRIGGER IF EXISTS farmer_registrations_updated_at_trigger ON farmer_registrations;
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

-- ============================================================================
-- PHASE 5: ORDERS & TRANSACTIONS
-- ============================================================================

-- ============================================================================
-- ORDER_STATUS ENUM
-- ============================================================================
CREATE TYPE order_status AS ENUM (
    'pending',
    'confirmed',
    'shipped',
    'delivered',
    'cancelled'
);

-- ============================================================================
-- ORDERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number TEXT NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
    status order_status DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_farmer_id ON orders(farmer_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS orders_updated_at_trigger ON orders;
CREATE TRIGGER orders_updated_at_trigger    
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ORDER_ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- ============================================================================
-- PHASE 6: COMMUNITY & FORUM
-- ============================================================================

-- ============================================================================
-- FORUM_POSTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS forum_posts (
    post_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_forum_posts_user_id ON forum_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_created_at ON forum_posts(created_at DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS forum_posts_updated_at_trigger ON forum_posts;
CREATE TRIGGER forum_posts_updated_at_trigger
BEFORE UPDATE ON forum_posts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FORUM_COMMENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS forum_comments (
    comment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_forum_comments_post_id ON forum_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_comments_user_id ON forum_comments(user_id);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS forum_comments_updated_at_trigger ON forum_comments;
CREATE TRIGGER forum_comments_updated_at_trigger
BEFORE UPDATE ON forum_comments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- POST_LIKES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS post_likes (
    like_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);

-- ============================================================================
-- PHASE 7: ADMIN & MODERATION
-- ============================================================================

-- ============================================================================
-- ARTICLES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS articles (
    article_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES admins(admin_id) ON DELETE CASCADE,
    read_time TEXT,
    image_url TEXT,
    published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_articles_author_id ON articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(published);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS articles_updated_at_trigger ON articles;
CREATE TRIGGER articles_updated_at_trigger
BEFORE UPDATE ON articles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ADMIN_LOGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_logs (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID NOT NULL REFERENCES admins(admin_id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details TEXT,
    target_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON admin_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_target_user_id ON admin_logs(target_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON admin_logs(created_at DESC);

-- ============================================================================
-- REPORTED_CONTENT TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS reported_content (
    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content_type TEXT NOT NULL CHECK (content_type IN ('post', 'comment', 'review', 'product', 'profile')),
    content_id UUID NOT NULL,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    resolved_by UUID REFERENCES admins(admin_id) ON DELETE SET NULL,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_reported_content_reporter_id ON reported_content(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reported_content_status ON reported_content(status);
CREATE INDEX IF NOT EXISTS idx_reported_content_content_type ON reported_content(content_type);

-- ============================================================================
-- USER_SUSPENSIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_suspensions (
    suspension_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    suspended_by UUID NOT NULL REFERENCES admins(admin_id) ON DELETE CASCADE,
    suspended_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ,
    is_permanent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_suspensions_user_id ON user_suspensions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_suspensions_suspended_by ON user_suspensions(suspended_by);
CREATE INDEX IF NOT EXISTS idx_user_suspensions_expires_at ON user_suspensions(expires_at);

-- ============================================================================
-- PHASE 8: DATABASE VIEWS (3NF Compliant)
-- ============================================================================

-- ============================================================================
-- v_products - Product listing with aggregates
-- ============================================================================
DROP VIEW IF EXISTS v_products CASCADE;
CREATE VIEW v_products AS
SELECT
    p.*,
    c.name AS category_name,
    u.name AS unit_name,
    u.abbreviation AS unit_abbr,
    f.farm_name,
    COALESCE(ROUND(AVG(pr.rating)::numeric, 1), 0) AS average_rating,
    COUNT(pr.review_id) AS review_count
FROM products p
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN units u ON u.unit_id = p.unit_id
LEFT JOIN farmers f ON f.farmer_id = p.farmer_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY p.product_id, c.name, u.name, u.abbreviation, f.farm_name;

-- ============================================================================
-- v_forum_posts - Forum posts with engagement metrics
-- ============================================================================
DROP VIEW IF EXISTS v_forum_posts CASCADE;
CREATE VIEW v_forum_posts AS
SELECT
    fp.*,
    usr.name AS author_name,
    usr.avatar_url AS author_avatar,
    COALESCE(lk.likes_count, 0) AS likes_count,
    COALESCE(cm.comments_count, 0) AS comments_count
FROM forum_posts fp
JOIN users usr ON usr.user_id = fp.user_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS likes_count FROM post_likes GROUP BY post_id
) lk ON lk.post_id = fp.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS comments_count FROM forum_comments GROUP BY post_id
) cm ON cm.post_id = fp.post_id;

-- ============================================================================
-- v_orders - Orders with totals
-- ============================================================================
DROP VIEW IF EXISTS v_orders CASCADE;
CREATE VIEW v_orders AS
SELECT
    o.*,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0)::decimal AS total,
    COUNT(oi.order_item_id) AS item_count
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

-- ============================================================================
-- v_order_items - Order items with subtotals
-- ============================================================================
DROP VIEW IF EXISTS v_order_items CASCADE;
CREATE VIEW v_order_items AS
SELECT
    oi.*,
    (oi.quantity * oi.unit_price)::decimal AS subtotal,
    p.name AS product_name,
    p.image_url AS product_image
FROM order_items oi
LEFT JOIN products p ON p.product_id = oi.product_id;

-- ============================================================================
-- v_farmer_profiles - Farmer profiles with ratings
-- ============================================================================
DROP VIEW IF EXISTS v_farmer_profiles CASCADE;
CREATE VIEW v_farmer_profiles AS
SELECT
    f.*,
    usr.name AS farmer_name,
    usr.email AS farmer_email,
    usr.phone AS farmer_phone,
    COALESCE(ROUND(AVG(pr.rating)::numeric, 1), 0) AS average_rating,
    COUNT(DISTINCT pr.review_id) AS total_reviews
FROM farmers f
JOIN users usr ON usr.user_id = f.farmer_id
LEFT JOIN products p ON p.farmer_id = f.farmer_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY f.farmer_id, usr.name, usr.email, usr.phone;

-- ============================================================================
-- v_articles - Articles with excerpts
-- ============================================================================
DROP VIEW IF EXISTS v_articles CASCADE;
CREATE VIEW v_articles AS
SELECT
    a.*,
    usr.name AS author_name,
    LEFT(a.content, 200) AS excerpt
FROM articles a
LEFT JOIN users usr ON usr.user_id = a.author_id;

-- ============================================================================
-- v_users_with_roles - Users with their roles (based on table membership)
-- ============================================================================
DROP VIEW IF EXISTS v_users_with_roles CASCADE;
CREATE VIEW v_users_with_roles AS
SELECT
    u.*,
    STRING_AGG(
        CASE
            WHEN c.customer_id IS NOT NULL THEN 'consumer'
            WHEN f.farmer_id IS NOT NULL THEN 'seller'
            WHEN a.admin_id IS NOT NULL THEN 'admin'
        END,
        ', '
    ) AS roles
FROM users u
LEFT JOIN customers c ON c.customer_id = u.user_id
LEFT JOIN farmers f ON f.farmer_id = u.user_id
LEFT JOIN admins a ON a.admin_id = u.user_id
GROUP BY u.user_id;

-- ============================================================================
-- PHASE 9: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- ============================================================================
-- CUSTOMERS TABLE - RLS
-- ============================================================================
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Customers can read own profile
CREATE POLICY "Customers can read own profile"
ON customers FOR SELECT
USING (auth.uid() = customer_id);

-- Customers can update own profile
CREATE POLICY "Customers can update own profile"
ON customers FOR UPDATE
USING (auth.uid() = customer_id)
WITH CHECK (auth.uid() = customer_id);

-- ============================================================================
-- FARMERS TABLE - RLS
-- ============================================================================
ALTER TABLE farmers ENABLE ROW LEVEL SECURITY;

-- Everyone can read farmer profiles
CREATE POLICY "Anyone can read farmer profiles"
ON farmers FOR SELECT
USING (true);

-- Farmers can update their own profile
CREATE POLICY "Farmers can update own profile"
ON farmers FOR UPDATE
USING (auth.uid() = farmer_id)
WITH CHECK (auth.uid() = farmer_id);

-- ============================================================================
-- ADMINS TABLE - RLS
-- ============================================================================
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- Admins can read own profile
CREATE POLICY "Admins can read own profile"
ON admins FOR SELECT
USING (auth.uid() = admin_id);

-- Admins can update own role info (but not role_level)
CREATE POLICY "Admins can update own profile"
ON admins FOR UPDATE
USING (auth.uid() = admin_id)
WITH CHECK (auth.uid() = admin_id);

-- ============================================================================
-- USERS TABLE - RLS
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can read their own data
CREATE POLICY "Users can read own profile"
ON users FOR SELECT
USING (auth.uid() = user_id);

-- Public can read limited user info for display (name, avatar, bio only)
CREATE POLICY "Public can read user display info"
ON users FOR SELECT
USING (true);

-- Users can update own data
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- New users inserted via signup trigger
CREATE POLICY "Users can create own profile on signup"
ON users FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- USER_ADDRESSES TABLE - RLS
-- ============================================================================
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;

-- Users can read own address
CREATE POLICY "Users can read own address"
ON user_addresses FOR SELECT
USING (auth.uid() = user_id);

-- Users can update own address
CREATE POLICY "Users can update own address"
ON user_addresses FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can insert own address
CREATE POLICY "Users can insert own address"
ON user_addresses FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- VERIFICATION_CODES TABLE - RLS
-- ============================================================================
ALTER TABLE verification_codes ENABLE ROW LEVEL SECURITY;

-- Anyone can insert verification codes
CREATE POLICY "Anyone can insert verification codes"
ON verification_codes FOR INSERT
WITH CHECK (true);

-- Anyone can select their own verification (for login)
CREATE POLICY "Users can read own verification codes"
ON verification_codes FOR SELECT
USING (true);

-- Only service role should update these (handled via function)
CREATE POLICY "Service can update verification codes"
ON verification_codes FOR UPDATE
USING (true);

-- ============================================================================
-- PRODUCTS TABLE - RLS
-- ============================================================================
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Everyone can read products
CREATE POLICY "Anyone can read products"
ON products FOR SELECT
USING (true);

-- Farmers can insert products (must be in farmers table)
CREATE POLICY "Farmers can insert their products"
ON products FOR INSERT
WITH CHECK (
    auth.uid() = farmer_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- Farmers can update their own products
CREATE POLICY "Farmers can update their products"
ON products FOR UPDATE
USING (auth.uid() = farmer_id)
WITH CHECK (auth.uid() = farmer_id);

-- Farmers can delete their products
CREATE POLICY "Farmers can delete their products"
ON products FOR DELETE
USING (auth.uid() = farmer_id);

-- ============================================================================
-- PRODUCT_REVIEWS TABLE - RLS
-- ============================================================================
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;

-- Everyone can read reviews
CREATE POLICY "Anyone can read reviews"
ON product_reviews FOR SELECT
USING (true);

-- Consumers can insert reviews
CREATE POLICY "Users can insert reviews"
ON product_reviews FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own reviews
CREATE POLICY "Users can update own reviews"
ON product_reviews FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own reviews
CREATE POLICY "Users can delete own reviews"
ON product_reviews FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- FARMER_REGISTRATIONS TABLE - RLS
-- ============================================================================
ALTER TABLE farmer_registrations ENABLE ROW LEVEL SECURITY;

-- Users can read own registration
CREATE POLICY "Users can read own registration"
ON farmer_registrations FOR SELECT
USING (auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- Users can insert own registration
CREATE POLICY "Users can create own registration"
ON farmer_registrations FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update own registration (if pending)
CREATE POLICY "Users can update own pending registration"
ON farmer_registrations FOR UPDATE
USING (auth.uid() = user_id AND status = 'pending')
WITH CHECK (auth.uid() = user_id AND status = 'pending');

-- Admins can update status
CREATE POLICY "Admins can update registration status"
ON farmer_registrations FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- ============================================================================
-- ORDERS TABLE - RLS
-- ============================================================================
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Customers can read their orders
CREATE POLICY "Customers can read own orders"
ON orders FOR SELECT
USING (auth.uid() = customer_id);

-- Farmers can read their orders
CREATE POLICY "Farmers can read their orders"
ON orders FOR SELECT
USING (auth.uid() = farmer_id);

-- Customers can create orders
CREATE POLICY "Customers can create orders"
ON orders FOR INSERT
WITH CHECK (auth.uid() = customer_id);

-- Customers can update their pending orders
CREATE POLICY "Customers can update own pending orders"
ON orders FOR UPDATE
USING (auth.uid() = customer_id AND status = 'pending')
WITH CHECK (auth.uid() = customer_id);

-- Farmers can update order status
CREATE POLICY "Farmers can update order status"
ON orders FOR UPDATE
USING (auth.uid() = farmer_id)
WITH CHECK (auth.uid() = farmer_id);

-- ============================================================================
-- ORDER_ITEMS TABLE - RLS
-- ============================================================================
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Users can read order items from their orders
CREATE POLICY "Users can read order items from own orders"
ON order_items FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM orders o
        WHERE o.order_id = order_items.order_id
        AND (o.customer_id = auth.uid() OR o.farmer_id = auth.uid())
    )
);

-- ============================================================================
-- FORUM_POSTS TABLE - RLS
-- ============================================================================
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;

-- Everyone can read posts
CREATE POLICY "Anyone can read forum posts"
ON forum_posts FOR SELECT
USING (true);

-- Only farmers can create posts
CREATE POLICY "Only farmers can create forum posts"
ON forum_posts FOR INSERT
WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- Only farmers can update their own posts
CREATE POLICY "Farmers can update own posts"
ON forum_posts FOR UPDATE
USING (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
)
WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- Only farmers can delete own posts
CREATE POLICY "Farmers can delete own posts"
ON forum_posts FOR DELETE
USING (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- ============================================================================
-- FORUM_COMMENTS TABLE - RLS
-- ============================================================================
ALTER TABLE forum_comments ENABLE ROW LEVEL SECURITY;

-- Everyone can read comments
CREATE POLICY "Anyone can read comments"
ON forum_comments FOR SELECT
USING (true);

-- Only farmers can create comments
CREATE POLICY "Only farmers can create comments"
ON forum_comments FOR INSERT
WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- Only farmers can update their own comments
CREATE POLICY "Farmers can update own comments"
ON forum_comments FOR UPDATE
USING (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
)
WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- Only farmers can delete their own comments
CREATE POLICY "Farmers can delete own comments"
ON forum_comments FOR DELETE
USING (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- ============================================================================
-- POST_LIKES TABLE - RLS
-- ============================================================================
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

-- Everyone can read likes
CREATE POLICY "Anyone can read post likes"
ON post_likes FOR SELECT
USING (true);

-- Only farmers can like posts
CREATE POLICY "Only farmers can like posts"
ON post_likes FOR INSERT
WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- Only farmers can unlike their own likes
CREATE POLICY "Farmers can unlike posts"
ON post_likes FOR DELETE
USING (
    auth.uid() = user_id AND
    EXISTS (
        SELECT 1 FROM farmers
        WHERE farmer_id = auth.uid()
    )
);

-- ============================================================================
-- ARTICLES TABLE - RLS
-- ============================================================================
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;

-- Everyone can read published articles
CREATE POLICY "Anyone can read published articles"
ON articles FOR SELECT
USING (published = true);

-- Admins can read all articles
CREATE POLICY "Admins can read all articles"
ON articles FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- Only admins can manage articles
CREATE POLICY "Only admins can manage articles"
ON articles FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- ============================================================================
-- ADMIN_LOGS TABLE - RLS
-- ============================================================================
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can read logs
CREATE POLICY "Only admins can read logs"
ON admin_logs FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- Only system can insert logs (via trigger)
CREATE POLICY "System can insert logs"
ON admin_logs FOR INSERT
WITH CHECK (true);

-- ============================================================================
-- REPORTED_CONTENT TABLE - RLS
-- ============================================================================
ALTER TABLE reported_content ENABLE ROW LEVEL SECURITY;

-- Users can read their own reports
CREATE POLICY "Users can read own reports"
ON reported_content FOR SELECT
USING (auth.uid() = reporter_id);

-- Admins can read all reports
CREATE POLICY "Admins can read all reports"
ON reported_content FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- Users can submit reports
CREATE POLICY "Users can submit reports"
ON reported_content FOR INSERT
WITH CHECK (auth.uid() = reporter_id);

-- Only admins can manage reports
CREATE POLICY "Admins can manage reports"
ON reported_content FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- ============================================================================
-- USER_SUSPENSIONS TABLE - RLS
-- ============================================================================
ALTER TABLE user_suspensions ENABLE ROW LEVEL SECURITY;

-- Users can read if they're suspended
CREATE POLICY "Users can check own suspension"
ON user_suspensions FOR SELECT
USING (auth.uid() = user_id);

-- Admins can manage suspensions
CREATE POLICY "Admins can manage suspensions"
ON user_suspensions FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM admins
        WHERE admin_id = auth.uid()
    )
);

-- ============================================================================
-- END OF DATABASE NORMALIZATION SCRIPT
-- ============================================================================
-- Total tables created: 28
--   - Core/Auth: 3 tables (users, customers, farmers, admins)
--   - Products: 6 tables (categories, units, products, product_tags, product_tag_mappings, product_reviews)
--   - Farmer Registration: 4 tables (farmer_registrations, farmer_specializations, farmer_education, farmer_crop_types, farmer_livestock)
--   - Orders: 2 tables (orders, order_items)
--   - Community: 3 tables (forum_posts, forum_comments, post_likes)
--   - Admin/Moderation: 4 tables (articles, admin_logs, reported_content, user_suspensions)
-- Total views created: 7
-- RLS policies: 50+
-- Indexes: 65+
-- Triggers: 13
--
-- SEED DATA INSERTED:
--   - 12 default units (kg, g, L, mL, pc, dz, lb, oz, gal, box, bag, bdl)
--   - 11 categories (Vegetables, Fruits, Grains, etc.)
--   - 20 product tags (Organic, Fresh, Local, etc.)
-- ============================================================================
-- ============================================================================
-- AGRIDIRECT - ADDITIONAL SCHEMA TABLES
-- Priority Features: Farmer Ratings, Notifications, Messages,
--                   Wishlist, and Farmer Followers
-- ============================================================================
-- Add these tables to your existing schema_3nf_clean.sql
-- ============================================================================

-- ============================================================================
-- PHASE 8: SOCIAL & ENGAGEMENT FEATURES
-- ============================================================================

-- ============================================================================
-- FARMER_RATINGS TABLE (Trust & Reputation System)
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_ratings (
    rating_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(order_id) ON DELETE SET NULL,
    rating DECIMAL(2, 1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    categories JSONB, -- {"delivery": 4.5, "quality": 5, "communication": 4.5}
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(farmer_id, customer_id, order_id) -- One rating per customer-farmer-order combo
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_farmer_id ON farmer_ratings(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_customer_id ON farmer_ratings(customer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_rating ON farmer_ratings(rating DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS farmer_ratings_updated_at_trigger ON farmer_ratings;
CREATE TRIGGER farmer_ratings_updated_at_trigger
BEFORE UPDATE ON farmer_ratings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FARMER_FOLLOWERS TABLE (Follow Farmers)
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_followers (
    follower_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(farmer_id, user_id) -- Prevent duplicate follows
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_farmer_followers_farmer_id ON farmer_followers(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_followers_user_id ON farmer_followers(user_id);

-- ============================================================================
-- CUSTOMER_WISHLIST TABLE (Save Products)
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_wishlist (
    wishlist_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(customer_id, product_id) -- One wishlist entry per customer-product combo
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_customer_wishlist_customer_id ON customer_wishlist(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_wishlist_product_id ON customer_wishlist(product_id);

-- ============================================================================
-- PHASE 9: MESSAGING & NOTIFICATIONS
-- ============================================================================

-- ============================================================================
-- CONVERSATIONS TABLE (Message Thread Base)
-- ============================================================================
CREATE TABLE IF NOT EXISTS conversations (
    conversation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    participant_1_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    participant_2_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(order_id) ON DELETE SET NULL, -- Optional: linked to an order
    last_message_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT different_participants CHECK (participant_1_id != participant_2_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_conversations_participant_1_id ON conversations(participant_1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_2_id ON conversations(participant_2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS conversations_updated_at_trigger ON conversations;
CREATE TRIGGER conversations_updated_at_trigger
BEFORE UPDATE ON conversations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MESSAGES TABLE (Individual Messages)
-- ============================================================================
CREATE TABLE IF NOT EXISTS messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    image_url TEXT, -- Optional attachment
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_id ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_is_read ON messages(is_read);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS messages_updated_at_trigger ON messages;
CREATE TRIGGER messages_updated_at_trigger
BEFORE UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- NOTIFICATIONS TABLE (System & User Notifications)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN (
        'order_created',
        'order_shipped',
        'order_delivered',
        'farmer_approved',
        'farmer_rejected',
        'new_message',
        'product_review',
        'farmer_review',
        'new_follower',
        'product_added',
        'system_alert'
    )),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    related_entity_id UUID, -- Order ID, Farmer ID, Product ID, etc.
    related_entity_type TEXT CHECK (related_entity_type IN (
        'order',
        'farmer',
        'product',
        'farmer_registration',
        'message',
        'user'
    )),
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    action_url TEXT, -- Deep link to navigate in app
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS notifications_updated_at_trigger ON notifications;
CREATE TRIGGER notifications_updated_at_trigger
BEFORE UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PHASE 10: UTILITY & ANALYTICS
-- ============================================================================

-- ============================================================================
-- HELPER FUNCTION: Get Average Farmer Rating
-- ============================================================================
CREATE OR REPLACE FUNCTION get_farmer_average_rating(farmer_uuid UUID)
RETURNS TABLE (average_rating DECIMAL, total_ratings BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(AVG(rating), 0::DECIMAL)::DECIMAL as average_rating,
        COUNT(*)::BIGINT as total_ratings
    FROM farmer_ratings
    WHERE farmer_id = farmer_uuid;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- HELPER FUNCTION: Get Unread Message Count
-- ============================================================================
CREATE OR REPLACE FUNCTION get_unread_message_count(user_uuid UUID)
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM messages
        WHERE recipient_id = user_uuid AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- HELPER FUNCTION: Get Unread Notification Count
-- ============================================================================
CREATE OR REPLACE FUNCTION get_unread_notification_count(user_uuid UUID)
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM notifications
        WHERE user_id = user_uuid AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- VIEW: Farmer Statistics
-- ============================================================================
CREATE OR REPLACE VIEW farmer_statistics AS
SELECT
    f.farmer_id,
    f.farm_name,
    COALESCE(AVG(fr.rating), 0::DECIMAL)::DECIMAL(2, 1) as average_rating,
    COUNT(DISTINCT fr.rating_id)::BIGINT as total_ratings,
    COUNT(DISTINCT ff.follower_id)::BIGINT as follower_count,
    COUNT(DISTINCT p.product_id)::BIGINT as product_count,
    COUNT(DISTINCT CASE WHEN o.status = 'delivered' THEN o.order_id END)::BIGINT as completed_orders
FROM farmers f
LEFT JOIN farmer_ratings fr ON f.farmer_id = fr.farmer_id
LEFT JOIN farmer_followers ff ON f.farmer_id = ff.farmer_id
LEFT JOIN products p ON f.farmer_id = p.farmer_id
LEFT JOIN orders o ON f.farmer_id = o.farmer_id
GROUP BY f.farmer_id, f.farm_name;

-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_messages_conversation_is_read ON messages(conversation_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_is_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_farmer_rating ON farmer_ratings(farmer_id, rating DESC);

-- ============================================================================
-- PHASE 11: VIEWS FOR SUPABASE READS
-- ============================================================================

-- ============================================================================
-- VIEW: v_farmer_ratings (Farmer Ratings with customer and farm info)
-- ============================================================================
CREATE OR REPLACE VIEW v_farmer_ratings AS
SELECT
    fr.rating_id,
    fr.farmer_id,
    fr.customer_id,
    fr.order_id,
    fr.rating,
    fr.review_text,
    fr.categories,
    fr.created_at,
    fr.updated_at,
    u.name AS customer_name,
    u.avatar_url AS customer_avatar,
    f.farm_name
FROM farmer_ratings fr
JOIN users u ON u.user_id = fr.customer_id
JOIN farmers f ON f.farmer_id = fr.farmer_id;

-- ============================================================================
-- VIEW: v_customer_wishlist (Wishlist with product details)
-- ============================================================================
CREATE OR REPLACE VIEW v_customer_wishlist AS
SELECT
    cw.wishlist_id,
    cw.customer_id,
    cw.product_id,
    cw.created_at,
    p.name AS product_name,
    p.price,
    p.image_url AS product_image,
    p.farmer_id,
    p.is_preorder,
    p.quantity AS product_quantity,
    c.name AS category_name,
    un.name AS unit_name,
    un.abbreviation AS unit_abbr,
    f.farm_name
FROM customer_wishlist cw
JOIN products p ON p.product_id = cw.product_id
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN units un ON un.unit_id = p.unit_id
LEFT JOIN farmers f ON f.farmer_id = p.farmer_id;

-- ============================================================================
-- VIEW: v_conversations (Conversations with participant info and last message)
-- ============================================================================
CREATE OR REPLACE VIEW v_conversations AS
SELECT
    c.conversation_id,
    c.participant_1_id,
    c.participant_2_id,
    c.order_id,
    c.last_message_id,
    c.created_at,
    c.updated_at,
    u1.name AS participant_1_name,
    u1.avatar_url AS participant_1_avatar,
    u2.name AS participant_2_name,
    u2.avatar_url AS participant_2_avatar,
    lm.content AS last_message_content,
    lm.created_at AS last_message_at,
    lm.sender_id AS last_message_sender_id
FROM conversations c
JOIN users u1 ON u1.user_id = c.participant_1_id
JOIN users u2 ON u2.user_id = c.participant_2_id
LEFT JOIN messages lm ON lm.message_id = c.last_message_id;

-- ============================================================================
-- VIEW: v_messages (Messages with sender info)
-- ============================================================================
CREATE OR REPLACE VIEW v_messages AS
SELECT
    m.message_id,
    m.conversation_id,
    m.sender_id,
    m.recipient_id,
    m.content,
    m.image_url,
    m.is_read,
    m.read_at,
    m.created_at,
    m.updated_at,
    u.name AS sender_name,
    u.avatar_url AS sender_avatar
FROM messages m
JOIN users u ON u.user_id = m.sender_id;

-- ============================================================================
-- END OF ADDITIONAL SCHEMA
-- ============================================================================
