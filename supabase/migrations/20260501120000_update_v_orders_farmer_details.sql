-- Migration: Update v_orders to include farmer details and item count
-- Purpose: Support farmer image display and better order summaries in the UI

BEGIN;

DROP VIEW IF EXISTS public.v_orders CASCADE;

CREATE VIEW public.v_orders AS
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
  f.farm_name as farm_name, -- Renamed from farmer_name to match model
  f.farm_name as farmer_name, -- Keep for backward compatibility if needed
  COALESCE(f.image_url, fu.avatar_url) as farmer_avatar_url,
  os.code as status,
  os.code as status_code,
  os.description as status_description,
  (
    SELECT string_agg(p.name || ' (x' || oi.quantity || ')', ', ')
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE oi.order_id = o.order_id
  ) as items,
  (
    SELECT COUNT(*)::int
    FROM order_items
    WHERE order_id = o.order_id
  ) as item_count
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN users u ON c.user_id = u.user_id
LEFT JOIN farmers f ON o.farmer_id = f.farmer_id
LEFT JOIN users fu ON f.user_id = fu.user_id
LEFT JOIN order_statuses os ON o.order_status_id = os.order_status_id;

COMMIT;
