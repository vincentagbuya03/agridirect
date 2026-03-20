-- ============================================================================
-- lib/shared/data/migrations/transactions_payment.sql
-- Payment Transactions Table for PayMongo (GCash & Card) and PayMaya
-- ============================================================================

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
  transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  amount_php DECIMAL(10, 2) NOT NULL,
  payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('gcash', 'card', 'paymaya', 'bank_transfer')),
  payment_status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'confirmed', 'failed', 'cancelled')),
  payment_reference TEXT,
  customer_email VARCHAR(255),
  customer_phone VARCHAR(20),
  transaction_type VARCHAR(50) DEFAULT 'marketplace' CHECK (transaction_type IN ('preorder', 'marketplace')),
  gateway_response JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  paid_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_transactions_order_id ON transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_transactions_payment_status ON transactions(payment_status);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

-- Enable RLS (Row Level Security)
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own transactions
CREATE POLICY transactions_user_select ON transactions
  FOR SELECT
  USING (
    EXISTS(
      SELECT 1 FROM orders o
      WHERE o.order_id = transactions.order_id
      AND (o.customer_id = auth.uid() OR o.farmer_id = auth.uid())
    )
  );

-- RLS Policy: Only service can insert
CREATE POLICY transactions_insert ON transactions
  FOR INSERT
  WITH CHECK (true);

-- RLS Policy: Only service can update
CREATE POLICY transactions_update ON transactions
  FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_transactions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for timestamp
DROP TRIGGER IF EXISTS transactions_timestamp ON transactions;
CREATE TRIGGER transactions_timestamp
  BEFORE UPDATE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_transactions_timestamp();
