-- ============================================================================
-- 004_orders_tables.sql
-- Order and transaction management
-- ============================================================================

-- ============================================================================
-- ORDER_STATUS ENUM
-- ============================================================================
CREATE TYPE order_status AS ENUM (
    'pending',
    'confirmed',
    'shipped',
    'delivered',
    'cancelled'
);

-- ============================================================================
-- ORDERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number TEXT NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    farmer_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status order_status DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_farmer_id ON orders(farmer_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- Trigger for auto-update timestamp
CREATE TRIGGER orders_updated_at_trigger
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ORDER_ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
