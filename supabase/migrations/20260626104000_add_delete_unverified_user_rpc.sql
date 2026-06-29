-- Migration: Add RPC to delete unverified user to allow re-registration
-- Purpose:
--   Allows deleting user record from auth.users and public.users if the email is not verified yet.

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_unverified_user(p_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text := lower(trim(coalesce(p_email, '')));
  v_user_id uuid;
  v_email_verified boolean;
BEGIN
  -- Get user ID and verified status from public.users
  SELECT user_id, email_verified
  INTO v_user_id, v_email_verified
  FROM public.users
  WHERE lower(email) = v_email;

  -- If user exists and is not verified, delete them
  IF v_user_id IS NOT NULL AND (v_email_verified IS NOT TRUE) THEN
    -- Delete from any table referencing user_id to ensure clean deletion
    DELETE FROM public.verification_codes WHERE user_id = v_user_id;
    DELETE FROM public.user_roles WHERE user_id = v_user_id;
    DELETE FROM public.admins WHERE user_id = v_user_id;
    DELETE FROM public.customers WHERE user_id = v_user_id;
    DELETE FROM public.farmers WHERE user_id = v_user_id;
    DELETE FROM public.delivery_addresses WHERE user_id = v_user_id;
    DELETE FROM public.user_device_tokens WHERE user_id = v_user_id;
    DELETE FROM public.app_sessions WHERE user_id = v_user_id;
    DELETE FROM public.notifications WHERE user_id = v_user_id;
    DELETE FROM public.users WHERE user_id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_unverified_user(text) TO anon, authenticated;

COMMIT;
