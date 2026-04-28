-- Add article as a reportable content type so admin_articles can flow
-- through the same moderation pipeline as forum posts.

INSERT INTO public.content_types (
  content_type_id,
  code,
  description,
  is_active
)
VALUES (
  5,
  'article',
  'Admin-published article',
  true
)
ON CONFLICT (content_type_id) DO UPDATE
SET
  code = EXCLUDED.code,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active;
