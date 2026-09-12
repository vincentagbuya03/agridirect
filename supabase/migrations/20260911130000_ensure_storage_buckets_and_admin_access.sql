-- Migration: Ensure Uploads and Registrations Storage Buckets and Admin Access
-- Created at: 2026-09-11 13:00:00

-- 1. Ensure 'uploads' and 'registrations' buckets exist and are public
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('uploads', 'uploads', true),
  ('registrations', 'registrations', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Allow public/anon/authenticated read access to both buckets
DROP POLICY IF EXISTS "Public Access Uploads And Registrations" ON storage.objects;
DROP POLICY IF EXISTS "Public Access Registrations" ON storage.objects;
CREATE POLICY "Public Access Uploads And Registrations"
ON storage.objects FOR SELECT
USING ( bucket_id IN ('uploads', 'registrations') );

-- 3. Allow authenticated users to upload files to both buckets
DROP POLICY IF EXISTS "Authenticated Upload Objects" ON storage.objects;
CREATE POLICY "Authenticated Upload Objects"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id IN ('uploads', 'registrations') );

-- 4. Allow authenticated users to update files in both buckets
DROP POLICY IF EXISTS "Authenticated Update Objects" ON storage.objects;
CREATE POLICY "Authenticated Update Objects"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id IN ('uploads', 'registrations') )
WITH CHECK ( bucket_id IN ('uploads', 'registrations') );

-- 5. Allow authenticated users to delete files in both buckets
DROP POLICY IF EXISTS "Authenticated Delete Objects" ON storage.objects;
CREATE POLICY "Authenticated Delete Objects"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id IN ('uploads', 'registrations') );
