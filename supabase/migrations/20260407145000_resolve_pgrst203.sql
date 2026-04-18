-- ========================================================================
-- AGRIDIRECT - FINAL RPC CLEANUP
-- Drops the old string-based birth_date function that is confusing PostgREST
-- ========================================================================

-- Drop the function that expects birth_date as text
DROP FUNCTION IF EXISTS submit_complete_farmer_registration(uuid, text, integer, text, text, text, text, text, text, jsonb, jsonb, jsonb);

-- Also drop other possible permutations just to be absolutely sure we have a clean slate!

-- Drop the 13-argument function again, just in case
DROP FUNCTION IF EXISTS submit_complete_farmer_registration(uuid, date, integer, text, text, text, text, text, text, text, jsonb, jsonb, jsonb);

-- The function we WANT is already in the database and was created by the previous migration: 
-- submit_complete_farmer_registration(uuid, date, integer, text, text, text, text, text, text, jsonb, jsonb, jsonb)
-- Because we only drop the text version here, the single correct date version remains, resolving the PGRST203 Exception!
