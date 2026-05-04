-- Create an atomic offline pre-order flow.
-- The function validates the customer/product, reserves inventory, creates the
-- order and order item, and ensures the customer/farmer conversation exists.

CREATE OR REPLACE FUNCTION public.create_offline_preorder(
  p_product_id uuid,
  p_quantity numeric,
  p_payment_method text,
  p_delivery_address_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_customer_id uuid;
  v_product record;
  v_inventory record;
  v_payment_method text := upper(trim(coalesce(p_payment_method, '')));
  v_pending_status_id smallint;
  v_order_id uuid;
  v_order_number text;
  v_subtotal numeric;
  v_conversation_id uuid;
  v_farmer_user_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be greater than zero';
  END IF;

  IF v_payment_method NOT IN ('COD', 'COP') THEN
    RAISE EXCEPTION 'Offline payment method must be COD or COP';
  END IF;

  SELECT c.customer_id
    INTO v_customer_id
  FROM public.customers c
  WHERE c.user_id = v_user_id
    AND c.is_active = true
  LIMIT 1;

  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Customer profile not found';
  END IF;

  IF p_delivery_address_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.delivery_addresses da
    WHERE da.address_id = p_delivery_address_id
      AND da.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Delivery address does not belong to the current user';
  END IF;

  SELECT p.product_id, p.farmer_id, p.price, p.name
    INTO v_product
  FROM public.products p
  WHERE p.product_id = p_product_id
    AND p.is_preorder = true
    AND p.is_active = true
  LIMIT 1;

  IF v_product.product_id IS NULL THEN
    RAISE EXCEPTION 'Selected pre-order product is not available';
  END IF;

  SELECT pi.inventory_id,
         coalesce(pi.available_quantity, 0) AS available_quantity,
         coalesce(pi.reserved_quantity, 0) AS reserved_quantity
    INTO v_inventory
  FROM public.product_inventory pi
  WHERE pi.product_id = p_product_id
  FOR UPDATE;

  IF v_inventory.inventory_id IS NULL THEN
    RAISE EXCEPTION 'Selected pre-order product does not have inventory configured';
  END IF;

  IF v_inventory.available_quantity < p_quantity THEN
    RAISE EXCEPTION 'Only % units are available for this pre-order', v_inventory.available_quantity;
  END IF;

  SELECT os.order_status_id
    INTO v_pending_status_id
  FROM public.order_statuses os
  WHERE os.code = 'pending'
  LIMIT 1;

  IF v_pending_status_id IS NULL THEN
    RAISE EXCEPTION 'Order status pending is not configured';
  END IF;

  v_subtotal := p_quantity * v_product.price;
  v_order_number := 'ORD-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text
    || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  INSERT INTO public.orders (
    order_number,
    customer_id,
    farmer_id,
    delivery_address_id,
    order_status_id,
    subtotal,
    delivery_fee,
    total_amount,
    payment_method,
    delivery_method,
    special_instructions
  )
  VALUES (
    v_order_number,
    v_customer_id,
    v_product.farmer_id,
    p_delivery_address_id,
    v_pending_status_id,
    v_subtotal,
    0,
    v_subtotal,
    v_payment_method::payment_method_enum,
    CASE WHEN v_payment_method = 'COP' THEN 'pickup' ELSE 'delivery' END,
    NULLIF(trim(coalesce(p_notes, '')), '')
  )
  RETURNING order_id INTO v_order_id;

  INSERT INTO public.order_items (
    order_id,
    product_id,
    quantity,
    unit_price,
    subtotal
  )
  VALUES (
    v_order_id,
    p_product_id,
    p_quantity,
    v_product.price,
    v_subtotal
  );

  UPDATE public.product_inventory
  SET available_quantity = v_inventory.available_quantity - p_quantity,
      reserved_quantity = v_inventory.reserved_quantity + p_quantity,
      updated_at = now()
  WHERE inventory_id = v_inventory.inventory_id;

  INSERT INTO public.conversations (customer_id, farmer_id, last_message_at)
  VALUES (v_customer_id, v_product.farmer_id, now())
  ON CONFLICT (customer_id, farmer_id)
  DO UPDATE SET last_message_at = greatest(public.conversations.last_message_at, excluded.last_message_at)
  RETURNING conversation_id INTO v_conversation_id;

  SELECT f.user_id
    INTO v_farmer_user_id
  FROM public.farmers f
  WHERE f.farmer_id = v_product.farmer_id;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'product_id', p_product_id,
    'product_name', v_product.name,
    'farmer_id', v_product.farmer_id,
    'farmer_user_id', v_farmer_user_id,
    'conversation_id', v_conversation_id,
    'payment_method', v_payment_method,
    'payment_status', 'offline_pending',
    'quantity', p_quantity,
    'total_amount', v_subtotal
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_offline_preorder(uuid, numeric, text, uuid, text) TO authenticated;
