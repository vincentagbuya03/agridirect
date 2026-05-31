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

CREATE TABLE IF NOT EXISTS public.forum_comment_likes (
  user_id uuid NOT NULL REFERENCES public.users(user_id),
  comment_id uuid NOT NULL REFERENCES public.forum_comments(comment_id),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, comment_id)
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

CREATE OR REPLACE FUNCTION public.create_offline_preorder(
  p_product_id uuid,
  p_quantity numeric,
  p_payment_method text,
  p_delivery_address_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_customer_id uuid;
  v_product record;
  v_inventory record;
  v_payment_method text := upper(trim(coalesce(p_payment_method, '')));
  v_pending_status_id smallint;
  v_order_id uuid;
  v_order_number text;
  v_subtotal numeric;
  v_conversation_id uuid;
  v_farmer_user_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be greater than zero';
  END IF;

  IF v_payment_method NOT IN ('COD', 'COP') THEN
    RAISE EXCEPTION 'Offline payment method must be COD or COP';
  END IF;

  SELECT c.customer_id
    INTO v_customer_id
  FROM public.customers c
  WHERE c.user_id = v_user_id
    AND c.is_active = true
  LIMIT 1;

  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Customer profile not found';
  END IF;

  IF p_delivery_address_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.delivery_addresses da
    WHERE da.address_id = p_delivery_address_id
      AND da.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Delivery address does not belong to the current user';
  END IF;

  SELECT p.product_id, p.farmer_id, p.price, p.name
    INTO v_product
  FROM public.products p
  WHERE p.product_id = p_product_id
    AND p.is_preorder = true
    AND p.is_active = true
  LIMIT 1;

  IF v_product.product_id IS NULL THEN
    RAISE EXCEPTION 'Selected pre-order product is not available';
  END IF;

  SELECT pi.inventory_id,
         coalesce(pi.available_quantity, 0) AS available_quantity,
         coalesce(pi.reserved_quantity, 0) AS reserved_quantity
    INTO v_inventory
  FROM public.product_inventory pi
  WHERE pi.product_id = p_product_id
  FOR UPDATE;

  IF v_inventory.inventory_id IS NULL THEN
    RAISE EXCEPTION 'Selected pre-order product does not have inventory configured';
  END IF;

  IF v_inventory.available_quantity < p_quantity THEN
    RAISE EXCEPTION 'Only % units are available for this pre-order', v_inventory.available_quantity;
  END IF;

  SELECT os.order_status_id
    INTO v_pending_status_id
  FROM public.order_statuses os
  WHERE os.code = 'pending'
  LIMIT 1;

  IF v_pending_status_id IS NULL THEN
    RAISE EXCEPTION 'Order status pending is not configured';
  END IF;

  v_subtotal := p_quantity * v_product.price;
  v_order_number := 'ORD-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text
    || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  INSERT INTO public.orders (
    order_number,
    customer_id,
    farmer_id,
    delivery_address_id,
    order_status_id,
    subtotal,
    delivery_fee,
    total_amount,
    payment_method,
    delivery_method,
    special_instructions
  )
  VALUES (
    v_order_number,
    v_customer_id,
    v_product.farmer_id,
    p_delivery_address_id,
    v_pending_status_id,
    v_subtotal,
    0,
    v_subtotal,
    v_payment_method::payment_method_enum,
    CASE WHEN v_payment_method = 'COP' THEN 'pickup' ELSE 'delivery' END,
    NULLIF(trim(coalesce(p_notes, '')), '')
  )
  RETURNING order_id INTO v_order_id;

  INSERT INTO public.order_items (
    order_id,
    product_id,
    quantity,
    unit_price,
    subtotal
  )
  VALUES (
    v_order_id,
    p_product_id,
    p_quantity,
    v_product.price,
    v_subtotal
  );

  UPDATE public.product_inventory
  SET available_quantity = v_inventory.available_quantity - p_quantity,
      reserved_quantity = v_inventory.reserved_quantity + p_quantity,
      updated_at = now()
  WHERE inventory_id = v_inventory.inventory_id;

  INSERT INTO public.conversations (customer_id, farmer_id, last_message_at)
  VALUES (v_customer_id, v_product.farmer_id, now())
  ON CONFLICT (customer_id, farmer_id)
  DO UPDATE SET last_message_at = greatest(public.conversations.last_message_at, excluded.last_message_at)
  RETURNING conversation_id INTO v_conversation_id;

  SELECT f.user_id
    INTO v_farmer_user_id
  FROM public.farmers f
  WHERE f.farmer_id = v_product.farmer_id;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'product_id', p_product_id,
    'product_name', v_product.name,
    'farmer_id', v_product.farmer_id,
    'farmer_user_id', v_farmer_user_id,
    'conversation_id', v_conversation_id,
    'payment_method', v_payment_method,
    'payment_status', 'offline_pending',
    'quantity', p_quantity,
    'total_amount', v_subtotal
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_offline_preorder(uuid, numeric, text, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.current_user_is_farmer()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.farmers f
    WHERE f.user_id = auth.uid()
      AND COALESCE(f.is_active, true)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_is_customer()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE c.user_id = auth.uid()
      AND COALESCE(c.is_active, true)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admins a
    WHERE a.user_id = auth.uid()
      AND COALESCE(a.is_active, true)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_engage_forum()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_user_is_farmer()
      OR public.current_user_is_customer()
      OR public.current_user_is_admin();
$$;

ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS forum_posts_select_authenticated ON public.forum_posts;
CREATE POLICY forum_posts_select_authenticated
ON public.forum_posts
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_posts_insert_farmer ON public.forum_posts;
CREATE POLICY forum_posts_insert_farmer
ON public.forum_posts
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_is_farmer());

DROP POLICY IF EXISTS forum_posts_update_owner_or_admin ON public.forum_posts;
CREATE POLICY forum_posts_update_owner_or_admin
ON public.forum_posts
FOR UPDATE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin())
WITH CHECK (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_posts_delete_owner_or_admin ON public.forum_posts;
CREATE POLICY forum_posts_delete_owner_or_admin
ON public.forum_posts
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_comments_select_authenticated ON public.forum_comments;
CREATE POLICY forum_comments_select_authenticated
ON public.forum_comments
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_comments_insert_farmer_or_customer ON public.forum_comments;
CREATE POLICY forum_comments_insert_farmer_or_customer
ON public.forum_comments
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_can_engage_forum());

