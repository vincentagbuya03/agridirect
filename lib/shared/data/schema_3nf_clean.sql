-- ========================================================================
-- AgrIDirect Database Schema - Third Normal Form (3NF)
-- ========================================================================
-- This is the CLEAN schema for fresh Supabase setup.
-- If migrating from existing tables, see MIGRATION_TO_3NF.md
-- ========================================================================

-- ========================================================================
-- 1. ENUM Types
-- ========================================================================

CREATE TYPE order_status AS ENUM (
  'PENDING',
  'CONFIRMED', 
  'SHIPPED',
  'DELIVERED',
  'CANCELLED'
);

-- ========================================================================
-- 2. Core User System
-- ========================================================================

CREATE TABLE users (
  user_id uuid PRIMARY KEY DEFAULT auth.uid(),
  email text UNIQUE NOT NULL,
  name text NOT NULL,
  phone text,
  avatar_url text,
  bio text,
  email_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Role definitions (consumer, seller, admin)
CREATE TABLE roles (
  role_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

INSERT INTO roles (name) VALUES ('consumer'), ('seller'), ('admin');

-- User-Role mapping (many-to-many)
CREATE TABLE user_roles (
  user_id uuid REFERENCES users(user_id) ON DELETE CASCADE,
  role_id uuid REFERENCES roles(role_id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);

-- Decomposed address (atomic fields)
CREATE TABLE user_addresses (
  address_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
  street text,
  barangay text,
  city text,
  province text,
  zip_code text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_user_addresses_user_id ON user_addresses(user_id);

-- ========================================================================
-- 3. Reference Tables (Lookups)
-- ========================================================================

CREATE TABLE categories (
  category_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  icon text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_categories_name ON categories(name);

CREATE TABLE units (
  unit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  abbreviation text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_units_name ON units(name);

-- ========================================================================
-- 4. Product Management
-- ========================================================================

CREATE TABLE products (
  product_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  price decimal(12, 2) NOT NULL,
  image_url text,
  harvest_days integer,
  is_preorder boolean DEFAULT false,
  farmer_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
  unit_id uuid NOT NULL REFERENCES units(unit_id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_products_farmer_id ON products(farmer_id);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_unit_id ON products(unit_id);
CREATE INDEX idx_products_is_preorder ON products(is_preorder);
CREATE INDEX idx_products_created_at ON products(created_at);

CREATE TABLE product_reviews (
  review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  rating decimal(3, 2) NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(product_id, user_id)
);

CREATE INDEX idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX idx_product_reviews_user_id ON product_reviews(user_id);
CREATE INDEX idx_product_reviews_created_at ON product_reviews(created_at);

CREATE TABLE product_tags (
  tag_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_product_tags_name ON product_tags(name);

CREATE TABLE product_tag_mappings (
  product_id uuid REFERENCES products(product_id) ON DELETE CASCADE,
  tag_id uuid REFERENCES product_tags(tag_id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, tag_id)
);

CREATE INDEX idx_product_tag_mappings_tag_id ON product_tag_mappings(tag_id);

-- ========================================================================
-- 5. Farmer System
-- ========================================================================

CREATE TABLE farmer_profiles (
  profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  farm_name text NOT NULL,
  specialty text,
  location text,
  badge text,
  image_url text,
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_farmer_profiles_user_id ON farmer_profiles(user_id);
CREATE INDEX idx_farmer_profiles_is_verified ON farmer_profiles(is_verified);

CREATE TABLE farmer_specializations (
  specialization_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  specialization text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_farmer_specializations_farmer_id ON farmer_specializations(farmer_id);

-- Farmer registration and verification
CREATE TABLE farmer_registrations (
  registration_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  birth_date text,
  years_of_experience integer,
  residential_address text,
  face_photo_path text,
  valid_id_path text,
  farming_history text,
  certification_accepted boolean DEFAULT false,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_farmer_registrations_user_id ON farmer_registrations(user_id);
CREATE INDEX idx_farmer_registrations_status ON farmer_registrations(status);

-- Decomposed education (one row per education level)
CREATE TABLE farmer_education (
  education_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
  level text NOT NULL,
  school_name text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_farmer_education_registration_id ON farmer_education(registration_id);

-- Decomposed crop types (one row per crop)
CREATE TABLE farmer_crop_types (
  crop_type_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
  crop_type text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_farmer_crop_types_registration_id ON farmer_crop_types(registration_id);

-- Decomposed livestock (one row per livestock type)
CREATE TABLE farmer_livestock (
  livestock_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
  livestock_type text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_farmer_livestock_registration_id ON farmer_livestock(registration_id);

-- ========================================================================
-- 6. Shopping & Orders
-- ========================================================================

CREATE TABLE orders (
  order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number text UNIQUE NOT NULL,
  customer_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  farmer_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  status order_status DEFAULT 'PENDING',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_farmer_id ON orders(farmer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_orders_order_number ON orders(order_number);

CREATE TABLE order_items (
  order_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
  quantity decimal(10, 2) NOT NULL CHECK (quantity > 0),
  unit_price decimal(12, 2) NOT NULL CHECK (unit_price >= 0),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- ========================================================================
-- 7. Community & Forum
-- ========================================================================

CREATE TABLE forum_posts (
  post_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_forum_posts_user_id ON forum_posts(user_id);
CREATE INDEX idx_forum_posts_created_at ON forum_posts(created_at);

CREATE TABLE forum_comments (
  comment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_forum_comments_post_id ON forum_comments(post_id);
CREATE INDEX idx_forum_comments_user_id ON forum_comments(user_id);

CREATE TABLE post_likes (
  like_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX idx_post_likes_user_id ON post_likes(user_id);

-- ========================================================================
-- 8. Content Management
-- ========================================================================

CREATE TABLE articles (
  article_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL,
  author_id uuid REFERENCES users(user_id) ON DELETE SET NULL,
  read_time text,
  image_url text,
  published boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_articles_author_id ON articles(author_id);
CREATE INDEX idx_articles_published ON articles(published);
CREATE INDEX idx_articles_created_at ON articles(created_at);

-- ========================================================================
-- 9. Admin & Moderation
-- ========================================================================

CREATE TABLE admin_logs (
  log_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  action text NOT NULL,
  details text,
  target_user_id uuid REFERENCES users(user_id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_admin_logs_admin_id ON admin_logs(admin_id);
CREATE INDEX idx_admin_logs_target_user_id ON admin_logs(target_user_id);
CREATE INDEX idx_admin_logs_created_at ON admin_logs(created_at);

CREATE TABLE reported_content (
  report_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  content_type text NOT NULL,
  content_id uuid NOT NULL,
  reason text NOT NULL,
  description text,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  resolved_by uuid REFERENCES users(user_id) ON DELETE SET NULL,
  resolution_notes text,
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX idx_reported_content_reporter_id ON reported_content(reporter_id);
CREATE INDEX idx_reported_content_status ON reported_content(status);
CREATE INDEX idx_reported_content_created_at ON reported_content(created_at);

CREATE TABLE user_suspensions (
  suspension_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  reason text NOT NULL,
  suspended_by uuid NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  suspended_at timestamptz DEFAULT now(),
  expires_at timestamptz,
  is_permanent boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_user_suspensions_user_id ON user_suspensions(user_id);
CREATE INDEX idx_user_suspensions_suspended_by ON user_suspensions(suspended_by);

-- ========================================================================
-- COMPUTED VIEWs (Do NOT write to these - READ ONLY)
-- ========================================================================

-- Products with aggregated ratings and counts
CREATE OR REPLACE VIEW v_products AS
SELECT
  p.*,
  c.name AS category_name,
  u.name AS unit_name,
  u.abbreviation AS unit_abbr,
  fp.farm_name,
  COALESCE(AVG(pr.rating), 0.0) AS average_rating,
  COUNT(pr.review_id)::integer AS review_count
FROM products p
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN units u ON u.unit_id = p.unit_id
LEFT JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY p.product_id, c.name, u.name, u.abbreviation, fp.farm_name;

-- Forum posts with like and comment counts
CREATE OR REPLACE VIEW v_forum_posts AS
SELECT
  fp.*,
  usr.name AS author_name,
  COALESCE(lk.likes_count, 0)::integer AS likes_count,
  COALESCE(cm.comments_count, 0)::integer AS comments_count
FROM forum_posts fp
JOIN users usr ON usr.user_id = fp.user_id
LEFT JOIN (
  SELECT post_id, COUNT(*) AS likes_count 
  FROM post_likes 
  GROUP BY post_id
) lk ON lk.post_id = fp.post_id
LEFT JOIN (
  SELECT post_id, COUNT(*) AS comments_count 
  FROM forum_comments 
  GROUP BY post_id
) cm ON cm.post_id = fp.post_id;

-- Orders with computed total and item count
CREATE OR REPLACE VIEW v_orders AS
SELECT
  o.*,
  COALESCE(SUM(oi.quantity * oi.unit_price), 0.0) AS total,
  COUNT(oi.order_item_id)::integer AS item_count
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

-- Order items with computed subtotal
CREATE OR REPLACE VIEW v_order_items AS
SELECT
  oi.*,
  (oi.quantity * oi.unit_price) AS subtotal
FROM order_items oi;

-- Farmer profiles with ratings
CREATE OR REPLACE VIEW v_farmer_profiles AS
SELECT
  fp.*,
  usr.name AS farmer_name,
  COALESCE(AVG(pr.rating), 0.0) AS average_rating,
  COUNT(DISTINCT pr.review_id)::integer AS total_reviews
FROM farmer_profiles fp
JOIN users usr ON usr.user_id = fp.user_id
LEFT JOIN products p ON p.farmer_id = fp.user_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY fp.profile_id, usr.name;

-- Articles with computed excerpt
CREATE OR REPLACE VIEW v_articles AS
SELECT
  a.*,
  usr.name AS author_name,
  LEFT(a.content, 200) AS excerpt
FROM articles a
LEFT JOIN users usr ON usr.user_id = a.author_id;

-- User info with roles
CREATE OR REPLACE VIEW v_users_with_roles AS
SELECT
  u.*,
  STRING_AGG(r.name, ', ') AS roles
FROM users u
LEFT JOIN user_roles ur ON ur.user_id = u.user_id
LEFT JOIN roles r ON r.role_id = ur.role_id
GROUP BY u.user_id;

-- ========================================================================
-- 10. INSERT INITIAL DATA (Optional)
-- ========================================================================

-- Pre-populate common categories
INSERT INTO categories (name, description, icon) VALUES
  ('Vegetables', 'Fresh vegetables', '🥬'),
  ('Fruits', 'Fresh fruits', '🍎'),
  ('Dairy', 'Milk and dairy products', '🥛'),
  ('Grains', 'Cereals and grains', '🌾'),
  ('Herbs', 'Fresh herbs and spices', '🌿'),
  ('Eggs', 'Fresh eggs', '🥚'),
  ('Poultry', 'Meat and chicken', '🍗'),
  ('Fish', 'Fresh seafood', '🎣')
ON CONFLICT (name) DO NOTHING;

-- Pre-populate common units
INSERT INTO units (name, abbreviation) VALUES
  ('Kilogram', 'kg'),
  ('Gram', 'g'),
  ('Pound', 'lb'),
  ('Piece', 'pc'),
  ('Bunch', 'bun'),
  ('Tray', 'tray'),
  ('Box', 'box'),
  ('Jar', 'jar'),
  ('Crate', 'crate'),
  ('Head', 'hd'),
  ('Bundle', 'bdl')
ON CONFLICT (name) DO NOTHING;

-- ========================================================================
-- 11. AUTO-CREATE USER PROFILE ON AUTH SIGNUP (Trigger)
-- ========================================================================

-- This trigger fires when a new user signs up via Supabase Auth.
-- It automatically inserts a row in public.users and assigns the 'consumer' role.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  consumer_role_id uuid;
BEGIN
  -- Insert user profile from auth metadata
  INSERT INTO public.users (user_id, email, name, phone)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    NEW.raw_user_meta_data->>'phone_number'
  )
  ON CONFLICT (user_id) DO NOTHING;

  -- Assign default 'consumer' role
  SELECT role_id INTO consumer_role_id FROM public.roles WHERE name = 'consumer';
  IF consumer_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id)
    VALUES (NEW.id, consumer_role_id)
    ON CONFLICT (user_id, role_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: run handle_new_user after every auth.users insert
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ========================================================================
-- 12. Row Level Security (RLS) Policies
-- ========================================================================

-- Enable RLS on users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can read own profile" ON users
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = user_id);

-- Enable RLS on user_roles table
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- Users can read their own roles
CREATE POLICY "Users can read own roles" ON user_roles
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own roles
CREATE POLICY "Users can insert own roles" ON user_roles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ========================================================================
-- END OF SCHEMA
-- ========================================================================
