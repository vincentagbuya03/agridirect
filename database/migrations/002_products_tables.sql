-- ============================================================================
-- 002_products_tables.sql
-- Product catalog management tables
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
    farmer_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
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
CREATE TRIGGER product_reviews_updated_at_trigger
BEFORE UPDATE ON product_reviews
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
