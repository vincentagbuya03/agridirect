-- Migration: Fix v_products view to include stock_quantity from product_inventory
-- Date: 2026-04-21
-- Purpose: 
--   - Join products with product_inventory table
--   - Expose available_quantity as stock_quantity for the Admin Dashboard
--   - Ensure product list and summary metrics work correctly

BEGIN;

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

COMMIT;
