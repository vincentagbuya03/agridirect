-- ============================================================================
-- 007_views.sql
-- Database views for computed aggregates (3NF compliant)
-- ============================================================================

-- ============================================================================
-- v_products - Product listing with aggregates
-- ============================================================================
DROP VIEW IF EXISTS v_products CASCADE;
CREATE VIEW v_products AS
SELECT
    p.*,
    c.name AS category_name,
    u.name AS unit_name,
    u.abbreviation AS unit_abbr,
    fp.farm_name,
    COALESCE(ROUND(AVG(pr.rating)::numeric, 1), 0) AS average_rating,
    COUNT(pr.review_id) AS review_count
FROM products p
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN units u ON u.unit_id = p.unit_id
LEFT JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY p.product_id, c.name, u.name, u.abbreviation, fp.farm_name;

-- ============================================================================
-- v_forum_posts - Forum posts with engagement metrics
-- ============================================================================
DROP VIEW IF EXISTS v_forum_posts CASCADE;
CREATE VIEW v_forum_posts AS
SELECT
    fp.*,
    usr.name AS author_name,
    usr.avatar_url AS author_avatar,
    COALESCE(lk.likes_count, 0) AS likes_count,
    COALESCE(cm.comments_count, 0) AS comments_count
FROM forum_posts fp
JOIN users usr ON usr.user_id = fp.user_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS likes_count FROM post_likes GROUP BY post_id
) lk ON lk.post_id = fp.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS comments_count FROM forum_comments GROUP BY post_id
) cm ON cm.post_id = fp.post_id;

-- ============================================================================
-- v_orders - Orders with totals
-- ============================================================================
DROP VIEW IF EXISTS v_orders CASCADE;
CREATE VIEW v_orders AS
SELECT
    o.*,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0)::decimal AS total,
    COUNT(oi.order_item_id) AS item_count
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

-- ============================================================================
-- v_order_items - Order items with subtotals
-- ============================================================================
DROP VIEW IF EXISTS v_order_items CASCADE;
CREATE VIEW v_order_items AS
SELECT
    oi.*,
    (oi.quantity * oi.unit_price)::decimal AS subtotal,
    p.name AS product_name,
    p.image_url AS product_image
FROM order_items oi
LEFT JOIN products p ON p.product_id = oi.product_id;

-- ============================================================================
-- v_farmer_profiles - Farmer profiles with ratings
-- ============================================================================
DROP VIEW IF EXISTS v_farmer_profiles CASCADE;
CREATE VIEW v_farmer_profiles AS
SELECT
    fp.*,
    usr.name AS farmer_name,
    usr.email AS farmer_email,
    usr.phone AS farmer_phone,
    COALESCE(ROUND(AVG(pr.rating)::numeric, 1), 0) AS average_rating,
    COUNT(DISTINCT pr.review_id) AS total_reviews
FROM farmer_profiles fp
JOIN users usr ON usr.user_id = fp.user_id
LEFT JOIN products p ON p.farmer_id = fp.user_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY fp.profile_id, usr.name, usr.email, usr.phone;

-- ============================================================================
-- v_articles - Articles with excerpts
-- ============================================================================
DROP VIEW IF EXISTS v_articles CASCADE;
CREATE VIEW v_articles AS
SELECT
    a.*,
    usr.name AS author_name,
    LEFT(a.content, 200) AS excerpt
FROM articles a
LEFT JOIN users usr ON usr.user_id = a.author_id;

-- ============================================================================
-- v_users_with_roles - Users with their roles
-- ============================================================================
DROP VIEW IF EXISTS v_users_with_roles CASCADE;
CREATE VIEW v_users_with_roles AS
SELECT
    u.*,
    STRING_AGG(r.name, ', ') AS roles
FROM users u
LEFT JOIN user_roles ur ON ur.user_id = u.user_id
LEFT JOIN roles r ON r.role_id = ur.role_id
GROUP BY u.user_id;
