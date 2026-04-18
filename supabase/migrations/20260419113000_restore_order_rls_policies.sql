-- Restore RLS policies for customer order creation and order item inserts.
-- This fixes 42501 errors when authenticated customers place orders.

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS orders_select_customer_or_farmer ON public.orders;
CREATE POLICY orders_select_customer_or_farmer
ON public.orders
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE c.customer_id = orders.customer_id
      AND c.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.farmers f
    WHERE f.farmer_id = orders.farmer_id
      AND f.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS orders_insert_customer_owns_order ON public.orders;
CREATE POLICY orders_insert_customer_owns_order
ON public.orders
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE c.customer_id = orders.customer_id
      AND c.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS orders_update_customer_or_farmer ON public.orders;
CREATE POLICY orders_update_customer_or_farmer
ON public.orders
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE c.customer_id = orders.customer_id
      AND c.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.farmers f
    WHERE f.farmer_id = orders.farmer_id
      AND f.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE c.customer_id = orders.customer_id
      AND c.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.farmers f
    WHERE f.farmer_id = orders.farmer_id
      AND f.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS order_items_select_related_orders ON public.order_items;
CREATE POLICY order_items_select_related_orders
ON public.order_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.customers c ON c.customer_id = o.customer_id
    WHERE o.order_id = order_items.order_id
      AND c.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.farmers f ON f.farmer_id = o.farmer_id
    WHERE o.order_id = order_items.order_id
      AND f.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS order_items_insert_customer_owns_parent_order ON public.order_items;
CREATE POLICY order_items_insert_customer_owns_parent_order
ON public.order_items
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.customers c ON c.customer_id = o.customer_id
    WHERE o.order_id = order_items.order_id
      AND c.user_id = auth.uid()
  )
);
