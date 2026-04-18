-- Cleanup migration: user_addresses has been replaced by delivery_addresses.
-- Drop the legacy table safely.

DROP POLICY IF EXISTS user_addresses_select_own ON public.user_addresses;
DROP POLICY IF EXISTS user_addresses_insert_own ON public.user_addresses;
DROP POLICY IF EXISTS user_addresses_update_own ON public.user_addresses;
DROP POLICY IF EXISTS user_addresses_delete_own ON public.user_addresses;

DROP TABLE IF EXISTS public.user_addresses;