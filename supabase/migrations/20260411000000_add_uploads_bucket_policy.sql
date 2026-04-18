-- Create RLS policy for uploads bucket - Allow authenticated users to insert files
CREATE POLICY "Allow authenticated users to insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'uploads');

-- Allow authenticated users to read their own files
CREATE POLICY "Allow authenticated users to read own files"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'uploads');

-- Allow authenticated users to update their own files
CREATE POLICY "Allow authenticated users to update own files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'uploads');
