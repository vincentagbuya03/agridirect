-- Migration: Remove farmer wallet infrastructure and enforce offline payments
-- Purpose: Apply wallet/payment cleanup on databases that already executed
-- 20260413120000_restrict_payment_methods_to_cod_and_cop.sql.
-- Created: April 13, 2026

-- ============================================================================
-- STEP 1: Keep only COD and COP active
-- ============================================================================

UPDATE payment_methods
SET
  is_active = CASE WHEN UPPER(code) IN ('COD', 'COP') THEN true ELSE false END,
  updated_at = now();

COMMENT ON TABLE payment_methods IS
'Lookup table for payment methods.
ACTIVE METHODS:
- COD = Cash on Delivery
- COP = Cash on Pickup
Online payment methods are preserved for historical references but marked inactive.';

-- ============================================================================
-- STEP 2: Drop online-payment RPCs and wallet tables
-- ============================================================================

DROP FUNCTION IF EXISTS process_order_payment_to_farmer_wallet(
  uuid,
  uuid,
  numeric,
  text,
  text,
  text
);

DROP FUNCTION IF EXISTS process_order_payment_to_farmer_wallet(
  p_order_id uuid,
  p_customer_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_transaction_reference text,
  p_notes text
);

DROP TABLE IF EXISTS wallet_transactions CASCADE;
DROP TABLE IF EXISTS farmer_wallets CASCADE;
DROP TABLE IF EXISTS wallet_transaction_types CASCADE;

COMMENT ON TABLE orders IS
'Orders support offline checkout only.
Allowed payment methods:
- COD = Cash on Delivery
- COP = Cash on Pickup';
