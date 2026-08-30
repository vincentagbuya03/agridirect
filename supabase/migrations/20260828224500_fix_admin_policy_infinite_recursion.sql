-- Fix infinite recursion in admins RLS policy & restore customer/farmer access
BEGIN;

-- 1. Create a SECURITY DEFINER helper function to safely check admin status without recursive policy evaluation
CREATE OR REPLACE FUNCTION is_active_admin(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admins
    WHERE user_id = p_user_id AND is_active = true
  );
$$;

GRANT EXECUTE ON FUNCTION is_active_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_active_admin(uuid) TO anon;
GRANT EXECUTE ON FUNCTION is_active_admin(uuid) TO service_role;

-- 2. Fix `admins` table RLS policies
DROP POLICY IF EXISTS "Admins can only be read by authenticated users" ON admins;
DROP POLICY IF EXISTS "Admins can only be modified by existing admins" ON admins;
DROP POLICY IF EXISTS "Admins read access" ON admins;
DROP POLICY IF EXISTS "Admins write access" ON admins;

CREATE POLICY "Admins read access"
ON admins FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Admins write access"
ON admins FOR ALL
TO authenticated
USING (is_active_admin())
WITH CHECK (is_active_admin());

-- 3. Fix `customers` table RLS policies (allow self-registration and profile auto-healing)
DROP POLICY IF EXISTS "Customers read access" ON customers;
DROP POLICY IF EXISTS "Customers insert access" ON customers;
DROP POLICY IF EXISTS "Customers update access" ON customers;
DROP POLICY IF EXISTS "Users can insert their own customer record" ON customers;
DROP POLICY IF EXISTS "Users can view and update their own customer record" ON customers;

CREATE POLICY "Customers read access"
ON customers FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Customers insert access"
ON customers FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id OR is_active_admin());

CREATE POLICY "Customers update access"
ON customers FOR UPDATE
TO authenticated
USING (auth.uid() = user_id OR is_active_admin())
WITH CHECK (auth.uid() = user_id OR is_active_admin());

-- 4. Ensure `farmers` table allows reading and self-management
DROP POLICY IF EXISTS "Farmers read access" ON farmers;
DROP POLICY IF EXISTS "Farmers insert access" ON farmers;
DROP POLICY IF EXISTS "Farmers update access" ON farmers;

CREATE POLICY "Farmers read access"
ON farmers FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Farmers insert access"
ON farmers FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id OR is_active_admin());

CREATE POLICY "Farmers update access"
ON farmers FOR UPDATE
TO authenticated
USING (auth.uid() = user_id OR is_active_admin())
WITH CHECK (auth.uid() = user_id OR is_active_admin());

COMMIT;
