-- ============================================================================
-- lib/shared/data/migrations/farmer_payouts.sql
-- Farmer Payouts System for PayMongo Transfers
-- ============================================================================

-- ============================================================================
-- Table: farmer_bank_accounts
-- Purpose: Store farmer's bank account information for payouts
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_bank_accounts (
  bank_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  bank_name VARCHAR(100) NOT NULL,        -- e.g., "BDO", "BPI", "RCBC"
  bank_code VARCHAR(20) NOT NULL,         -- PayMongo bank code
  account_name VARCHAR(255) NOT NULL,     -- Name on account
  account_number TEXT NOT NULL,           -- Encrypted in code before storage
  account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('savings', 'checking')),
  is_primary BOOLEAN DEFAULT true,        -- Default payout account
  verified BOOLEAN DEFAULT false,         -- After micro-deposit verification
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  UNIQUE(farmer_id, account_number),      -- Prevent duplicate accounts per farmer
  CONSTRAINT fk_farmer FOREIGN KEY (farmer_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Create indexes for farmer_bank_accounts
CREATE INDEX IF NOT EXISTS idx_farmer_bank_accounts_farmer_id ON farmer_bank_accounts(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_bank_accounts_is_primary ON farmer_bank_accounts(is_primary);

-- Enable RLS on farmer_bank_accounts
ALTER TABLE farmer_bank_accounts ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Farmers can view their own accounts
CREATE POLICY farmer_bank_accounts_select ON farmer_bank_accounts
  FOR SELECT
  USING (farmer_id = auth.uid() OR auth.role() = 'service_role');

-- RLS Policy: Farmers can insert their own accounts
CREATE POLICY farmer_bank_accounts_insert ON farmer_bank_accounts
  FOR INSERT
  WITH CHECK (farmer_id = auth.uid() OR auth.role() = 'service_role');

-- RLS Policy: Farmers can update their own accounts
CREATE POLICY farmer_bank_accounts_update ON farmer_bank_accounts
  FOR UPDATE
  USING (farmer_id = auth.uid() OR auth.role() = 'service_role')
  WITH CHECK (farmer_id = auth.uid() OR auth.role() = 'service_role');

-- RLS Policy: Farmers can delete their own accounts
CREATE POLICY farmer_bank_accounts_delete ON farmer_bank_accounts
  FOR DELETE
  USING (farmer_id = auth.uid() OR auth.role() = 'service_role');

-- ============================================================================
-- Table: farmer_payouts
-- Purpose: Track payout requests and their status
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_payouts (
  payout_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  amount_php DECIMAL(10, 2) NOT NULL,
  payout_status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (
    payout_status IN ('pending', 'approved', 'processing', 'completed', 'failed')
  ),
  bank_account_id UUID NOT NULL REFERENCES farmer_bank_accounts(bank_account_id) ON DELETE RESTRICT,
  paymongo_payout_id TEXT,                -- PayMongo's payout ID
  transaction_reference TEXT,             -- For tracking
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approved_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  failed_reason TEXT,                     -- Reason for failure
  paymongo_response JSONB,                -- Full PayMongo API response
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CONSTRAINT fk_farmer_payout FOREIGN KEY (farmer_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_bank_account FOREIGN KEY (bank_account_id) REFERENCES farmer_bank_accounts(bank_account_id) ON DELETE RESTRICT
);

-- Create indexes for farmer_payouts
CREATE INDEX IF NOT EXISTS idx_farmer_payouts_farmer_id ON farmer_payouts(farmer_id);
CREATE INDEX IF NOT EXISTS idx_farmer_payouts_status ON farmer_payouts(payout_status);
CREATE INDEX IF NOT EXISTS idx_farmer_payouts_requested_at ON farmer_payouts(requested_at);
CREATE INDEX IF NOT EXISTS idx_farmer_payouts_paymongo_id ON farmer_payouts(paymongo_payout_id);

-- Enable RLS on farmer_payouts
ALTER TABLE farmer_payouts ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Farmers can view their own payouts
CREATE POLICY farmer_payouts_select ON farmer_payouts
  FOR SELECT
  USING (
    farmer_id = auth.uid() OR
    auth.role() = 'service_role' OR
    auth.role() = 'admin'
  );

-- RLS Policy: Farmers can insert their own payouts
CREATE POLICY farmer_payouts_insert ON farmer_payouts
  FOR INSERT
  WITH CHECK (farmer_id = auth.uid() OR auth.role() = 'service_role');

-- RLS Policy: Service role can update payouts (for webhook updates)
CREATE POLICY farmer_payouts_update ON farmer_payouts
  FOR UPDATE
  USING (auth.role() = 'service_role' OR auth.role() = 'admin')
  WITH CHECK (auth.role() = 'service_role' OR auth.role() = 'admin');

-- ============================================================================
-- Function: update_farmer_payouts_timestamp
-- Purpose: Automatically update the updated_at field
-- ============================================================================
CREATE OR REPLACE FUNCTION update_farmer_payouts_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for timestamp
DROP TRIGGER IF EXISTS farmer_payouts_timestamp ON farmer_payouts;
CREATE TRIGGER farmer_payouts_timestamp
  BEFORE UPDATE ON farmer_payouts
  FOR EACH ROW
  EXECUTE FUNCTION update_farmer_payouts_timestamp();

-- ============================================================================
-- Function: update_farmer_bank_accounts_timestamp
-- Purpose: Automatically update the updated_at field
-- ============================================================================
CREATE OR REPLACE FUNCTION update_farmer_bank_accounts_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for timestamp
DROP TRIGGER IF EXISTS farmer_bank_accounts_timestamp ON farmer_bank_accounts;
CREATE TRIGGER farmer_bank_accounts_timestamp
  BEFORE UPDATE ON farmer_bank_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_farmer_bank_accounts_timestamp();

-- ============================================================================
-- View: farmer_earnings_summary
-- Purpose: Get a summary of farmer earnings available for payout
-- ============================================================================
CREATE OR REPLACE VIEW farmer_earnings_summary AS
SELECT
  o.farmer_id,
  SUM(t.amount_php) FILTER (WHERE t.payment_status = 'confirmed' AND t.transaction_type = 'preorder') as preorder_earnings,
  SUM(t.amount_php) FILTER (WHERE t.payment_status = 'confirmed') as total_earnings,
  SUM(fp.amount_php) FILTER (WHERE fp.payout_status IN ('processing', 'completed')) as total_paid_out,
  COUNT(DISTINCT fp.payout_id) FILTER (WHERE fp.payout_status = 'pending') as pending_payouts
FROM orders o
LEFT JOIN transactions t ON o.order_id = t.order_id
LEFT JOIN farmer_payouts fp ON o.farmer_id = fp.farmer_id
GROUP BY o.farmer_id;

-- ============================================================================
-- Notes:
-- ============================================================================
-- 1. Run this migration in Supabase SQL Editor
-- 2. Bank account numbers should be encrypted before storage in production
-- 3. Implement row-level security in backend for sensitive data
-- 4. PayMongo webhook endpoint should trigger payout status updates
-- 5. Consider adding audit trail for compliance and reconciliation
