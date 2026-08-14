-- Migration: Support free shipping and product-specific vouchers

-- Add discount_type column to support different voucher types
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS discount_type TEXT DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'flat', 'free_shipping'));

-- Add product_id to support product-specific vouchers
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(product_id) ON DELETE CASCADE;

-- Add max_discount for flat caps on percentage or free shipping
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS max_discount NUMERIC;

-- Update the existing view or create a new one to safely expose vouchers
CREATE OR REPLACE VIEW v_vouchers AS
SELECT 
    v.voucher_id,
    v.farmer_id,
    v.product_id,
    v.title,
    v.description,
    v.code,
    v.discount_type,
    v.discount_percentage,
    v.min_spend,
    v.max_discount,
    v.valid_until as end_date,
    f.farm_name,
    f.image_url as farm_image_url
FROM vouchers v
LEFT JOIN farmers f ON v.farmer_id = f.farmer_id;