-- AgriDirect Core Database Schema
-- Last Updated: 2026-04-22

-- Core Tables
CREATE TABLE IF NOT EXISTS public.users (
  user_id uuid NOT NULL PRIMARY KEY DEFAULT auth.uid(),
  email text NOT NULL UNIQUE,
  name text NOT NULL DEFAULT ''::text,
  phone text,
  avatar_url text,
  bio text,
  email_verified boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admins (
  admin_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.users(user_id),
  role_level smallint NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customers (
  customer_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.users(user_id),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.farmers (
  farmer_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.users(user_id),
  farm_name text NOT NULL,
  full_name text,
  specialty text,
  location text,
  badge text,
  image_url text,
  is_verified boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  birth_date date,
  years_of_experience integer DEFAULT 0,
  face_photo_path text,
  valid_id_path text,
  valid_id_back_path text,
  residential_address text,
  farming_history text,
  farm_latitude double precision,
  farm_longitude double precision,
  id_type text,
  sex text,
  place_of_birth text,
  pcn text
);

-- Community Content
CREATE TABLE IF NOT EXISTS public.admin_articles (
  article_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  summary text,
  body text NOT NULL,
  cover_image_url text,
  is_published boolean DEFAULT false,
  published_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  admin_id uuid NOT NULL REFERENCES public.admins(admin_id)
);

CREATE TABLE IF NOT EXISTS public.forum_posts (
  post_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  title text NOT NULL,
  body text NOT NULL,
  image_url text,
  is_pinned boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.forum_comments (
  comment_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.forum_posts(post_id),
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  body text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.forum_post_likes (
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  post_id uuid NOT NULL REFERENCES public.forum_posts(post_id),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

-- Categories and Units
CREATE TABLE IF NOT EXISTS public.categories (
  category_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  icon text,
  image_url text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.units (
  unit_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  abbreviation text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Products and Inventory
CREATE TABLE IF NOT EXISTS public.products (
  product_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price numeric NOT NULL CHECK (price > 0),
  harvest_days integer,
  is_preorder boolean DEFAULT false,
  is_featured boolean DEFAULT false,
  is_active boolean DEFAULT true,
  farmer_id uuid NOT NULL REFERENCES public.farmers(farmer_id),
  category_id uuid NOT NULL REFERENCES public.categories(category_id),
  unit_id uuid NOT NULL REFERENCES public.units(unit_id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.product_images (
  image_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(product_id),
  image_url text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.product_inventory (
  inventory_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL UNIQUE REFERENCES public.products(product_id),
  available_quantity numeric,
  reserved_quantity numeric,
  low_stock_threshold numeric,
  updated_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Orders and Cart
CREATE TABLE IF NOT EXISTS public.cart_items (
  cart_item_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.customers(customer_id),
  product_id uuid NOT NULL REFERENCES public.products(product_id),
  quantity numeric NOT NULL CHECK (quantity > 0),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.order_statuses (
  order_status_id smallint NOT NULL PRIMARY KEY,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.delivery_addresses (
  address_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  label text NOT NULL,
  recipient_name text NOT NULL,
  recipient_phone text NOT NULL,
  street text NOT NULL,
  barangay text NOT NULL,
  city text NOT NULL,
  province text NOT NULL,
  zip_code text,
  is_default boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  latitude double precision,
  longitude double precision
);

CREATE TABLE IF NOT EXISTS public.orders (
  order_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number text NOT NULL UNIQUE,
  customer_id uuid NOT NULL REFERENCES public.customers(customer_id),
  farmer_id uuid NOT NULL REFERENCES public.farmers(farmer_id),
  delivery_address_id uuid REFERENCES public.delivery_addresses(address_id),
  order_status_id smallint NOT NULL REFERENCES public.order_statuses(order_status_id),
  subtotal numeric NOT NULL CHECK (subtotal >= 0),
  delivery_fee numeric CHECK (delivery_fee >= 0),
  total_amount numeric NOT NULL CHECK (total_amount >= 0),
  special_instructions text,
  delivery_method text NOT NULL DEFAULT 'delivery',
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.order_items (
  order_item_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(order_id),
  product_id uuid NOT NULL REFERENCES public.products(product_id),
  quantity numeric NOT NULL CHECK (quantity > 0),
  unit_price numeric NOT NULL CHECK (unit_price >= 0),
  subtotal numeric NOT NULL CHECK (subtotal >= 0),
  created_at timestamp with time zone DEFAULT now()
);

-- Notifications and Sessions
CREATE TABLE IF NOT EXISTS public.notification_types (
  notification_type_id smallint NOT NULL PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
  notification_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  notification_type_id smallint NOT NULL REFERENCES public.notification_types(notification_type_id),
  title text NOT NULL,
  body text NOT NULL,
  link_url text,
  link_type text,
  link_id uuid,
  is_read boolean DEFAULT false,
  read_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone DEFAULT (now() + '90 days'::interval)
);

CREATE TABLE IF NOT EXISTS public.user_device_tokens (
  token_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  fcm_token text NOT NULL UNIQUE,
  device_type text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_sessions (
  session_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone,
  duration_seconds integer,
  platform text,
  device_info text,
  app_version text,
  created_at timestamp with time zone DEFAULT now()
);

-- Reviews and Ratings
CREATE TABLE IF NOT EXISTS public.product_reviews (
  review_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(product_id),
  customer_id uuid NOT NULL REFERENCES public.customers(customer_id),
  order_id uuid REFERENCES public.orders(order_id),
  rating numeric NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  is_verified_purchase boolean NOT NULL DEFAULT false,
  helpful_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.farmer_ratings (
  rating_id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL REFERENCES public.farmers(farmer_id),
  customer_id uuid NOT NULL REFERENCES public.customers(customer_id),
  order_id uuid REFERENCES public.orders(order_id),
  rating numeric NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  response_text text,
  response_date timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Database Views
CREATE OR REPLACE VIEW public.v_forum_posts AS
SELECT 
    p.post_id,
    u.name as author_name,
    p.created_at,
    p.title,
    p.body,
    p.image_url,
    COALESCE(l.likes_count, 0)::int as likes_count,
    COALESCE(c.comments_count, 0)::int as comments_count
FROM forum_posts p
JOIN users u ON p.user_id = u.user_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as likes_count 
    FROM forum_post_likes GROUP BY post_id
) l ON p.post_id = l.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as comments_count 
    FROM forum_comments GROUP BY post_id
) c ON p.post_id = c.post_id;

CREATE OR REPLACE VIEW public.v_articles AS
SELECT 
    article_id,
    title,
    summary as excerpt,
    'AgriDirect' as author_name,
    CASE 
        WHEN length(body) < 1000 THEN '3 min read'
        WHEN length(body) < 2500 THEN '5 min read'
        ELSE '8 min read'
    END as read_time,
    cover_image_url as image_url,
    is_published as published,
    created_at
FROM admin_articles;

CREATE OR REPLACE VIEW public.v_farmer_profiles AS
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
  f.is_active,
  COALESCE(fr.status, 'pending'::text) AS registration_status,
  f.created_at,
  f.updated_at,
  f.birth_date,
  f.years_of_experience,
  f.face_photo_path,
  f.valid_id_path,
  u.name AS farmer_name,
  u.email AS farmer_email,
  u.phone AS farmer_phone,
  u.avatar_url,
  f.farm_latitude,
  f.farm_longitude
FROM farmers f
JOIN users u ON f.user_id = u.user_id
LEFT JOIN farmer_registrations fr ON f.farmer_id = fr.farmer_id;

CREATE OR REPLACE VIEW public.v_orders AS
SELECT
  o.order_id,
  o.order_number,
  o.customer_id,
  o.farmer_id,
  o.delivery_address_id,
  o.order_status_id,
  o.subtotal,
  o.delivery_fee,
  o.total_amount,
  o.payment_method,
  o.special_instructions,
  o.cancellation_reason,
  o.cancelled_by,
  o.created_at,
  o.updated_at,
  u.name as customer_name,
  u.avatar_url as customer_image,
  f.farm_name as farmer_name,
  os.code as status,
  os.code as status_code,
  os.description as status_description,
  o.payment_method::text as payment_method_name,
  (
    SELECT string_agg(p.name || ' (x' || oi.quantity || ')', ', ')
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE oi.order_id = o.order_id
  ) as items
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN users u ON c.user_id = u.user_id
LEFT JOIN farmers f ON o.farmer_id = f.farmer_id
LEFT JOIN order_statuses os ON o.order_status_id = os.order_status_id;
