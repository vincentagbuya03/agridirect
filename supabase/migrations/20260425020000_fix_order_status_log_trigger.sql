-- Migration: Fix Order Status Logging Trigger
-- Purpose: Update the status logging trigger to use 'changed_by_user_id' instead of 'changed_by'
-- and ensure the 'v_orders' view is restored with customer name and image.

BEGIN;

-- 1. Fix the logging function
CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if the status has actually changed
    IF (OLD.order_status_id IS DISTINCT FROM NEW.order_status_id) THEN
        INSERT INTO public.order_status_logs (
            order_id, 
            order_status_id, 
            changed_by_user_id, -- Using the new column name from normalize_schema_to_2nf
            created_at
        )
        VALUES (
            NEW.order_id, 
            NEW.order_status_id, 
            auth.uid(), -- The user performing the update
            now()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Ensure the trigger is attached to the orders table
DROP TRIGGER IF EXISTS tr_order_status_change ON public.orders;
CREATE TRIGGER tr_order_status_change
    AFTER UPDATE OF order_status_id ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_order_status_change();

-- 3. Restore the v_orders view with customer name and image
-- This fixes the issue where customer profiles were showing as 'Customer' or empty
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
LEFT JOIN order_statuses os ON os.order_status_id = o.order_status_id;

COMMIT;
