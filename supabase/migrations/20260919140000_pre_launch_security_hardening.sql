-- Migration: 20260919140000_pre_launch_security_hardening.sql
-- Pre-Launch Security Hardening: RLS Enforcement, Storage Lockdown, and Privilege Protections

BEGIN;

-- ============================================================================
-- 1. REVOKE PUBLIC ACCESS ON SENSITIVE RPCs (Fix Zero-Click Account Takeover)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.request_password_reset_code(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.request_password_reset_code(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.request_password_reset_code(text) TO service_role;

-- ============================================================================
-- 2. SECURE STORAGE BUCKETS & STORAGE OBJECTS
-- ============================================================================
-- Ensure registrations bucket is PRIVATE to protect government IDs and biometric face scans
UPDATE storage.buckets SET public = false WHERE id = 'registrations';
UPDATE storage.buckets SET public = true WHERE id = 'uploads';

-- Drop overly permissive public / delete storage policies
DROP POLICY IF EXISTS "Public Access Uploads And Registrations" ON storage.objects;
DROP POLICY IF EXISTS "Public Access Registrations" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Delete Objects" ON storage.objects;
DROP POLICY IF EXISTS "Restricted Access Registrations" ON storage.objects;
DROP POLICY IF EXISTS "Public Access Uploads" ON storage.objects;

-- Public read access ONLY for uploads (product photos, avatars)
CREATE POLICY "Public Access Uploads"
ON storage.objects FOR SELECT
USING ( bucket_id = 'uploads' );

-- Restricted read for registrations: only owner or active admin can select
CREATE POLICY "Restricted Access Registrations"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'registrations' AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true
    )
  )
);

-- Ownership-based delete policy: users can only delete their own uploads
CREATE POLICY "Authenticated Delete Objects"
ON storage.objects FOR DELETE
TO authenticated
USING (
  (bucket_id = 'uploads' AND (storage.foldername(name))[1] = auth.uid()::text)
  OR (bucket_id = 'registrations' AND (storage.foldername(name))[1] = auth.uid()::text)
  OR EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true
  )
);

-- ============================================================================
-- 3. ENABLE RLS ON SENSITIVE UNPROTECTED TABLES
-- ============================================================================

-- A. ROLES
ALTER TABLE IF EXISTS public.roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "roles_select_public" ON public.roles;
CREATE POLICY "roles_select_public"
ON public.roles FOR SELECT
TO authenticated, anon
USING (true);

-- B. USER_ROLES
ALTER TABLE IF EXISTS public.user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_roles_select_self_or_admin" ON public.user_roles;
CREATE POLICY "user_roles_select_self_or_admin"
ON public.user_roles FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true
  )
);

DROP POLICY IF EXISTS "user_roles_insert_customer_self" ON public.user_roles;
CREATE POLICY "user_roles_insert_customer_self"
ON public.user_roles FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role_id IN (SELECT role_id FROM public.roles WHERE lower(name) = 'customer')
);

DROP POLICY IF EXISTS "user_roles_admin_all" ON public.user_roles;
CREATE POLICY "user_roles_admin_all"
ON public.user_roles FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true
  )
);

-- C. PRODUCT_INVENTORY
ALTER TABLE IF EXISTS public.product_inventory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "product_inventory_select_all" ON public.product_inventory;
CREATE POLICY "product_inventory_select_all"
ON public.product_inventory FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "product_inventory_modify_farmer_or_admin" ON public.product_inventory;
CREATE POLICY "product_inventory_modify_farmer_or_admin"
ON public.product_inventory FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.products p
    JOIN public.farmers f ON f.farmer_id = p.farmer_id
    WHERE p.product_id = product_inventory.product_id
      AND f.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.products p
    JOIN public.farmers f ON f.farmer_id = p.farmer_id
    WHERE p.product_id = product_inventory.product_id
      AND f.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true
  )
);

-- D. SECURITY_RATE_LIMITS
ALTER TABLE IF EXISTS public.security_rate_limits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "security_rate_limits_service_role" ON public.security_rate_limits;
CREATE POLICY "security_rate_limits_service_role"
ON public.security_rate_limits FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- E. CATEGORIES & UNITS
ALTER TABLE IF EXISTS public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "categories_select_all" ON public.categories;
CREATE POLICY "categories_select_all" ON public.categories FOR SELECT TO authenticated, anon USING (true);
DROP POLICY IF EXISTS "categories_admin_all" ON public.categories;
CREATE POLICY "categories_admin_all" ON public.categories FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true)
);

