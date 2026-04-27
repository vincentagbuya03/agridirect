-- Migration: Final Fix for Order Status Trigger and Views
-- Purpose:
-- 1. Fix the broken order status logging trigger (column changed_by rename)
-- 2. Restore v_orders with customer avatars and correct columns
-- 3. Resolve "lookup_values" missing relation errors by using a clean split-table approach

BEGIN;

-- 1. Fix the logging function to use 'changed_by_user_id'
CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.order_status_id IS DISTINCT FROM NEW.order_status_id) THEN
        INSERT INTO public.order_status_logs (
            order_id, 
            order_status_id, 
            changed_by_user_id, -- Correct column name from normalized schema
            created_at
        )
        VALUES (
            NEW.order_id, 
            NEW.order_status_id, 
            auth.uid(),
            now()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Ensure trigger is attached correctly
DROP TRIGGER IF EXISTS tr_order_status_change ON public.orders;
CREATE TRIGGER tr_order_status_change
    AFTER UPDATE OF order_status_id ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_order_status_change();

-- 3. Restore v_orders view with customer_image (avatar)
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
  f.farm_name as farmer_name,
  os.code as status,
  os.code as status_code,
  os.description as status_description,
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
LEFT JOIN order_statuses os ON os.order_status_id = o.order_status_id;

COMMIT;
