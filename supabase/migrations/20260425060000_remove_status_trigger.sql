-- Migration: Remove Order Status Logging Trigger
-- Purpose: 
-- 1. Stop the errors by removing the trigger that attempts to log status changes
--    since the user mentioned they don't have/need the order_status_logs table for this.

BEGIN;

-- 1. Drop the trigger from the orders table
DROP TRIGGER IF EXISTS tr_order_status_change ON public.orders;
DROP TRIGGER IF EXISTS update_order_status_log ON public.orders;

-- 2. Drop the trigger function
DROP FUNCTION IF EXISTS public.handle_order_status_change();

COMMIT;