ALTER TABLE IF EXISTS public.units ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "units_select_all" ON public.units;
CREATE POLICY "units_select_all" ON public.units FOR SELECT TO authenticated, anon USING (true);
DROP POLICY IF EXISTS "units_admin_all" ON public.units;
CREATE POLICY "units_admin_all" ON public.units FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid() AND a.is_active = true)
);

-- ============================================================================
-- 4. HARDEN ORDER UPDATE POLICIES (Prevent customer price/status tampering)
-- ============================================================================
DROP POLICY IF EXISTS orders_update_customer_or_farmer ON public.orders;
DROP POLICY IF EXISTS orders_update_farmer ON public.orders;
DROP POLICY IF EXISTS orders_update_customer_pending_only ON public.orders;

-- Farmers can update orders placed with their farm
CREATE POLICY orders_update_farmer
ON public.orders
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.farmers f
    WHERE f.farmer_id = orders.farmer_id
      AND f.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.admins a
    WHERE a.user_id = auth.uid() AND a.is_active = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.farmers f
    WHERE f.farmer_id = orders.farmer_id
      AND f.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.admins a
    WHERE a.user_id = auth.uid() AND a.is_active = true
  )
);

-- Customers can only update their own order when status is still 'pending' (e.g. to cancel)
CREATE POLICY orders_update_customer_pending_only
ON public.orders
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.customers c
    JOIN public.order_statuses os ON os.order_status_id = orders.order_status_id
    WHERE c.customer_id = orders.customer_id
      AND c.user_id = auth.uid()
      AND lower(os.code) = 'pending'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE c.customer_id = orders.customer_id
      AND c.user_id = auth.uid()
  )
);

-- ============================================================================
-- 5. ATOMIC INVENTORY REDUCTION & RESTORATION (Product Inventory + Products Sync)
-- ============================================================================
CREATE OR REPLACE FUNCTION decrement_product_stock_atomic(
  p_product_id uuid,
  p_quantity numeric
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_available numeric;
  v_is_preorder boolean := false;
BEGIN
  -- Check preorder status
  SELECT COALESCE(is_preorder, false) INTO v_is_preorder
  FROM public.products
  WHERE product_id = p_product_id;

  -- Lock row in product_inventory exclusively for this transaction
  SELECT available_quantity INTO v_available
  FROM public.product_inventory
  WHERE product_id = p_product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Fallback lock on products table if inventory record was absent
    SELECT stock_quantity INTO v_available
    FROM public.products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;
  END IF;

  IF v_available < p_quantity THEN
    RETURN false; -- Insufficient inventory
  END IF;

  -- Update product_inventory atomically
  IF v_is_preorder THEN
    UPDATE public.product_inventory
    SET available_quantity = available_quantity - p_quantity,
        reserved_quantity = COALESCE(reserved_quantity, 0) + p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;
  ELSE
    UPDATE public.product_inventory
    SET available_quantity = available_quantity - p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;
  END IF;

  -- Sync products.stock_quantity for view compatibility
  UPDATE public.products
  SET stock_quantity = GREATEST(0, stock_quantity - p_quantity),
      updated_at = now()
  WHERE product_id = p_product_id;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION restore_product_stock_atomic(
  p_product_id uuid,
  p_quantity numeric
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_preorder boolean := false;
BEGIN
  SELECT COALESCE(is_preorder, false) INTO v_is_preorder
  FROM public.products
  WHERE product_id = p_product_id;

  -- Lock row in product_inventory
  PERFORM 1 FROM public.product_inventory WHERE product_id = p_product_id FOR UPDATE;

  IF v_is_preorder THEN
    UPDATE public.product_inventory
    SET available_quantity = available_quantity + p_quantity,
        reserved_quantity = GREATEST(0, COALESCE(reserved_quantity, 0) - p_quantity),
        updated_at = now()
    WHERE product_id = p_product_id;
  ELSE
    UPDATE public.product_inventory
    SET available_quantity = available_quantity + p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;
  END IF;

  -- Sync products.stock_quantity
  UPDATE public.products
  SET stock_quantity = stock_quantity + p_quantity,
      updated_at = now()
  WHERE product_id = p_product_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION decrement_product_stock_atomic(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_product_stock_atomic(uuid, numeric) TO service_role;
GRANT EXECUTE ON FUNCTION restore_product_stock_atomic(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_product_stock_atomic(uuid, numeric) TO service_role;

COMMIT;
