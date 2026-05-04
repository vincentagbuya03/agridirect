-- Enable pg_cron and pg_net extensions (needed for scheduled Edge Function calls)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Grant usage so cron jobs can call pg_net
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- Schedule the daily-weather-check Edge Function to run every 6 hours
-- (6:00 AM, 12:00 PM, 6:00 PM, 12:00 AM UTC)
-- This ensures farmers get timely weather notifications throughout the day.
SELECT cron.schedule(
  'daily-weather-check',
  '0 */6 * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url') || '/functions/v1/daily-weather-check',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_service_role_key')
    ),
    body := '{"source": "pg_cron"}'::jsonb
  );
  $$
);
