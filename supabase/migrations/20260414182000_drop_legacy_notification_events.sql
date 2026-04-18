-- Migration: Drop legacy notification_events table
-- Purpose:
--   - Remove leftover table created by historical merged-schema migration
--   - Keep live DB aligned with canonical schema (notifications + notification_types only)

BEGIN;

DROP TABLE IF EXISTS notification_events CASCADE;

COMMIT;
