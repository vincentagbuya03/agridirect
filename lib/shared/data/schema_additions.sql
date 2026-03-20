-- ============================================================================
-- AGRIDIRECT - ADDITIONAL SCHEMA TABLES
-- Priority Features: Farmer Ratings, Notifications, Messages,
--                   Wishlist, and Farmer Followers
-- ============================================================================
-- Add these tables to your existing schema_3nf_clean.sql
-- ============================================================================

-- ============================================================================
-- PHASE 8: SOCIAL & ENGAGEMENT FEATURES
-- ============================================================================

-- ============================================================================
-- FARMER_RATINGS TABLE (Trust & Reputation System)
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_ratings (
    rating_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(order_id) ON DELETE SET NULL,
    rating DECIMAL(2, 1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    categories JSONB, -- {"delivery": 4.5, "quality": 5, "communication": 4.5}
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(farmer_id, customer_id, order_id) -- One rating per customer-farmer-order combo
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_farmer_id ON farmer_ratings(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_customer_id ON farmer_ratings(customer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_rating ON farmer_ratings(rating DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS farmer_ratings_updated_at_trigger ON farmer_ratings;
CREATE TRIGGER farmer_ratings_updated_at_trigger
BEFORE UPDATE ON farmer_ratings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FARMER_FOLLOWERS TABLE (Follow Farmers)
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_followers (
    follower_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(farmer_id, user_id) -- Prevent duplicate follows
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_farmer_followers_farmer_id ON farmer_followers(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_followers_user_id ON farmer_followers(user_id);

-- ============================================================================
-- CUSTOMER_WISHLIST TABLE (Save Products)
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_wishlist (
    wishlist_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(customer_id, product_id) -- One wishlist entry per customer-product combo
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_customer_wishlist_customer_id ON customer_wishlist(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_wishlist_product_id ON customer_wishlist(product_id);

-- ============================================================================
-- PHASE 9: MESSAGING & NOTIFICATIONS
-- ============================================================================

-- ============================================================================
-- CONVERSATIONS TABLE (Message Thread Base)
-- ============================================================================
CREATE TABLE IF NOT EXISTS conversations (
    conversation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    participant_1_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    participant_2_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(order_id) ON DELETE SET NULL, -- Optional: linked to an order
    last_message_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT different_participants CHECK (participant_1_id != participant_2_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_conversations_participant_1_id ON conversations(participant_1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_2_id ON conversations(participant_2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS conversations_updated_at_trigger ON conversations;
CREATE TRIGGER conversations_updated_at_trigger
BEFORE UPDATE ON conversations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MESSAGES TABLE (Individual Messages)
-- ============================================================================
CREATE TABLE IF NOT EXISTS messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    image_url TEXT, -- Optional attachment
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_id ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_is_read ON messages(is_read);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS messages_updated_at_trigger ON messages;
CREATE TRIGGER messages_updated_at_trigger
BEFORE UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- NOTIFICATIONS TABLE (System & User Notifications)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN (
        'order_created',
        'order_shipped',
        'order_delivered',
        'farmer_approved',
        'farmer_rejected',
        'new_message',
        'product_review',
        'farmer_review',
        'new_follower',
        'product_added',
        'system_alert'
    )),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    related_entity_id UUID, -- Order ID, Farmer ID, Product ID, etc.
    related_entity_type TEXT CHECK (related_entity_type IN (
        'order',
        'farmer',
        'product',
        'farmer_registration',
        'message',
        'user'
    )),
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    action_url TEXT, -- Deep link to navigate in app
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Trigger for auto-update timestamp
DROP TRIGGER IF EXISTS notifications_updated_at_trigger ON notifications;
CREATE TRIGGER notifications_updated_at_trigger
BEFORE UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PHASE 10: UTILITY & ANALYTICS
-- ============================================================================

-- ============================================================================
-- HELPER FUNCTION: Get Average Farmer Rating
-- ============================================================================
CREATE OR REPLACE FUNCTION get_farmer_average_rating(farmer_uuid UUID)
RETURNS TABLE (average_rating DECIMAL, total_ratings BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(AVG(rating), 0::DECIMAL)::DECIMAL as average_rating,
        COUNT(*)::BIGINT as total_ratings
    FROM farmer_ratings
    WHERE farmer_id = farmer_uuid;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- HELPER FUNCTION: Get Unread Message Count
-- ============================================================================
CREATE OR REPLACE FUNCTION get_unread_message_count(user_uuid UUID)
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM messages
        WHERE recipient_id = user_uuid AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- HELPER FUNCTION: Get Unread Notification Count
-- ============================================================================
CREATE OR REPLACE FUNCTION get_unread_notification_count(user_uuid UUID)
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM notifications
        WHERE user_id = user_uuid AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- VIEW: Farmer Statistics
-- ============================================================================
CREATE OR REPLACE VIEW farmer_statistics AS
SELECT
    f.farmer_id,
    f.farm_name,
    COALESCE(AVG(fr.rating), 0::DECIMAL)::DECIMAL(2, 1) as average_rating,
    COUNT(DISTINCT fr.rating_id)::BIGINT as total_ratings,
    COUNT(DISTINCT ff.follower_id)::BIGINT as follower_count,
    COUNT(DISTINCT p.product_id)::BIGINT as product_count,
    COUNT(DISTINCT CASE WHEN o.status = 'delivered' THEN o.order_id END)::BIGINT as completed_orders
FROM farmers f
LEFT JOIN farmer_ratings fr ON f.farmer_id = fr.farmer_id
LEFT JOIN farmer_followers ff ON f.farmer_id = ff.farmer_id
LEFT JOIN products p ON f.farmer_id = p.farmer_id
LEFT JOIN orders o ON f.farmer_id = o.farmer_id
GROUP BY f.farmer_id, f.farm_name;

-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_messages_conversation_is_read ON messages(conversation_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_is_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_farmer_ratings_farmer_rating ON farmer_ratings(farmer_id, rating DESC);

-- ============================================================================
-- PHASE 11: VIEWS FOR SUPABASE READS
-- ============================================================================

-- ============================================================================
-- VIEW: v_farmer_ratings (Farmer Ratings with customer and farm info)
-- ============================================================================
CREATE OR REPLACE VIEW v_farmer_ratings AS
SELECT
    fr.rating_id,
    fr.farmer_id,
    fr.customer_id,
    fr.order_id,
    fr.rating,
    fr.review_text,
    fr.categories,
    fr.created_at,
    fr.updated_at,
    u.name AS customer_name,
    u.avatar_url AS customer_avatar,
    f.farm_name
FROM farmer_ratings fr
JOIN users u ON u.user_id = fr.customer_id
JOIN farmers f ON f.farmer_id = fr.farmer_id;

-- ============================================================================
-- VIEW: v_customer_wishlist (Wishlist with product details)
-- ============================================================================
CREATE OR REPLACE VIEW v_customer_wishlist AS
SELECT
    cw.wishlist_id,
    cw.customer_id,
    cw.product_id,
    cw.created_at,
    p.name AS product_name,
    p.price,
    p.image_url AS product_image,
    p.farmer_id,
    p.is_preorder,
    p.quantity AS product_quantity,
    c.name AS category_name,
    un.name AS unit_name,
    un.abbreviation AS unit_abbr,
    f.farm_name
FROM customer_wishlist cw
JOIN products p ON p.product_id = cw.product_id
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN units un ON un.unit_id = p.unit_id
LEFT JOIN farmers f ON f.farmer_id = p.farmer_id;

-- ============================================================================
-- VIEW: v_conversations (Conversations with participant info and last message)
-- ============================================================================
CREATE OR REPLACE VIEW v_conversations AS
SELECT
    c.conversation_id,
    c.participant_1_id,
    c.participant_2_id,
    c.order_id,
    c.last_message_id,
    c.created_at,
    c.updated_at,
    u1.name AS participant_1_name,
    u1.avatar_url AS participant_1_avatar,
    u2.name AS participant_2_name,
    u2.avatar_url AS participant_2_avatar,
    lm.content AS last_message_content,
    lm.created_at AS last_message_at,
    lm.sender_id AS last_message_sender_id
FROM conversations c
JOIN users u1 ON u1.user_id = c.participant_1_id
JOIN users u2 ON u2.user_id = c.participant_2_id
LEFT JOIN messages lm ON lm.message_id = c.last_message_id;

-- ============================================================================
-- VIEW: v_messages (Messages with sender info)
-- ============================================================================
CREATE OR REPLACE VIEW v_messages AS
SELECT
    m.message_id,
    m.conversation_id,
    m.sender_id,
    m.recipient_id,
    m.content,
    m.image_url,
    m.is_read,
    m.read_at,
    m.created_at,
    m.updated_at,
    u.name AS sender_name,
    u.avatar_url AS sender_avatar
FROM messages m
JOIN users u ON u.user_id = m.sender_id;

-- ============================================================================
-- END OF ADDITIONAL SCHEMA
-- ============================================================================
