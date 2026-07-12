-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.users (
  email text NOT NULL UNIQUE,
  phone text,
  avatar_url text,
  bio text,
  user_id uuid NOT NULL DEFAULT auth.uid(),
  name text NOT NULL DEFAULT ''::text,
  email_verified boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (user_id)
);
CREATE TABLE public.roles (
  name text NOT NULL UNIQUE,
  role_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT roles_pkey PRIMARY KEY (role_id)
);
CREATE TABLE public.user_roles (
  user_id uuid NOT NULL,
  role_id uuid NOT NULL,
  CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES public.roles(role_id)
);
CREATE TABLE public.farmers (
  farm_latitude double precision CHECK (farm_latitude IS NULL OR farm_latitude >= '-90'::integer::double precision AND farm_latitude <= 90::double precision),
  farm_longitude double precision CHECK (farm_longitude IS NULL OR farm_longitude >= '-180'::integer::double precision AND farm_longitude <= 180::double precision),
  user_id uuid NOT NULL UNIQUE,
  farm_name text NOT NULL,
  specialty text,
  location text,
  badge text,
  image_url text,
  farmer_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  is_verified boolean DEFAULT false,
  is_active boolean DEFAULT true,
  free_delivery_min_amount numeric DEFAULT 0 CHECK (free_delivery_min_amount >= 0::numeric),
  id_type text,
  sex text,
  place_of_birth text,
  pcn text,
  valid_id_back_path text,
  residential_address text,
  farming_history text,
  birth_date date,
  years_of_experience integer DEFAULT 0,
  face_photo_path text,
  valid_id_path text,
  full_name text,
  CONSTRAINT farmers_pkey PRIMARY KEY (farmer_id),
  CONSTRAINT fk_farmers_user FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.delivery_addresses (
  user_id uuid NOT NULL,
  label text NOT NULL,
  recipient_name text NOT NULL,
  recipient_phone text NOT NULL,
  street text NOT NULL,
  barangay text NOT NULL,
  city text NOT NULL,
  province text NOT NULL,
  zip_code text,
  address_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  latitude double precision CHECK (latitude IS NULL OR latitude >= '-90'::integer::double precision AND latitude <= 90::double precision),
  longitude double precision CHECK (longitude IS NULL OR longitude >= '-180'::integer::double precision AND longitude <= 180::double precision),
  is_default boolean DEFAULT false,
  CONSTRAINT delivery_addresses_pkey PRIMARY KEY (address_id),
  CONSTRAINT fk_delivery_addresses_user FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.categories (
  name text NOT NULL UNIQUE,
  description text,
  category_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categories_pkey PRIMARY KEY (category_id)
);
CREATE TABLE public.units (
  name text NOT NULL UNIQUE,
  abbreviation text NOT NULL UNIQUE,
  unit_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT units_pkey PRIMARY KEY (unit_id)
);
CREATE TABLE public.products (
  name text NOT NULL,
  description text,
  price numeric NOT NULL CHECK (price > 0::numeric),
  harvest_days integer,
  farmer_id uuid NOT NULL,
  category_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  product_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_preorder boolean DEFAULT false,
  is_featured boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT products_pkey PRIMARY KEY (product_id),
  CONSTRAINT fk_products_unit FOREIGN KEY (unit_id) REFERENCES public.units(unit_id),
  CONSTRAINT fk_products_farmer FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES public.categories(category_id)
);
CREATE TABLE public.cart_items (
  customer_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  cart_item_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT cart_items_pkey PRIMARY KEY (cart_item_id),
  CONSTRAINT fk_cart_items_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT fk_cart_product FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.orders (
  customer_id uuid NOT NULL,
  order_number text NOT NULL UNIQUE,
  farmer_id uuid NOT NULL,
  delivery_address_id uuid,
  order_status_id smallint NOT NULL,
  subtotal numeric NOT NULL CHECK (subtotal >= 0::numeric),
  delivery_fee numeric CHECK (delivery_fee IS NULL OR delivery_fee >= 0::numeric),
  total_amount numeric NOT NULL CHECK (total_amount >= 0::numeric),
  special_instructions text,
  cancellation_reason text,
  cancelled_by uuid,
  order_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  payment_method USER-DEFINED NOT NULL DEFAULT 'COD'::payment_method_enum,
  delivery_method text NOT NULL DEFAULT 'delivery'::text CHECK (delivery_method = ANY (ARRAY['delivery'::text, 'pickup'::text])),
  cancelled_by_role text CHECK (cancelled_by_role IS NULL OR (cancelled_by_role = ANY (ARRAY['customer'::text, 'farmer'::text, 'admin'::text, 'system'::text]))),
  CONSTRAINT orders_pkey PRIMARY KEY (order_id),
  CONSTRAINT fk_orders_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT fk_orders_farmer FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id),
  CONSTRAINT fk_orders_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES public.users(user_id),
  CONSTRAINT fk_orders_delivery_address FOREIGN KEY (delivery_address_id) REFERENCES public.delivery_addresses(address_id),
  CONSTRAINT fk_orders_order_status_id FOREIGN KEY (order_status_id) REFERENCES public.order_statuses(order_status_id)
);
CREATE TABLE public.order_items (
  order_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  unit_price numeric NOT NULL CHECK (unit_price >= 0::numeric),
  subtotal numeric NOT NULL CHECK (subtotal >= 0::numeric),
  order_item_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES public.orders(order_id),
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.payments (
  customer_id uuid NOT NULL,
  order_id uuid NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  notes text,
  payment_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  payment_status USER-DEFINED NOT NULL DEFAULT 'offline_pending'::payment_status_enum,
  payment_method USER-DEFINED NOT NULL DEFAULT 'COD'::payment_method_enum,
  CONSTRAINT payments_pkey PRIMARY KEY (payment_id),
  CONSTRAINT fk_payments_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES public.orders(order_id)
);
CREATE TABLE public.conversations (
  customer_id uuid NOT NULL,
  farmer_id uuid NOT NULL,
  last_message_at timestamp with time zone,
  conversation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT conversations_pkey PRIMARY KEY (conversation_id),
  CONSTRAINT fk_conversations_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT fk_conversations_farmer FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id)
);
CREATE TABLE public.messages (
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  message_text text NOT NULL,
  image_url text,
  read_at timestamp with time zone,
  message_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  is_read boolean DEFAULT false,
  CONSTRAINT messages_pkey PRIMARY KEY (message_id),
  CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES public.users(user_id),
  CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id) REFERENCES public.conversations(conversation_id)
);
CREATE TABLE public.notifications (
  user_id uuid NOT NULL,
  notification_type_id smallint NOT NULL,
  title text NOT NULL,
  link_url text,
  read_at timestamp with time zone,
  notification_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  link_type text,
  link_id uuid,
  body text NOT NULL,
  expires_at timestamp with time zone DEFAULT (now() + '90 days'::interval),
  archived_at timestamp with time zone,
  CONSTRAINT notifications_pkey PRIMARY KEY (notification_id),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT fk_notifications_type_id FOREIGN KEY (notification_type_id) REFERENCES public.notification_types(notification_type_id)
);
CREATE TABLE public.forum_posts (
  video_url text,
  user_id uuid NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  image_url text,
  post_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_pinned boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT forum_posts_pkey PRIMARY KEY (post_id),
  CONSTRAINT fk_forum_posts_user FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.forum_comments (
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  body text NOT NULL,
  comment_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT forum_comments_pkey PRIMARY KEY (comment_id),
  CONSTRAINT fk_forum_comments_user FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT fk_forum_comments_post FOREIGN KEY (post_id) REFERENCES public.forum_posts(post_id)
);
CREATE TABLE public.app_sessions (
  user_id uuid NOT NULL,
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone,
  duration_seconds integer,
  platform text,
  device_info text,
  app_version text,
  session_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT app_sessions_pkey PRIMARY KEY (session_id),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.admin_logs (
  admin_id uuid NOT NULL,
  action text NOT NULL,
  details text,
  target_user_id uuid,
  ip_address text,
  log_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT admin_logs_pkey PRIMARY KEY (log_id),
  CONSTRAINT fk_admin_logs_admin_id FOREIGN KEY (admin_id) REFERENCES public.admins(admin_id),
  CONSTRAINT fk_admin_logs_target FOREIGN KEY (target_user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.admin_articles (
  admin_id uuid NOT NULL,
  title text NOT NULL,
  summary text,
  body text NOT NULL,
  cover_image_url text,
  published_at timestamp with time zone,
  article_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_published boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  audience text DEFAULT 'ALL'::text,
  read_time text DEFAULT '3 min read'::text,
  CONSTRAINT admin_articles_pkey PRIMARY KEY (article_id),
  CONSTRAINT fk_admin_articles_admin_id FOREIGN KEY (admin_id) REFERENCES public.admins(admin_id)
);
CREATE TABLE public.verification_codes (
  created_at timestamp with time zone DEFAULT now(),
  user_id uuid NOT NULL,
  verification_code text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  used_at timestamp with time zone,
  code_id uuid NOT NULL DEFAULT gen_random_uuid(),
  verification_type text NOT NULL CHECK (verification_type = ANY (ARRAY['email'::text, 'phone'::text, 'password_reset'::text, 'two_factor'::text])),
  CONSTRAINT verification_codes_pkey PRIMARY KEY (code_id),
  CONSTRAINT fk_verification_user FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.reported_content (
  content_id text NOT NULL,
  reason text NOT NULL,
  description text,
  resolution_notes text,
  report_id uuid NOT NULL DEFAULT gen_random_uuid(),
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'reviewing'::text, 'resolved'::text, 'dismissed'::text])),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  content_type_id smallint NOT NULL CHECK (content_type_id IS NOT NULL),
  resolved_by uuid,
  resolved_at timestamp with time zone,
  reporter_id uuid NOT NULL,
  CONSTRAINT reported_content_pkey PRIMARY KEY (report_id),
  CONSTRAINT fk_reported_content_reporter_id FOREIGN KEY (reporter_id) REFERENCES public.users(user_id),
  CONSTRAINT fk_reported_content_resolved_by FOREIGN KEY (resolved_by) REFERENCES public.users(user_id),
  CONSTRAINT fk_reported_content_content_type_id FOREIGN KEY (content_type_id) REFERENCES public.content_types(content_type_id)
);
CREATE TABLE public.user_device_tokens (
  user_id uuid NOT NULL,
  fcm_token text NOT NULL UNIQUE,
  device_type text NOT NULL CHECK (device_type = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text])),
  token_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_device_tokens_pkey PRIMARY KEY (token_id),
  CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.farmer_education (
  farmer_id uuid NOT NULL,
  degree text,
  institution text,
  year_graduated integer,
  education_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT farmer_education_pkey PRIMARY KEY (education_id),
  CONSTRAINT farmer_education_normalized_farmer_id_fkey FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id)
);
CREATE TABLE public.customers (
  user_id uuid NOT NULL UNIQUE,
  customer_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT customers_pkey PRIMARY KEY (customer_id),
  CONSTRAINT customers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.admins (
  user_id uuid NOT NULL UNIQUE,
  admin_id uuid NOT NULL DEFAULT gen_random_uuid(),
  role_level smallint NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT admins_pkey PRIMARY KEY (admin_id),
  CONSTRAINT admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.order_statuses (
  order_status_id smallint NOT NULL,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT order_statuses_pkey PRIMARY KEY (order_status_id)
);
CREATE TABLE public.content_types (
  content_type_id smallint NOT NULL,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT content_types_pkey PRIMARY KEY (content_type_id)
);
CREATE TABLE public.notification_types (
  notification_type_id smallint NOT NULL,
  code text NOT NULL UNIQUE,
  name text,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_types_pkey PRIMARY KEY (notification_type_id)
);
CREATE TABLE public.farmer_registrations (
  reviewed_by uuid,
  review_notes text,
  farmer_id uuid NOT NULL UNIQUE,
  registration_id uuid NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'under_review'::text, 'approved'::text, 'rejected'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT farmer_registrations_pkey PRIMARY KEY (registration_id),
  CONSTRAINT farmer_registrations_farmer_id_fkey FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id),
  CONSTRAINT farmer_registrations_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.admins(admin_id)
);
CREATE TABLE public.farmer_crop_types (
  farmer_id uuid NOT NULL,
  crop_type text NOT NULL,
  crop_type_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT farmer_crop_types_pkey PRIMARY KEY (crop_type_id),
  CONSTRAINT farmer_crop_types_farmer_id_fkey FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id)
);
CREATE TABLE public.farmer_livestock (
  farmer_id uuid NOT NULL,
  livestock_type text NOT NULL,
  livestock_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT farmer_livestock_pkey PRIMARY KEY (livestock_id),
  CONSTRAINT farmer_livestock_farmer_id_fkey FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id)
);
CREATE TABLE public.product_inventory (
  product_id uuid NOT NULL UNIQUE,
  available_quantity numeric,
  reserved_quantity numeric,
  low_stock_threshold numeric,
  updated_at timestamp with time zone,
  inventory_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT product_inventory_pkey PRIMARY KEY (inventory_id),
  CONSTRAINT product_inventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.product_images (
  product_id uuid NOT NULL,
  image_url text NOT NULL,
  image_id uuid NOT NULL DEFAULT gen_random_uuid(),
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT product_images_pkey PRIMARY KEY (image_id),
  CONSTRAINT product_images_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.product_reviews (
  product_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  order_id uuid,
  rating numeric NOT NULL CHECK (rating >= 1::numeric AND rating <= 5::numeric),
  review_text text,
  review_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_verified_purchase boolean NOT NULL DEFAULT false,
  helpful_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT product_reviews_pkey PRIMARY KEY (review_id),
  CONSTRAINT product_reviews_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id),
  CONSTRAINT product_reviews_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT product_reviews_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id)
);
CREATE TABLE public.review_images (
  review_id uuid NOT NULL,
  image_url text NOT NULL,
  image_id uuid NOT NULL DEFAULT gen_random_uuid(),
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT review_images_pkey PRIMARY KEY (image_id),
  CONSTRAINT review_images_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.product_reviews(review_id)
);
CREATE TABLE public.farmer_ratings (
  farmer_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  rating numeric NOT NULL CHECK (rating >= 1::numeric AND rating <= 5::numeric),
  review_text text,
  response_text text,
  response_date timestamp with time zone,
  order_id uuid NOT NULL,
  rating_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT farmer_ratings_pkey PRIMARY KEY (rating_id),
  CONSTRAINT farmer_ratings_farmer_id_fkey FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id),
  CONSTRAINT farmer_ratings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT farmer_ratings_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id)
);
CREATE TABLE public.forum_post_likes (
  user_id uuid NOT NULL,
  post_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT forum_post_likes_pkey PRIMARY KEY (user_id, post_id),
  CONSTRAINT forum_post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT forum_post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.forum_posts(post_id)
);
CREATE TABLE public.forum_comment_likes (
  user_id uuid NOT NULL,
  comment_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT forum_comment_likes_pkey PRIMARY KEY (user_id, comment_id),
  CONSTRAINT forum_comment_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT forum_comment_likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.forum_comments(comment_id)
);
CREATE TABLE public.security_rate_limits (
  rate_key text NOT NULL,
  action text NOT NULL,
  blocked_until timestamp with time zone,
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  last_attempt_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT security_rate_limits_pkey PRIMARY KEY (rate_key)
);
CREATE TABLE public.farmer_follows (
  follower_user_id uuid NOT NULL,
  farmer_id uuid NOT NULL,
  follow_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT farmer_follows_pkey PRIMARY KEY (follow_id),
  CONSTRAINT farmer_follows_follower_user_id_fkey FOREIGN KEY (follower_user_id) REFERENCES public.users(user_id),
  CONSTRAINT farmer_follows_farmer_id_fkey FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id)
);
CREATE TABLE public.system_activity_logs (
  actor_user_id uuid NOT NULL,
  action text NOT NULL,
  details text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  log_id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_role text NOT NULL DEFAULT 'User'::text CHECK (actor_role = ANY (ARRAY['Admin'::text, 'Farmer'::text, 'Customer'::text, 'User'::text, 'System'::text])),
  severity text NOT NULL DEFAULT 'info'::text CHECK (severity = ANY (ARRAY['info'::text, 'warning'::text, 'critical'::text])),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT system_activity_logs_pkey PRIMARY KEY (log_id),
  CONSTRAINT system_activity_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.calls (
  conversation_id uuid,
  caller_id uuid NOT NULL,
  receiver_id uuid NOT NULL,
  channel_name text NOT NULL,
  call_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_video boolean NOT NULL DEFAULT false,
  status USER-DEFINED NOT NULL DEFAULT 'ringing'::call_status,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT calls_pkey PRIMARY KEY (call_id),
  CONSTRAINT calls_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(conversation_id),
  CONSTRAINT calls_caller_id_fkey FOREIGN KEY (caller_id) REFERENCES public.users(user_id),
  CONSTRAINT calls_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.users(user_id)
);
CREATE TABLE public.support_tickets (
  user_email text NOT NULL,
  user_name text NOT NULL,
  subject text NOT NULL,
  message_text text NOT NULL,
  ticket_id uuid NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'open'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT support_tickets_pkey PRIMARY KEY (ticket_id)
);
CREATE TABLE public.crop_milestones (
  product_id uuid,
  title character varying NOT NULL,
  description text NOT NULL,
  image_url text,
  milestone_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT crop_milestones_pkey PRIMARY KEY (milestone_id),
  CONSTRAINT crop_milestones_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.vouchers (
  usage_limit integer NOT NULL DEFAULT 100,
  used_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  farmer_id uuid NOT NULL,
  code text NOT NULL,
  discount_type text NOT NULL CHECK (discount_type = ANY (ARRAY['percentage'::text, 'flat'::text])),
  discount_value numeric NOT NULL CHECK (discount_value > 0::numeric),
  max_discount numeric,
  start_date timestamp with time zone NOT NULL,
  end_date timestamp with time zone NOT NULL,
  voucher_id uuid NOT NULL DEFAULT gen_random_uuid(),
  min_spend numeric NOT NULL DEFAULT 0.00 CHECK (min_spend >= 0::numeric),
  CONSTRAINT vouchers_pkey PRIMARY KEY (voucher_id),
  CONSTRAINT vouchers_farmer_id_fkey FOREIGN KEY (farmer_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_claimed_vouchers (
  user_id uuid NOT NULL,
  voucher_id uuid NOT NULL,
  claim_id uuid NOT NULL DEFAULT gen_random_uuid(),
  is_used boolean NOT NULL DEFAULT false,
  claimed_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_claimed_vouchers_pkey PRIMARY KEY (claim_id),
  CONSTRAINT user_claimed_vouchers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT user_claimed_vouchers_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES public.vouchers(voucher_id)
);