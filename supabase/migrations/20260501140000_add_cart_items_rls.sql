-- Enable RLS for cart_items
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own cart items
-- We join with customers to link auth.uid() (user_id) to customer_id
CREATE POLICY "Users can view their own cart items"
  ON public.cart_items
  FOR SELECT
  USING (
    customer_id IN (
      SELECT customer_id FROM public.customers WHERE user_id = auth.uid()
    )
  );

-- Policy: Users can insert their own cart items
CREATE POLICY "Users can insert their own cart items"
  ON public.cart_items
  FOR INSERT
  WITH CHECK (
    customer_id IN (
      SELECT customer_id FROM public.customers WHERE user_id = auth.uid()
    )
  );

-- Policy: Users can update their own cart items
CREATE POLICY "Users can update their own cart items"
  ON public.cart_items
  FOR UPDATE
  USING (
    customer_id IN (
      SELECT customer_id FROM public.customers WHERE user_id = auth.uid()
    )
  );

-- Policy: Users can delete their own cart items
CREATE POLICY "Users can delete their own cart items"
  ON public.cart_items
  FOR DELETE
  USING (
    customer_id IN (
      SELECT customer_id FROM public.customers WHERE user_id = auth.uid()
    )
  );
