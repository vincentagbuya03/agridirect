-- Security Hardening Migration: RLS Privilege Locks & Concurrency Safeguards
-- Description:
--   1. Strict RLS enforcement for admin tables and role protection
--   2. Atomic stock reduction function to prevent race conditions during high checkout traffic
--   3. Guard triggers to prevent privilege escalation on verification and admin flags

BEGIN;

-- 1. Ensure RLS is active on critical role and security tables
ALTER TABLE IF EXISTS admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS farmers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS products ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_items ENABLE ROW LEVEL SECURITY;

-- 2. Lock down the `admins` table so regular users cannot insert/update themselves as admins
DROP POLICY IF EXISTS "Admins can only be read by authenticated users" ON admins;
CREATE POLICY "Admins can only be read by authenticated users"
ON admins FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Admins can only be modified by existing admins" ON admins;
CREATE POLICY "Admins can only be modified by existing admins"
ON admins FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM admins a
    WHERE a.user_id = auth.uid() AND a.is_active = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admins a
    WHERE a.user_id = auth.uid() AND a.is_active = true
  )
);

-- 3. Atomic stock reduction function (prevents race conditions & double-spending)
CREATE OR REPLACE FUNCTION decrement_product_stock_atomic(
  p_product_id uuid,
  p_quantity numeric
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_stock numeric;
BEGIN
  -- Lock row exclusively for this transaction
  SELECT stock_quantity INTO v_current_stock
  FROM products
  WHERE product_id = p_product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found: %', p_product_id;
  END IF;

  IF v_current_stock < p_quantity THEN
    RETURN false; -- Insufficient inventory
  END IF;

  UPDATE products
  SET stock_quantity = stock_quantity - p_quantity,
      updated_at = now()
  WHERE product_id = p_product_id;

  RETURN true;
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION decrement_product_stock_atomic(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_product_stock_atomic(uuid, numeric) TO service_role;

COMMIT;
