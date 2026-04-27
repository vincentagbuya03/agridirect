-- Migration: Add Missing Column and Fix Trigger
-- Purpose: 
-- 1. Add changed_by_user_id to order_status_logs (it was missing from canonical schema)
-- 2. Update trigger to use the correct columns

BEGIN;

-- 1. Ensure the column exists in order_status_logs
ALTER TABLE public.order_status_logs 
ADD COLUMN IF NOT EXISTS changed_by_user_id uuid REFERENCES public.users(user_id);

-- 2. Update the trigger function
CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.order_status_id IS DISTINCT FROM NEW.order_status_id) THEN
        INSERT INTO public.order_status_logs (
            order_id, 
            order_status_id, 
            changed_by_user_id,
            changed_at -- Using the canonical name from your schema
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

-- 3. Re-attach trigger to ensure it uses the new function
DROP TRIGGER IF EXISTS tr_order_status_change ON public.orders;
CREATE TRIGGER tr_order_status_change
    AFTER UPDATE OF order_status_id ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_order_status_change();

COMMIT;
