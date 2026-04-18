-- Migration: Add CHECK constraint to wallet_transactions
-- Purpose: Ensure every transaction has at least order_id OR payment_id (no orphaned transactions)
-- Safety: Prevents invalid state where transaction is linked to nothing
-- Created: April 11, 2026

-- Step 1: Check and remove any orphaned transactions first (optional cleanup)
-- These would be transactions with both order_id and payment_id as NULL
-- SELECT COUNT(*) FROM wallet_transactions WHERE order_id IS NULL AND payment_id IS NULL;
-- DELETE FROM wallet_transactions WHERE order_id IS NULL AND payment_id IS NULL;

-- Step 2: Add the CHECK constraint
ALTER TABLE wallet_transactions
ADD CONSTRAINT check_wallet_transaction_source
CHECK (order_id IS NOT NULL OR payment_id IS NOT NULL);

COMMENT ON CONSTRAINT check_wallet_transaction_source ON wallet_transactions IS
'Ensures every wallet transaction is linked to either an order or a payment.
Prevents orphaned transactions that don''t relate to any actual business event.';

-- Step 3: Update table comment
COMMENT ON TABLE wallet_transactions IS
'Wallet transaction history. Every transaction must be linked to either:
- An order (order_id) for order-related wallet changes
- A payment (payment_id) for payment-related wallet changes
Constraint: order_id IS NOT NULL OR payment_id IS NOT NULL';

-- Queries to verify constraint works:
-- 1. Try to insert invalid transaction (should fail):
--    INSERT INTO wallet_transactions (user_id, amount, transaction_type, order_id, payment_id)
--    VALUES (uuid_generate_v4(), 100, 'debit', NULL, NULL);
--    -- Should raise error: new row for relation "wallet_transactions" violates check constraint
-- 2. View valid transactions:
--    SELECT wt.*, o.order_number, p.payment_id
--    FROM wallet_transactions wt
--    LEFT JOIN orders o ON wt.order_id = o.order_id
--    LEFT JOIN payments p ON wt.payment_id = p.id
--    LIMIT 10;
-- 3. Find any transactions with both order and payment (dual-linked):
--    SELECT COUNT(*) FROM wallet_transactions WHERE order_id IS NOT NULL AND payment_id IS NOT NULL;

-- Example valid insertions:
-- 1. Order-related transaction:
--    INSERT INTO wallet_transactions (user_id, amount, transaction_type, order_id, metadata)
--    VALUES (user_uuid, -500, 'debit', order_uuid, '{"reason": "order 123"}');
-- 2. Payment-related transaction:
--    INSERT INTO wallet_transactions (user_id, amount, transaction_type, payment_id, metadata)
--    VALUES (user_uuid, 5000, 'credit', payment_uuid, '{"reason": "payment", "refund": false}');

-- Audit trail:
-- - Previously: wallet_transactions could have orphaned transactions
-- - Now: All transactions must relate to business events (orders or payments)
-- - Impact: Improves data consistency and audit trail quality

-- Rollback note:
-- ALTER TABLE wallet_transactions DROP CONSTRAINT check_wallet_transaction_source;
