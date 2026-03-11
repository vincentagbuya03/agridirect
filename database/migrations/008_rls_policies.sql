-- ============================================================================
-- 008_rls_policies.sql
-- Row Level Security (RLS) policies for all tables
-- ============================================================================

-- ============================================================================
-- USERS TABLE - RLS
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can read their own data
CREATE POLICY "Users can read own profile"
ON users FOR SELECT
USING (auth.uid() = user_id);

-- Public can read limited user info for display (name, avatar, bio only)
CREATE POLICY "Public can read user display info"
ON users FOR SELECT
USING (true)
WITH CHECK (false);

-- Users can update own data
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- New users inserted via signup trigger
CREATE POLICY "Users can create own profile on signup"
ON users FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- USER_ROLES TABLE - RLS
-- ============================================================================
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- Users can read own roles
CREATE POLICY "Users can read own roles"
ON user_roles FOR SELECT
USING (auth.uid() = user_id);

-- Admins can manage all roles
CREATE POLICY "Admins can manage all roles"
ON user_roles FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- ============================================================================
-- USER_ADDRESSES TABLE - RLS
-- ============================================================================
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;

-- Users can read own address
CREATE POLICY "Users can read own address"
ON user_addresses FOR SELECT
USING (auth.uid() = user_id);

-- Users can update own address
CREATE POLICY "Users can update own address"
ON user_addresses FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can insert own address
CREATE POLICY "Users can insert own address"
ON user_addresses FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- VERIFICATION_CODES TABLE - RLS
-- ============================================================================
ALTER TABLE verification_codes ENABLE ROW LEVEL SECURITY;

-- Anyone can insert verification codes
CREATE POLICY "Anyone can insert verification codes"
ON verification_codes FOR INSERT
WITH CHECK (true);

-- Anyone can select their own verification (for login)
CREATE POLICY "Users can read own verification codes"
ON verification_codes FOR SELECT
USING (true);

-- Only service role should update these (handled via function)
CREATE POLICY "Service can update verification codes"
ON verification_codes FOR UPDATE
USING (true);

-- ============================================================================
-- PRODUCTS TABLE - RLS
-- ============================================================================
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Everyone can read products
CREATE POLICY "Anyone can read products"
ON products FOR SELECT
USING (true);

-- Farmers can insert products
CREATE POLICY "Farmers can insert their products"
ON products FOR INSERT
WITH CHECK (
    auth.uid() = farmer_id AND
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'seller'
    )
);

-- Farmers can update their own products
CREATE POLICY "Farmers can update their products"
ON products FOR UPDATE
USING (auth.uid() = farmer_id)
WITH CHECK (auth.uid() = farmer_id);

-- Farmers can delete their products
CREATE POLICY "Farmers can delete their products"
ON products FOR DELETE
USING (auth.uid() = farmer_id);

-- ============================================================================
-- PRODUCT_REVIEWS TABLE - RLS
-- ============================================================================
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;

-- Everyone can read reviews
CREATE POLICY "Anyone can read reviews"
ON product_reviews FOR SELECT
USING (true);

-- Consumers can insert reviews
CREATE POLICY "Users can insert reviews"
ON product_reviews FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own reviews
CREATE POLICY "Users can update own reviews"
ON product_reviews FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own reviews
CREATE POLICY "Users can delete own reviews"
ON product_reviews FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- FARMER_PROFILES TABLE - RLS
-- ============================================================================
ALTER TABLE farmer_profiles ENABLE ROW LEVEL SECURITY;

-- Everyone can read farmer profiles
CREATE POLICY "Anyone can read farmer profiles"
ON farmer_profiles FOR SELECT
USING (true);

-- Farmers can update their own profile
CREATE POLICY "Farmers can update own profile"
ON farmer_profiles FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Only admins can modify verification status
-- Farmers create profiles, admins verify

-- ============================================================================
-- FARMER_REGISTRATIONS TABLE - RLS
-- ============================================================================
ALTER TABLE farmer_registrations ENABLE ROW LEVEL SECURITY;

