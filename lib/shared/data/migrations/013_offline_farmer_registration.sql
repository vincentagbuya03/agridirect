-- ============================================================================
-- Migration: Add offline-first support for farmer registration
-- ============================================================================
-- Purpose: Allow farmers to register and add products offline
-- Products will be linked to registrations when both sync
-- ============================================================================

-- Add offline tracking for farmer registrations
ALTER TABLE farmer_registrations
ADD COLUMN IF NOT EXISTS local_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS synced_at TIMESTAMPTZ;

-- Create index for offline lookups
CREATE INDEX IF NOT EXISTS idx_farmer_registrations_local_id
ON farmer_registrations(local_id) WHERE local_id IS NOT NULL;

-- Update RLS to allow pending farmers to add products locally
-- (Products will be visible only to the farmer until registration approved)
CREATE POLICY IF NOT EXISTS "Pending farmers can create products offline"
ON products FOR INSERT
WITH CHECK (
  -- Allow if user has a pending farmer registration OR is an approved farmer
  EXISTS (
    SELECT 1 FROM farmer_registrations
    WHERE user_id = auth.uid()
    AND status IN ('pending', 'approved')
  )
  OR
  EXISTS (
    SELECT 1 FROM farmer_profiles
    WHERE farmer_id = auth.uid()
  )
);

-- Products from pending farmers are only visible to themselves
CREATE POLICY IF NOT EXISTS "Users see their own pending products"
ON products FOR SELECT
USING (
  -- Public can see products from approved farmers
  EXISTS (
    SELECT 1 FROM farmer_profiles
    WHERE farmer_id = products.farmer_id
  )
  OR
  -- Farmers can see their own pending products
  farmer_id = auth.uid()
);

-- ============================================================================
-- This allows offline workflow:
-- 1. Submit farmer registration (saved locally if offline)
-- 2. Add products immediately (saved locally if offline)
-- 3. When online, registration syncs
-- 4. When approved, products become publicly visible
-- 5. If rejected, products remain visible only to farmer (can be edited/deleted)
-- ============================================================================
