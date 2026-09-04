-- Add reviewed_at column to farmer_registrations to track exact approval timestamp
ALTER TABLE public.farmer_registrations
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
