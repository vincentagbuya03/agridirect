-- Migration: Clean up farmers.image_url where KYC face selfie was inadvertently set as farm cover banner photo
BEGIN;

UPDATE public.farmers
SET image_url = NULL
WHERE image_url IS NOT NULL
  AND (
    image_url = face_photo_path
    OR image_url LIKE '%face_photo%'
    OR image_url LIKE '%selfie%'
  );

COMMIT;
