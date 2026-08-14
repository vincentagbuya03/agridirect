-- Seed Free Shipping Vouchers

-- We need a valid farmer_id. Let's find one.
DO $$ 
DECLARE 
    test_farmer_id UUID;
BEGIN
    SELECT farmer_id INTO test_farmer_id FROM farmers LIMIT 1;
    
    IF test_farmer_id IS NOT NULL THEN
        -- Insert a Free Shipping voucher
        INSERT INTO vouchers (farmer_id, title, description, code, discount_type, min_spend, valid_until)
        VALUES (
            test_farmer_id,
            'Free Delivery on Fresh Goods',
            'For orders ₱249 and above',
            'FS100',
            'free_shipping',
            249,
            NOW() + INTERVAL '30 days'
        ) ON CONFLICT (code) DO NOTHING;
        
        -- Insert another voucher
        INSERT INTO vouchers (farmer_id, title, description, code, discount_type, min_spend, valid_until)
        VALUES (
            test_farmer_id,
            'Farm-to-Table Express',
            'Max discount of ₱300',
            'FS200',
            'free_shipping',
            0,
            NOW() + INTERVAL '30 days'
        ) ON CONFLICT (code) DO NOTHING;
    END IF;
END $$;