-- ============================================================================
-- PAYMENT SCHEMA - GCash/PayMaya → Blockchain Bridge
-- ============================================================================

-- Payment method enum
CREATE TYPE payment_method AS ENUM (
    'gcash',
    'paymaya',
    'bank_transfer',
    'usdc_polygon'
);

-- Payment status enum
CREATE TYPE payment_status AS ENUM (
    'pending',           -- Awaiting payment
    'processing',        -- Payment received, converting to crypto
    'confirmed',         -- Funds in escrow contract
    'released',          -- Delivered, farmer paid
    'refunded',          -- Cancelled/refund issued
    'failed'             -- Payment failed
);

-- ============================================================================
-- TRANSACTIONS TABLE - Track all payments
-- ============================================================================
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,

    -- Payment details
    amount_php DECIMAL(10, 2) NOT NULL,           -- Amount in Philippine Pesos
    amount_usdc DECIMAL(10, 2),                   -- Converted to USDC
    payment_method payment_method NOT NULL,
    payment_status payment_status DEFAULT 'pending',

    -- Reference tracking
    payment_reference TEXT,                       -- GCash/PayMaya reference
    transaction_hash TEXT,                        -- Blockchain tx hash
    escrow_contract_id TEXT,                      -- Smart contract ID

    -- Payment gateway records
    gateway_response JSONB,                       -- Full gateway response

    -- Farmer wallet
    farmer_wallet_address TEXT,                   -- Polygon wallet address
    farmer_wallet_public_key TEXT,                -- Encrypted wallet key

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMPTZ,                          -- When payment confirmed
    converted_to_crypto_at TIMESTAMPTZ,           -- When swapped to USDC
    released_to_farmer_at TIMESTAMPTZ,            -- When escrow released
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transactions_order_id ON transactions(order_id);
CREATE INDEX idx_transactions_status ON transactions(payment_status);
CREATE INDEX idx_transactions_farmer_wallet ON transactions(farmer_wallet_address);
CREATE INDEX idx_transactions_tx_hash ON transactions(transaction_hash);

-- ============================================================================
-- FARMER WALLETS TABLE - Store farmer blockchain addresses
-- ============================================================================
CREATE TABLE IF NOT EXISTS farmer_wallets (
    wallet_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,

    -- Wallet details
    wallet_address TEXT NOT NULL UNIQUE,          -- Polygon address
    network TEXT DEFAULT 'polygon',               -- blockchain network
    wallet_type TEXT DEFAULT 'metamask',          -- metamask, magic.link, etc

    -- Security
    wallet_encrypted BOOLEAN DEFAULT true,
    verified BOOLEAN DEFAULT false,

    -- Farmer preferences
    auto_payout_enabled BOOLEAN DEFAULT true,
    auto_swap_to_php BOOLEAN DEFAULT false,       -- Auto-convert USDC to PHP
    preferred_exchange_rate_buffer DECIMAL(5, 2) DEFAULT 2.0, -- 2% buffer

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_farmer_wallets_farmer_id ON farmer_wallets(farmer_id);
CREATE INDEX idx_farmer_wallets_verified ON farmer_wallets(verified);

-- ============================================================================
-- ESCROW CONTRACTS TABLE - Track smart contract interactions
-- ============================================================================
CREATE TABLE IF NOT EXISTS escrow_contracts (
    contract_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES transactions(transaction_id),

    -- Smart contract details
    contract_address TEXT NOT NULL,               -- Deployed contract address
    contract_network TEXT DEFAULT 'polygon',
    contract_chain_id INT DEFAULT 137,            -- Polygon chain ID

    -- Escrow state
    buyer_wallet TEXT NOT NULL,                   -- Buyer's wallet
    seller_wallet TEXT NOT NULL,                  -- Farmer's wallet
    amount_usdc DECIMAL(10, 2) NOT NULL,

    -- Status tracking
    status TEXT DEFAULT 'funded',                 -- funded, delivered, released, disputed
    delivery_confirmed BOOLEAN DEFAULT false,
    delivery_confirmed_at TIMESTAMPTZ,
    dispute_reason TEXT,

    -- Blockchain metadata
    deployment_tx_hash TEXT,
    release_tx_hash TEXT,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_escrow_contracts_order_id ON escrow_contracts(order_id);
CREATE INDEX idx_escrow_contracts_status ON escrow_contracts(status);
CREATE INDEX idx_escrow_contracts_contract_address ON escrow_contracts(contract_address);

-- ============================================================================
-- PAYOUT HISTORY TABLE - Track farmer payouts
-- ============================================================================
CREATE TABLE IF NOT EXISTS payouts (
    payout_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES farmers(farmer_id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(transaction_id),

    -- Payout details
    amount_usdc DECIMAL(10, 2) NOT NULL,
    amount_php DECIMAL(10, 2),                    -- Converted to PHP if swapped
    payout_method TEXT, -- 'usdc_wallet', 'php_transfer', 'gcash'

    -- Exchange rate
    exchange_rate DECIMAL(10, 4),                 -- USDC/PHP rate at time of payout

    -- Status
    status TEXT DEFAULT 'pending',                -- pending, completed, failed
    tx_hash TEXT,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payouts_farmer_id ON payouts(farmer_id);
CREATE INDEX idx_payouts_status ON payouts(status);

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Customers can only view their own transactions
CREATE POLICY transactions_customer_access ON transactions
    FOR SELECT USING (
        order_id IN (
            SELECT order_id FROM orders WHERE customer_id = auth.uid()
        )
    );

-- Farmers can view transactions for their orders
CREATE POLICY transactions_farmer_access ON transactions
    FOR SELECT USING (
        order_id IN (
            SELECT order_id FROM orders WHERE farmer_id = auth.uid()
        )
    );

-- Farmers manage their own wallets
CREATE POLICY farmer_wallets_own_access ON farmer_wallets
    FOR ALL USING (farmer_id = auth.uid());

-- Admin can view all
CREATE POLICY transactions_admin_access ON transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admins WHERE admin_id = auth.uid()
        )
    );
