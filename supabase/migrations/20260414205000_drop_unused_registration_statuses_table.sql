-- Drop unused registration_statuses lookup table
-- farmer_registrations now uses hardcoded text status instead of foreign key
-- No tables or code reference this table anymore

DROP TABLE IF EXISTS registration_statuses CASCADE;
