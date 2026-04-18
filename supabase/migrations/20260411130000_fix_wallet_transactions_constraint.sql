-- Migration: Verify and enforce wallet_transactions CHECK constraint
-- Purpose: Ensure order_id IS NOT NULL OR payment_id IS NOT NULL
-- This is the definitive version with error handling for idempotency
-- Created: April 11, 2026

-- Step 1: Add the CHECK constraint if it doesn't exist
-- Using CREATE CONSTRAINT approach for Postgres 14+
DO $$
BEGIN
  -- Try to add the constraint
  ALTER TABLE wallet_transactions
  ADD CONSTRAINT check_wallet_transaction_source
  CHECK (order_id IS NOT NULL OR payment_id IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN
  -- Constraint already exists, that's fine
  NULL;
END $$;

-- Step 2: Verify no orphaned transactions exist (they shouldn't)
-- This is a safety check - should return 0 rows
-- SELECT COUNT(*) as orphaned_count FROM wallet_transactions 
-- WHERE order_id IS NULL AND payment_id IS NULL;

-- Step 3: Test that the constraint works
-- This query would fail if constraint is active:
-- INSERT INTO wallet_transactions (user_id, amount, transaction_type, order_id, payment_id, created_at)
-- VALUES (uuid_generate_v4(), 100, 'debit', NULL, NULL, now())
-- EXPECT ERROR: new row for relation "wallet_transactions" violates check constraint

COMMENT ON TABLE wallet_transactions IS
'Wallet transaction history with strict data integrity.
Every transaction MUST be linked to either an order OR a payment (or both).
Constraint: check_wallet_transaction_source enforces (order_id IS NOT NULL OR payment_id IS NOT NULL)
This prevents orphaned transactions that don''t relate to any business event.';

-- Rollback note:
-- ALTER TABLE wallet_transactions DROP CONSTRAINT IF EXISTS check_wallet_transaction_source;
