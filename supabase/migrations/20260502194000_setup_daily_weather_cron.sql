-- Enable pg_cron extension for scheduling
create extension if not exists pg_cron with schema extensions;

-- ⚠️  IMPORTANT: Replace <YOUR_SERVICE_ROLE_KEY> below with your actual Supabase service role key
-- Find it in: Supabase Dashboard → Settings → API → Service Role Key
-- 
-- Schedule daily weather check at 12:50 UTC every day
select cron.schedule(
  'daily-farmer-weather-check',
  '50 12 * * *',
  $$
  select net.http_post(
    url := 'https://ywfppgarzyksacgbesme.supabase.co/functions/v1/daily-weather-check',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer <YOUR_SERVICE_ROLE_KEY>"}'::jsonb
  );
  $$
);

-- Verify the job was created:
-- SELECT * FROM cron.job WHERE jobname = 'daily-farmer-weather-check';