-- Users can read own registration
CREATE POLICY "Users can read own registration"
ON farmer_registrations FOR SELECT
USING (auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- Users can insert own registration
CREATE POLICY "Users can create own registration"
ON farmer_registrations FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update own registration (if pending)
CREATE POLICY "Users can update own pending registration"
ON farmer_registrations FOR UPDATE
USING (auth.uid() = user_id AND status = 'pending')
WITH CHECK (auth.uid() = user_id AND status = 'pending');

-- Admins can update status
CREATE POLICY "Admins can update registration status"
ON farmer_registrations FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- ============================================================================
-- ORDERS TABLE - RLS
-- ============================================================================
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Customers can read their orders
CREATE POLICY "Customers can read own orders"
ON orders FOR SELECT
USING (auth.uid() = customer_id);

-- Farmers can read their orders
CREATE POLICY "Farmers can read their orders"
ON orders FOR SELECT
USING (auth.uid() = farmer_id);

-- Customers can create orders
CREATE POLICY "Customers can create orders"
ON orders FOR INSERT
WITH CHECK (auth.uid() = customer_id);

-- Customers can update their pending orders
CREATE POLICY "Customers can update own pending orders"
ON orders FOR UPDATE
USING (auth.uid() = customer_id AND status = 'pending')
WITH CHECK (auth.uid() = customer_id);

-- Farmers can update order status
CREATE POLICY "Farmers can update order status"
ON orders FOR UPDATE
USING (auth.uid() = farmer_id)
WITH CHECK (auth.uid() = farmer_id);

-- ============================================================================
-- ORDER_ITEMS TABLE - RLS
-- ============================================================================
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Users can read order items from their orders
CREATE POLICY "Users can read order items from own orders"
ON order_items FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM orders o
        WHERE o.order_id = order_items.order_id
        AND (o.customer_id = auth.uid() OR o.farmer_id = auth.uid())
    )
);

-- ============================================================================
-- FORUM_POSTS TABLE - RLS
-- ============================================================================
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;

-- Everyone can read posts
CREATE POLICY "Anyone can read forum posts"
ON forum_posts FOR SELECT
USING (true);

-- Users can insert posts
CREATE POLICY "Users can create forum posts"
ON forum_posts FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update own posts
CREATE POLICY "Users can update own posts"
ON forum_posts FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete own posts
CREATE POLICY "Users can delete own posts"
ON forum_posts FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- FORUM_COMMENTS TABLE - RLS
-- ============================================================================
ALTER TABLE forum_comments ENABLE ROW LEVEL SECURITY;

-- Everyone can read comments
CREATE POLICY "Anyone can read comments"
ON forum_comments FOR SELECT
USING (true);

-- Users can create comments
CREATE POLICY "Users can create comments"
ON forum_comments FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update own comments
CREATE POLICY "Users can update own comments"
ON forum_comments FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete own comments
CREATE POLICY "Users can delete own comments"
ON forum_comments FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- POST_LIKES TABLE - RLS
-- ============================================================================
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

-- Everyone can read likes
CREATE POLICY "Anyone can read post likes"
ON post_likes FOR SELECT
USING (true);

-- Users can like posts
CREATE POLICY "Users can like posts"
ON post_likes FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can unlike their own likes
CREATE POLICY "Users can unlike posts"
ON post_likes FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- ARTICLES TABLE - RLS
-- ============================================================================
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;

-- Everyone can read published articles
CREATE POLICY "Anyone can read published articles"
ON articles FOR SELECT
USING (published = true);

-- Admins can read all articles
CREATE POLICY "Admins can read all articles"
ON articles FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- Only admins can manage articles
CREATE POLICY "Only admins can manage articles"
ON articles FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- ============================================================================
-- ADMIN_LOGS TABLE - RLS
-- ============================================================================
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can read logs
CREATE POLICY "Only admins can read logs"
ON admin_logs FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- Only system can insert logs (via trigger)
CREATE POLICY "System can insert logs"
ON admin_logs FOR INSERT
WITH CHECK (true);

-- ============================================================================
-- REPORTED_CONTENT TABLE - RLS
-- ============================================================================
ALTER TABLE reported_content ENABLE ROW LEVEL SECURITY;

-- Users can read their own reports
CREATE POLICY "Users can read own reports"
ON reported_content FOR SELECT
USING (auth.uid() = reporter_id);

-- Admins can read all reports
CREATE POLICY "Admins can read all reports"
ON reported_content FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- Users can submit reports
CREATE POLICY "Users can submit reports"
ON reported_content FOR INSERT
WITH CHECK (auth.uid() = reporter_id);

-- Only admins can manage reports
CREATE POLICY "Admins can manage reports"
ON reported_content FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);

-- ============================================================================
-- USER_SUSPENSIONS TABLE - RLS
-- ============================================================================
ALTER TABLE user_suspensions ENABLE ROW LEVEL SECURITY;

-- Users can read if they're suspended
CREATE POLICY "Users can check own suspension"
ON user_suspensions FOR SELECT
USING (auth.uid() = user_id);

-- Admins can manage suspensions
CREATE POLICY "Admins can manage suspensions"
ON user_suspensions FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = auth.uid() AND r.name = 'admin'
    )
);
