-- Emergency Fix: Force remove broken order status logging trigger
-- The trigger exists on remote DB but tries to use non-existent 'changed_by' column.
-- This migration ensures it's completely gone.

BEGIN;

-- 1. Drop any existing triggers on orders table
DROP TRIGGER IF EXISTS tr_order_status_change ON public.orders CASCADE;
DROP TRIGGER IF EXISTS update_order_status_log ON public.orders CASCADE;
DROP TRIGGER IF EXISTS tr_log_order_status_change ON public.orders CASCADE;

-- 2. Drop the trigger function(s) if they exist
DROP FUNCTION IF EXISTS public.handle_order_status_change() CASCADE;
DROP FUNCTION IF EXISTS public.log_order_status_change() CASCADE;
DROP FUNCTION IF EXISTS public.fn_log_order_status_change() CASCADE;

-- 3. Ensure order_status_logs table doesn't require changed_by column
-- Just drop it completely since it's not referenced in the canonical schema
DROP TABLE IF EXISTS public.order_status_logs CASCADE;

COMMIT;
