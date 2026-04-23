-- Migration: Setup Uploads Storage Bucket
-- Created at: 2026-04-22 00:41:00

-- 1. Create the 'uploads' bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('uploads', 'uploads', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow public access to read files in the 'uploads' bucket
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'uploads' );

-- 3. Allow authenticated users (admins/farmers) to upload files to the 'uploads' bucket
DROP POLICY IF EXISTS "Authenticated Upload" ON storage.objects;
CREATE POLICY "Authenticated Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'uploads' );

-- 4. Allow authenticated users to update/delete their own uploads
DROP POLICY IF EXISTS "Authenticated Update Own" ON storage.objects;
CREATE POLICY "Authenticated Update Own"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'uploads' AND (auth.uid() = owner) )
WITH CHECK ( bucket_id = 'uploads' AND (auth.uid() = owner) );

DROP POLICY IF EXISTS "Authenticated Delete Own" ON storage.objects;
CREATE POLICY "Authenticated Delete Own"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'uploads' AND (auth.uid() = owner) );
