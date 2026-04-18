-- Migration: Cleanup legacy lookup and duplicate merged tables
-- Purpose:
--   - Remove obsolete merged lookup table
--   - Remove duplicate legacy tables replaced by split schema
-- Notes:
--   - Data should already be backfilled by 20260414110000_restore_split_tables_from_merged_schema.sql

BEGIN;

-- Remove any leftover foreign keys that still point to lookup_values.
ALTER TABLE farmers
	DROP CONSTRAINT IF EXISTS fk_farmers_registration_status;

ALTER TABLE orders
	DROP CONSTRAINT IF EXISTS fk_orders_status_lookup,
	DROP CONSTRAINT IF EXISTS fk_orders_payment_method_lookup,
	DROP CONSTRAINT IF EXISTS fk_orders_delivery_method_lookup,
	DROP CONSTRAINT IF EXISTS fk_orders_cancel_role_lookup;

ALTER TABLE payments
	DROP CONSTRAINT IF EXISTS fk_payments_status_lookup,
	DROP CONSTRAINT IF EXISTS fk_payments_method_lookup;

ALTER TABLE order_status_logs
	DROP CONSTRAINT IF EXISTS fk_order_status_logs_lookup;

ALTER TABLE verification_codes
	DROP CONSTRAINT IF EXISTS fk_verification_codes_lookup;

ALTER TABLE reported_content
	DROP CONSTRAINT IF EXISTS fk_reported_content_lookup;

ALTER TABLE notification_events
	DROP CONSTRAINT IF EXISTS fk_notification_events_type,
	DROP CONSTRAINT IF EXISTS fk_notification_events_lookup,
	DROP CONSTRAINT IF EXISTS notification_events_notification_type_fkey;

-- Ensure notification_events continues to enforce type integrity via split table.
ALTER TABLE notification_events
	DROP CONSTRAINT IF EXISTS fk_notification_events_type_id,
	ADD CONSTRAINT fk_notification_events_type_id
	FOREIGN KEY (notification_type_id)
	REFERENCES notification_types(notification_type_id);

-- Remove legacy generic lookup table no longer used by live schema.
DROP TABLE IF EXISTS lookup_values;

-- Remove legacy merged domain tables replaced by split tables.
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS forum_likes;
DROP TABLE IF EXISTS farmer_produce;
DROP TABLE IF EXISTS media_attachments;

COMMIT;
