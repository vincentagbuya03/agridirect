-- Add unique constraint to cart_items to prevent duplicate products for the same customer
ALTER TABLE public.cart_items 
ADD CONSTRAINT unique_customer_product UNIQUE (customer_id, product_id);

-- Cleanup existing duplicates if any (keeping the one with the largest quantity)
DELETE FROM public.cart_items a
USING public.cart_items b
WHERE a.cart_item_id < b.cart_item_id
  AND a.customer_id = b.customer_id
  AND a.product_id = b.product_id;
