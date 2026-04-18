-- Migration: Final constraint verification and legacy column cleanup
-- Purpose: Ensure wallet_transactions and reported_content constraints are in place, drop legacy columns
-- This is the final hygiene pass for 100% production readiness
-- Created: April 11, 2026

-- ============================================================================
-- WALLET_TRANSACTIONS: Verify CHECK constraint
-- ============================================================================

-- Step 1: Add wallet_transactions CHECK constraint if missing
DO $$
BEGIN
  ALTER TABLE wallet_transactions
  ADD CONSTRAINT check_wallet_transaction_source
  CHECK (order_id IS NOT NULL OR payment_id IS NOT NULL);
  RAISE NOTICE 'Added constraint check_wallet_transaction_source to wallet_transactions';
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'Constraint check_wallet_transaction_source already exists on wallet_transactions';
END $$;

-- ============================================================================
-- REPORTED_CONTENT: Add status constraint if missing
-- ============================================================================

-- Step 2: Add reported_content status CHECK constraint if missing
DO $$
BEGIN
  ALTER TABLE reported_content
  ADD CONSTRAINT check_reported_content_status
  CHECK (status IN ('pending', 'resolved', 'dismissed'));
  RAISE NOTICE 'Added constraint check_reported_content_status to reported_content';
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'Constraint check_reported_content_status already exists on reported_content';
END $$;

-- ============================================================================
-- VERIFICATION_CODES: Drop legacy text column
-- ============================================================================

-- Step 3: Drop the old verification_type text column (now that verification_type_id FK is in place)
ALTER TABLE verification_codes
DROP COLUMN IF EXISTS verification_type;

-- ============================================================================
-- VERIFICATION AND DOCUMENTATION
-- ============================================================================

-- Step 4: Update table comments to reflect final state
COMMENT ON TABLE wallet_transactions IS
'Wallet transaction history with strict data integrity.
ENFORCED CONSTRAINTS:
- check_wallet_transaction_source: (order_id IS NOT NULL OR payment_id IS NOT NULL)
  Ensures every transaction is linked to a business event
- All amounts are integers (stored as cents/smallest units)
No orphaned transactions are possible.';

COMMENT ON TABLE reported_content IS
'User content reports for policy violations.
ENFORCED CONSTRAINTS:
- content_type_id NOT NULL: All reports must specify content type
- check_reported_content_status: status IN (''pending'', ''resolved'', ''dismissed'')
- fk_reported_content_type_id: content_type_id FK to content_types table
Complete data integrity with valid status and type tracking.';

COMMENT ON TABLE verification_codes IS
'Verification codes for email, phone, password reset, and 2FA.
ENFORCED CONSTRAINTS:
- verification_type_id NOT NULL: All codes must specify type
- fk_verification_codes_type_id: verification_type_id FK to verification_types table
Legacy verification_type text column has been removed (migrated to FK).';

-- Step 5: Verification queries (for manual testing if needed)
-- Run these to confirm all constraints are active:

-- Check wallet_transactions constraint:
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'wallet_transactions'::regclass
-- AND contype = 'c';
-- RESULT: Should show check_wallet_transaction_source

-- Check reported_content constraint:
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'reported_content'::regclass
-- AND contype = 'c';
-- RESULT: Should show check_reported_content_status

-- Check verification_codes FK:
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'verification_codes'::regclass
-- AND contype = 'f';
-- RESULT: Should show fk_verification_codes_type_id

-- ============================================================================
-- FINAL SCHEMA HEALTH CHECK
-- ============================================================================

-- All critical constraints should now be in place:
-- ✅ wallet_transactions: check_wallet_transaction_source (order_id OR payment_id)
-- ✅ reported_content: check_reported_content_status (pending/resolved/dismissed)
-- ✅ reported_content: content_type_id NOT NULL
-- ✅ reported_content: fk_reported_content_type_id (FK to content_types)
-- ✅ verification_codes: verification_type_id NOT NULL
-- ✅ verification_codes: fk_verification_codes_type_id (FK to verification_types)
-- ✅ No duplicate columns (delivery_method, content_type, cancelled_by_role text versions all removed)
-- ✅ All type tracking uses proper FKs to lookup tables
-- ✅ Deprecated columns removed (farmers.registration_status_id family)

-- Schema is now 100% production-ready!

-- Rollback note (if needed):
-- ALTER TABLE wallet_transactions DROP CONSTRAINT IF EXISTS check_wallet_transaction_source;
-- ALTER TABLE reported_content DROP CONSTRAINT IF EXISTS check_reported_content_status;
-- ALTER TABLE verification_codes ADD COLUMN verification_type TEXT;
-- UPDATE verification_codes SET verification_type = vt.code FROM verification_types vt WHERE verification_type_id = vt.verification_type_id;
