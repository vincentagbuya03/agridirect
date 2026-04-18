CREATE OR REPLACE VIEW public.v_products AS
SELECT
	p.product_id,
	p.name,
	p.description,
	p.price,
	p.harvest_days,
	p.is_preorder,
	p.is_featured,
	p.is_active,
	p.farmer_id,
	p.category_id,
	p.unit_id,
	p.created_at,
	p.updated_at,
	f.farm_name,
	c.name AS category_name,
	u.name AS unit_name,
	u.abbreviation AS unit_abbr,
	pi.image_url,
	COALESCE(pr.average_rating, 0) AS average_rating,
	COALESCE(pr.review_count, 0) AS review_count,
	COALESCE(oi.total_sold, 0) AS total_sold
FROM public.products p
LEFT JOIN public.farmers f ON f.farmer_id = p.farmer_id
LEFT JOIN public.categories c ON c.category_id = p.category_id
LEFT JOIN public.units u ON u.unit_id = p.unit_id
LEFT JOIN (
	SELECT DISTINCT ON (product_id)
		product_id,
		image_url
	FROM public.product_images
	ORDER BY product_id, sort_order ASC, created_at ASC
) pi ON pi.product_id = p.product_id
LEFT JOIN (
	SELECT
		product_id,
		AVG(rating)::numeric(10,2) AS average_rating,
		COUNT(*)::integer AS review_count
	FROM public.product_reviews
	GROUP BY product_id
) pr ON pr.product_id = p.product_id
LEFT JOIN (
	SELECT
		product_id,
		SUM(quantity) AS total_sold
	FROM public.order_items
	GROUP BY product_id
) oi ON oi.product_id = p.product_id;
