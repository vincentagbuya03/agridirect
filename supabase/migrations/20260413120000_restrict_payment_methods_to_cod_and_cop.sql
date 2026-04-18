-- Migration: Remove online payment and farmer wallet infrastructure
-- Purpose: Restrict active payment methods to COD/COP, remove wallet tables,
-- and drop online-payment RPCs that no longer match the product flow.
-- Created: April 13, 2026

-- ============================================================================
-- STEP 1: Normalize or create COD and COP payment methods
-- ============================================================================

DO $$
DECLARE
  v_cod_id SMALLINT;
  v_cop_id SMALLINT;
  v_next_id SMALLINT;
BEGIN
  SELECT payment_method_id
  INTO v_cod_id
  FROM payment_methods
  WHERE UPPER(code) = 'COD'
  ORDER BY payment_method_id
  LIMIT 1;

  IF v_cod_id IS NULL THEN
    SELECT COALESCE(MAX(payment_method_id), 0) + 1
    INTO v_next_id
    FROM payment_methods;

    INSERT INTO payment_methods (
      payment_method_id,
      code,
      description,
      is_active,
      created_at,
      updated_at
    )
    VALUES (
      v_next_id,
      'COD',
      'Cash on Delivery',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE payment_methods
    SET
      code = 'COD',
      description = 'Cash on Delivery',
      is_active = true,
      updated_at = now()
    WHERE payment_method_id = v_cod_id;
  END IF;

  SELECT payment_method_id
  INTO v_cop_id
  FROM payment_methods
  WHERE UPPER(code) = 'COP'
  ORDER BY payment_method_id
  LIMIT 1;

  IF v_cop_id IS NULL THEN
    SELECT COALESCE(MAX(payment_method_id), 0) + 1
    INTO v_next_id
    FROM payment_methods;

    INSERT INTO payment_methods (
      payment_method_id,
      code,
      description,
      is_active,
      created_at,
      updated_at
    )
    VALUES (
      v_next_id,
      'COP',
      'Cash on Pickup',
      true,
      now(),
      now()
    );
  ELSE
    UPDATE payment_methods
    SET
      code = 'COP',
      description = 'Cash on Pickup',
      is_active = true,
      updated_at = now()
    WHERE payment_method_id = v_cop_id;
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Deactivate all other payment methods
-- ============================================================================

UPDATE payment_methods
SET
  is_active = false,
  updated_at = now()
WHERE UPPER(code) NOT IN ('COD', 'COP');

-- ============================================================================
-- STEP 3: Documentation
-- ============================================================================

COMMENT ON TABLE payment_methods IS
'Lookup table for payment methods.
ACTIVE METHODS:
- COD = Cash on Delivery
- COP = Cash on Pickup
Online payment methods are preserved for historical references but marked inactive.';

-- ============================================================================
-- STEP 4: Drop farmer wallet infrastructure and online-payment RPCs
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

-- Verification query:
-- SELECT payment_method_id, code, description, is_active
-- FROM payment_methods
-- ORDER BY payment_method_id;
