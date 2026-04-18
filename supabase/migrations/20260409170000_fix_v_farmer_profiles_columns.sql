-- Fix v_farmer_profiles view by adding missing columns
-- These columns are referenced in admin_service.dart but were missing from the view
-- Note: Must DROP and recreate the view (can't use CREATE OR REPLACE when reordering columns)

DROP VIEW IF EXISTS v_farmer_profiles CASCADE;

CREATE VIEW v_farmer_profiles AS
SELECT 
    f.farmer_id,
    f.user_id,
    f.farm_name,
    f.specialty,
    f.location,
    f.residential_address,
    f.farming_history,
    f.badge,
    f.image_url,
    f.is_verified,
    f.is_active,
    f.registration_status_id,
    f.created_at,
    f.updated_at,
    f.birth_date,
    f.years_of_experience,
    f.face_photo_path,
    f.valid_id_path,
    u.name as farmer_name,
    u.email as farmer_email,
    u.phone as farmer_phone,
    u.avatar_url,
    COALESCE((SELECT SUM(total_amount) FROM orders WHERE farmer_id = f.farmer_id AND order_status_id = (SELECT order_status_id FROM order_statuses WHERE code = 'completed')), 0) as total_sales,
    COALESCE((SELECT COUNT(*) FROM products WHERE farmer_id = f.farmer_id AND is_active = true), 0) as total_products,
    COALESCE((SELECT AVG(rating) FROM farmer_ratings WHERE farmer_id = f.farmer_id), 0) as average_rating,
    COALESCE((SELECT COUNT(*) FROM farmer_ratings WHERE farmer_id = f.farmer_id), 0) as total_reviews
FROM farmers f
JOIN users u ON f.user_id = u.user_id;
