-- Migration: Add discount_percent, flash_sale_start, flash_sale_end to products and expose in v_products
-- Date: 2026-08-16

BEGIN;

-- 1. Add discount_percent, flash_sale_start, and flash_sale_end to products table
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS discount_percent numeric DEFAULT 30,
ADD COLUMN IF NOT EXISTS flash_sale_start timestamp with time zone DEFAULT now(),
ADD COLUMN IF NOT EXISTS flash_sale_end timestamp with time zone DEFAULT (now() + interval '24 hours');

-- 2. Update v_products view to include flash sale scheduling columns
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
  p.discount_percent,
  p.flash_sale_start,
  p.flash_sale_end,
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
  ), 0)::numeric AS sold_count,
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

COMMIT;
