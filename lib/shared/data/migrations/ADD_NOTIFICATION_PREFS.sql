-- Migration: Add Notification Preferences
-- Adds columns to the `users` table to track notification preferences for email, push, and promos.

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS email_alerts BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS push_alerts BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS promo_alerts BOOLEAN DEFAULT FALSE;
