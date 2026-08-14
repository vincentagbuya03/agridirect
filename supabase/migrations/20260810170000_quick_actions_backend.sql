-- Migration: Add fields for Quick Actions and Vouchers System
-- Date: 2026-08-10

BEGIN;

-- 1. Add new columns to products
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS is_free_shipping boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_wholesale boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_flash_sale boolean DEFAULT false;

-- 2. Create vouchers tables
CREATE TABLE IF NOT EXISTS public.vouchers (
  voucher_id uuid NOT NULL DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL,
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  description text,
  discount_percentage numeric,
  min_spend numeric,
  valid_until timestamp with time zone,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT vouchers_pkey PRIMARY KEY (voucher_id),
  CONSTRAINT fk_vouchers_farmer FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.user_vouchers (
  user_voucher_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  voucher_id uuid NOT NULL,
  status text DEFAULT 'available' CHECK (status IN ('available', 'used', 'expired')),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_vouchers_pkey PRIMARY KEY (user_voucher_id),
  CONSTRAINT fk_user_vouchers_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_user_vouchers_voucher FOREIGN KEY (voucher_id) REFERENCES public.vouchers(voucher_id) ON DELETE CASCADE
);

-- 3. Recreate v_products to include the new columns
DROP VIEW IF EXISTS public.v_products CASCADE;

CREATE OR REPLACE VIEW public.v_products AS
SELECT
  p.product_id,
  p.name,
  p.description,
  p.price,
  p.harvest_days,
  p.is_preorder,
  p.is_featured,
  p.is_active,
  p.is_free_shipping,
  p.is_wholesale,
  p.is_flash_sale,
  p.farmer_id,
  p.category_id,
  p.unit_id,
  p.created_at,
  p.updated_at,
  f.farm_name,
  c.name AS category_name,
  u.name AS unit_name,
  u.abbreviation AS unit_abbr,
  COALESCE(inv.available_quantity, 0)::numeric AS stock_quantity,
  (
    SELECT pi.image_url
    FROM product_images pi
    WHERE pi.product_id = p.product_id
    ORDER BY pi.sort_order ASC, pi.created_at ASC
    LIMIT 1
  ) AS image_url,
  COALESCE((
    SELECT AVG(pr.rating)
    FROM product_reviews pr
    WHERE pr.product_id = p.product_id
  ), 0)::numeric(10,2) AS average_rating,
  COALESCE((
    SELECT COUNT(*)
    FROM product_reviews pr
    WHERE pr.product_id = p.product_id
  ), 0)::integer AS review_count,
  COALESCE((
    SELECT SUM(oi.quantity)
    FROM order_items oi
    WHERE oi.product_id = p.product_id
  ), 0)::numeric AS total_sold
FROM products p
LEFT JOIN farmers f ON f.farmer_id = p.farmer_id
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN units u ON u.unit_id = p.unit_id
LEFT JOIN product_inventory inv ON inv.product_id = p.product_id;

-- Ensure RLS is enabled for the new tables (Optional but good practice)
ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_vouchers ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read vouchers
CREATE POLICY "Allow read access to all users" ON public.vouchers FOR SELECT USING (true);
CREATE POLICY "Allow users to read their own vouchers" ON public.user_vouchers FOR SELECT USING (auth.uid() = user_id);

COMMIT;
