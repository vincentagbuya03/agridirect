-- ========================================================================
-- AGRIDIRECT - COMPLETE DATABASE SCHEMA (Current Production)
-- Full-featured agricultural marketplace system
-- Last Updated: 2026-03-21
-- ========================================================================

-- ========================================================================
-- STEP 1: CORE TABLES
-- ========================================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
  user_id uuid PRIMARY KEY DEFAULT auth.uid(),
  email text UNIQUE NOT NULL,
  name text NOT NULL DEFAULT '',
  phone text,
  avatar_url text,
  bio text,
  email_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Roles table (for RBAC)
CREATE TABLE IF NOT EXISTS roles (
  role_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- User roles mapping table
CREATE TABLE IF NOT EXISTS user_roles (
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);

-- Customer role
CREATE TABLE IF NOT EXISTS customers (
  customer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  total_orders integer DEFAULT 0,
  total_spent numeric(12, 2) DEFAULT 0.00,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customers_user_id ON customers(user_id);

-- Farmer role
CREATE TABLE IF NOT EXISTS farmers (
  farmer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  farm_name text NOT NULL,
  specialty text,
  location text,
  badge text,
  image_url text,
  is_verified boolean DEFAULT false,
  is_active boolean DEFAULT true,
  total_sales numeric(12, 2) DEFAULT 0.00,
  total_products integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_farmers_user_id ON farmers(user_id);
CREATE INDEX IF NOT EXISTS idx_farmers_is_verified ON farmers(is_verified);
CREATE INDEX IF NOT EXISTS idx_farmers_location ON farmers(location);

-- Admin role
CREATE TABLE IF NOT EXISTS admins (
  admin_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  role_level smallint DEFAULT 1 CHECK (role_level IN (1, 2, 3)),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admins_user_id ON admins(user_id);

-- Delivery addresses
CREATE TABLE IF NOT EXISTS delivery_addresses (
  address_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  label text NOT NULL,
  recipient_name text NOT NULL,
  recipient_phone text NOT NULL,
  street text NOT NULL,
  barangay text NOT NULL,
  city text NOT NULL,
  province text NOT NULL,
  zip_code text,
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_addresses_user_id ON delivery_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_delivery_addresses_is_default ON delivery_addresses(is_default);

-- ========================================================================
-- REFERENCE TABLES
-- ========================================================================

CREATE TABLE IF NOT EXISTS categories (
  category_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  icon text,
  image_url text,
  parent_category_id uuid REFERENCES categories(category_id) ON DELETE SET NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_category_id);

CREATE TABLE IF NOT EXISTS units (
  unit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  abbreviation text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_units_name ON units(name);

-- ========================================================================
-- FARMER SYSTEM
-- ========================================================================

CREATE TABLE IF NOT EXISTS farmer_certifications (
  certification_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  certification_name text NOT NULL,
  certification_number text,
  issuing_authority text,
  issue_date date,
  expiry_date date,
  document_url text,
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_farmer_certifications_farmer_id ON farmer_certifications(farmer_id);

CREATE TABLE IF NOT EXISTS farmer_ratings (
  rating_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  order_id uuid NOT NULL,
  rating numeric(3, 2) NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  response_text text,
  response_date timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(order_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_farmer_ratings_farmer_id ON farmer_ratings(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_customer_id ON farmer_ratings(customer_id);

CREATE TABLE IF NOT EXISTS farmer_registrations (
  registration_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid UNIQUE NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  birth_date text,
  years_of_experience integer,
  residential_address text,
  face_photo_path text,
  valid_id_path text,
  farming_history text,
  certification_accepted boolean DEFAULT false,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by uuid REFERENCES admins(admin_id),
  review_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_farmer_registrations_farmer_id ON farmer_registrations(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_registrations_status ON farmer_registrations(status);

CREATE TABLE IF NOT EXISTS farmer_education (
  education_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
  level text NOT NULL,
  school_name text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_farmer_education_registration_id ON farmer_education(registration_id);

CREATE TABLE IF NOT EXISTS farmer_crop_types (
  crop_type_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
  crop_type text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_farmer_crop_types_registration_id ON farmer_crop_types(registration_id);

CREATE TABLE IF NOT EXISTS farmer_livestock (
  livestock_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid NOT NULL REFERENCES farmer_registrations(registration_id) ON DELETE CASCADE,
  livestock_type text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_farmer_livestock_registration_id ON farmer_livestock(registration_id);

-- ========================================================================
-- PRODUCT SYSTEM
-- ========================================================================

CREATE TABLE IF NOT EXISTS products (
  product_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price numeric(12, 2) NOT NULL,
  harvest_days integer,
  is_preorder boolean DEFAULT false,
  is_featured boolean DEFAULT false,
  is_active boolean DEFAULT true,
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
  unit_id uuid NOT NULL REFERENCES units(unit_id) ON DELETE RESTRICT,
  total_sold numeric(10, 2) DEFAULT 0,
  view_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_products_farmer_id ON products(farmer_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);

CREATE TABLE IF NOT EXISTS product_images (
  image_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  image_url text NOT NULL,
  is_primary boolean DEFAULT false,
  display_order integer,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON product_images(product_id);

CREATE TABLE IF NOT EXISTS product_inventory (
  inventory_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid UNIQUE NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  available_quantity numeric,
  reserved_quantity numeric,
  low_stock_threshold numeric,
  updated_at timestamptz
);

CREATE TABLE IF NOT EXISTS product_reviews (
  review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  order_id uuid,
  rating numeric NOT NULL,
  review_text text,
  images text[],
  is_verified_purchase boolean DEFAULT false,
  helpful_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_customer_id ON product_reviews(customer_id);

-- ========================================================================
-- CART & ORDERS
-- ========================================================================

CREATE TABLE IF NOT EXISTS cart_items (
  cart_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  quantity numeric NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cart_items_customer_id ON cart_items(customer_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON cart_items(product_id);

CREATE TABLE IF NOT EXISTS orders (
  order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number text UNIQUE NOT NULL,
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  delivery_address_id uuid REFERENCES delivery_addresses(address_id) ON DELETE SET NULL,
  status text DEFAULT 'pending',
  subtotal numeric NOT NULL,
  delivery_fee numeric,
  total_amount numeric NOT NULL,
  payment_method text,
  special_instructions text,
  cancellation_reason text,
  cancelled_by uuid REFERENCES users(user_id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_farmer_id ON orders(farmer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

CREATE TABLE IF NOT EXISTS order_items (
  order_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  product_name text NOT NULL,
  quantity numeric NOT NULL,
  unit_price numeric NOT NULL,
  subtotal numeric NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

CREATE TABLE IF NOT EXISTS order_status_history (
  history_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  old_status text,
  new_status text NOT NULL,
  notes text,
  changed_by uuid REFERENCES users(user_id),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);

CREATE TABLE IF NOT EXISTS payments (
  payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  payment_method text NOT NULL,
  status text DEFAULT 'pending',
  transaction_reference text,
  proof_of_payment_url text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id);

-- ========================================================================
-- MESSAGING & NOTIFICATIONS
-- ========================================================================

CREATE TABLE IF NOT EXISTS conversations (
  conversation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  farmer_id uuid NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
  last_message_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversations_customer_id ON conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_conversations_farmer_id ON conversations(farmer_id);

CREATE TABLE IF NOT EXISTS messages (
  message_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  message_text text NOT NULL,
  image_url text,
  is_read boolean DEFAULT false,
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);

CREATE TABLE IF NOT EXISTS notifications (
  notification_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  link_url text,
  is_read boolean DEFAULT false,
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- ========================================================================
-- FORUM SYSTEM
-- ========================================================================

CREATE TABLE IF NOT EXISTS forum_posts (
  post_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  image_url text,
  is_pinned boolean DEFAULT false,
  view_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_forum_posts_user_id ON forum_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_is_pinned ON forum_posts(is_pinned);

CREATE TABLE IF NOT EXISTS forum_comments (
  comment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_forum_comments_post_id ON forum_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_comments_user_id ON forum_comments(user_id);

CREATE TABLE IF NOT EXISTS post_likes (
  like_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);

-- ========================================================================
-- ACTIVITY TRACKING
-- ========================================================================

CREATE TABLE IF NOT EXISTS app_sessions (
  session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  duration_seconds integer,
  platform text,
  device_info text,
  app_version text,
  clicks_count integer DEFAULT 0,
  keystrokes_count integer DEFAULT 0,
  screens_visited text[],
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_user_id ON app_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_app_sessions_start_time ON app_sessions(start_time);

CREATE TABLE IF NOT EXISTS user_activity_logs (
  activity_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  date date NOT NULL,
  total_clicks integer,
  button_clicks integer,
  link_clicks integer,
  total_keystrokes integer,
  form_submissions integer,
  total_sessions integer,
  total_time_seconds integer,
  screens_visited text[],
  most_visited_screen text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_activity_logs_user_id ON user_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_logs_date ON user_activity_logs(date);

CREATE TABLE IF NOT EXISTS user_interaction_events (
  event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES app_sessions(session_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  event_type text NOT NULL,
  screen_name text NOT NULL,
  element_id text,
  element_type text,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_interaction_events_session_id ON user_interaction_events(session_id);
CREATE INDEX IF NOT EXISTS idx_user_interaction_events_user_id ON user_interaction_events(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interaction_events_event_type ON user_interaction_events(event_type);

-- ========================================================================
-- ADMIN LOGS
-- ========================================================================

CREATE TABLE IF NOT EXISTS admin_logs (
  log_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES admins(admin_id) ON DELETE CASCADE,
  action text NOT NULL,
  details text,
  target_user_id uuid REFERENCES users(user_id) ON DELETE SET NULL,
  ip_address text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON admin_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON admin_logs(created_at);

-- ========================================================================
-- WISHLIST
-- ========================================================================

CREATE TABLE IF NOT EXISTS wishlist_items (
  wishlist_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(customer_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_wishlist_items_customer_id ON wishlist_items(customer_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_items_product_id ON wishlist_items(product_id);
