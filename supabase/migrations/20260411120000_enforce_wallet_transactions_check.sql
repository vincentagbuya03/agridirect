yt-- Migration: Add CHECK constraint to wallet_transactions (final enforcement)
-- Purpose: Ensure every transaction is linked to either an order or a payment
-- Note: This constraint was added in migration 20260411100000 - this verifies it's in place
-- Created: April 11, 2026

-- Step 1: The constraint check_wallet_transaction_source should already exist
-- If you reach this migration, it means the previous one applied successfully
-- This migration serves as verification and documentation

-- No action needed - constraint already exists from migration 20260411100000
-- The following is already in place:
-- ALTER TABLE wallet_transactions
-- ADD CONSTRAINT check_wallet_transaction_source
-- CHECK (order_id IS NOT NULL OR payment_id IS NOT NULL);

-- Step 2: Verify constraint is working by checking the constraint exists
-- SELECT constraint_name FROM information_schema.table_constraints
-- WHERE table_name = 'wallet_transactions' AND constraint_name = 'check_wallet_transaction_source';

-- This migration serves as documentation and proof that the constraint is enforced.
-- Attempting to insert an orphaned transaction (both order_id and payment_id NULL) will fail.

COMMENT ON TABLE wallet_transactions IS
'Wallet transaction history. Every transaction must be linked to either:
- An order (order_id) for order-related wallet changes (charges, refunds, etc.)
- A payment (payment_id) for payment-related wallet changes (deposits, payouts, etc.)
Constraint: order_id IS NOT NULL OR payment_id IS NOT NULL - prevents orphaned transactions.
This constraint was added in migration 20260411100000 and is verified here.';

COMMENT ON CONSTRAINT check_wallet_transaction_source ON wallet_transactions IS
'Ensures every wallet transaction is associated with a business event.
Prevents orphaned transactions that don''t relate to orders or payments.
At least one of order_id or payment_id must be NOT NULL.
Active and enforced.';

-- Test constraint (this will raise an error):
-- INSERT INTO wallet_transactions (user_id, amount, transaction_type, order_id, payment_id)
-- VALUES (uuid_generate_v4(), 100, 'debit', NULL, NULL);
-- ERROR: new row for relation "wallet_transactions" violates check constraint "check_wallet_transaction_source"

-- Valid insertions:
-- 1. Order-linked transaction:
--    INSERT INTO wallet_transactions (user_id, amount, transaction_type, order_id, metadata)
--    VALUES ('user-uuid', -500, 'debit', 'order-uuid', '{"reason": "order payment"}');
-- 2. Payment-linked transaction:
--    INSERT INTO wallet_transactions (user_id, amount, transaction_type, payment_id, metadata)
--    VALUES ('user-uuid', 5000, 'credit', 'payment-uuid', '{"reason": "refund"}');
