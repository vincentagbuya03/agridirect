SELECT o.order_number, os.code as status_code, oi.product_id, oi.quantity
FROM public.orders o
JOIN public.order_statuses os ON o.order_status_id = os.order_status_id
JOIN public.order_items oi ON o.order_id = oi.order_id;
