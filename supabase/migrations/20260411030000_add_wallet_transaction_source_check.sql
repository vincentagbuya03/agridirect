-- Migration: Add CHECK constraint on wallet_transactions
-- Purpose: Ensure data integrity - at least one of order_id or payment_id must be NOT NULL
-- This prevents orphaned transactions without a source
-- Created: April 11, 2026

-- Step 1: Add CHECK constraint to wallet_transactions
-- Ensures a transaction is linked to either an order or a payment (or both)
ALTER TABLE wallet_transactions
ADD CONSTRAINT check_wallet_transaction_has_source
CHECK (order_id IS NOT NULL OR payment_id IS NOT NULL);

COMMENT ON CONSTRAINT check_wallet_transaction_has_source ON wallet_transactions IS
'Ensures every wallet transaction is linked to either an order or a payment (or both).
Prevents orphaned transactions without a source.';

-- Step 2: Verify no existing orphaned records
-- If this query returns rows, those records violate the constraint
-- They must be cleaned up before the constraint can be applied successfully
SELECT COUNT(*) AS orphaned_transactions
FROM wallet_transactions
WHERE order_id IS NULL AND payment_id IS NULL;

-- If orphaned records exist, either:
-- A) Set order_id to a valid order if the transaction belongs to an order
-- B) Set payment_id to a valid payment if the transaction belongs to a payment
-- C) Delete the transaction if it's invalid
-- DELETE FROM wallet_transactions WHERE order_id IS NULL AND payment_id IS NULL;

-- Migration guide:
-- Valid scenarios:
-- INSERT INTO wallet_transactions (wallet_id, order_id, wallet_transaction_type_id, amount, description)
--   VALUES (..., '123e4567-e89b-12d3-a456-426614174000', ..., ...);  -- order_id only
-- INSERT INTO wallet_transactions (wallet_id, payment_id, wallet_transaction_type_id, amount, description)
--   VALUES (..., '223e4567-e89b-12d3-a456-426614174000', ..., ...);  -- payment_id only
-- INSERT INTO wallet_transactions (wallet_id, order_id, payment_id, wallet_transaction_type_id, amount, description)
--   VALUES (..., '123e4567...', '223e4567...', ..., ...);  -- both

-- Invalid scenario (will FAIL):
-- INSERT INTO wallet_transactions (wallet_id, wallet_transaction_type_id, amount)
--   VALUES (..., ..., 100);  -- ERROR: violates check constraint

-- Rollback note:
-- ALTER TABLE wallet_transactions DROP CONSTRAINT check_wallet_transaction_has_source;