DROP POLICY IF EXISTS forum_comments_update_owner_or_admin ON public.forum_comments;
CREATE POLICY forum_comments_update_owner_or_admin
ON public.forum_comments
FOR UPDATE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin())
WITH CHECK (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_comments_delete_owner_or_admin ON public.forum_comments;
CREATE POLICY forum_comments_delete_owner_or_admin
ON public.forum_comments
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_post_likes_select_authenticated ON public.forum_post_likes;
CREATE POLICY forum_post_likes_select_authenticated
ON public.forum_post_likes
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_post_likes_insert_farmer_or_customer ON public.forum_post_likes;
CREATE POLICY forum_post_likes_insert_farmer_or_customer
ON public.forum_post_likes
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_can_engage_forum());

DROP POLICY IF EXISTS forum_post_likes_delete_own ON public.forum_post_likes;
CREATE POLICY forum_post_likes_delete_own
ON public.forum_post_likes
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

DROP POLICY IF EXISTS forum_comment_likes_select_authenticated ON public.forum_comment_likes;
CREATE POLICY forum_comment_likes_select_authenticated
ON public.forum_comment_likes
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS forum_comment_likes_insert_farmer_or_customer ON public.forum_comment_likes;
CREATE POLICY forum_comment_likes_insert_farmer_or_customer
ON public.forum_comment_likes
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.current_user_can_engage_forum());

DROP POLICY IF EXISTS forum_comment_likes_delete_own ON public.forum_comment_likes;
CREATE POLICY forum_comment_likes_delete_own
ON public.forum_comment_likes
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.current_user_is_admin());

GRANT EXECUTE ON FUNCTION public.current_user_is_farmer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_customer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_engage_forum() TO authenticated;
