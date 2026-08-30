-- Enable Supabase Realtime publication for orders and related tables
BEGIN;

-- Add orders to realtime publication if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
  END IF;
END $$;

COMMIT;
