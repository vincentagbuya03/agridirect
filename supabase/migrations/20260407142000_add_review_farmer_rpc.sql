-- ========================================================================
-- AGRIDIRECT - ADMIN REVIEW SYSTEM
-- Adds the RPC for admins to approve or reject farmer registrations.
-- ========================================================================

CREATE OR REPLACE FUNCTION review_farmer_registration(
  p_registration_id uuid,
  p_admin_id uuid,
  p_status_id smallint,  -- e.g. 2 = approved, 3 = rejected
  p_review_notes text
) RETURNS json AS $$
DECLARE
  v_farmer_id uuid;
BEGIN
  -- 1. Update the specific registration attempt audit log
  UPDATE farmer_registrations SET
    registration_status_id = p_status_id,
    reviewed_by = p_admin_id,
    review_notes = p_review_notes,
    updated_at = now()
  WHERE registration_id = p_registration_id
  RETURNING farmer_id INTO v_farmer_id;

  -- 2. Sync the farmer's current live status
  UPDATE farmers SET
    registration_status_id = p_status_id,
    is_verified = CASE WHEN p_status_id = 2 THEN true ELSE false END,
    updated_at = now()
  WHERE farmer_id = v_farmer_id;

  RETURN json_build_object('success', true, 'farmer_id', v_farmer_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions to allowed roles
GRANT EXECUTE ON FUNCTION review_farmer_registration TO authenticated, service_role;
