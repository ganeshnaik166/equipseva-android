-- S3: Real category images.
--
-- Extends equipment_categories with image_url + a bucket for the founder
-- curator to upload to. Marketplace + Parts surfaces render an AsyncImage
-- from this URL with a Material icon as the always-available fallback.

ALTER TABLE public.equipment_categories
  ADD COLUMN IF NOT EXISTS image_url text;

-- Recreate admin_categories_upsert to accept the image url. Keeps the old
-- 5-arg signature alive via DEFAULT NULL on the new param so any
-- in-flight clients keep compiling.
CREATE OR REPLACE FUNCTION public.admin_categories_upsert(
  p_key text,
  p_display_name text,
  p_scope text,
  p_sort_order int DEFAULT 100,
  p_is_active boolean DEFAULT true,
  p_image_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  IF p_scope NOT IN ('spare_part','repair','both') THEN
    RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.equipment_categories (key, display_name, scope, sort_order, is_active, image_url, updated_at)
  VALUES (p_key, p_display_name, p_scope, coalesce(p_sort_order, 100), coalesce(p_is_active, true), p_image_url, now())
  ON CONFLICT (key) DO UPDATE
    SET display_name = excluded.display_name,
        scope        = excluded.scope,
        sort_order   = excluded.sort_order,
        is_active    = excluded.is_active,
        image_url    = COALESCE(excluded.image_url, public.equipment_categories.image_url),
        updated_at   = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_categories_upsert(text, text, text, int, boolean, text) TO authenticated;

-- Refresh equipment_categories_for_scope to include image_url.
CREATE OR REPLACE FUNCTION public.equipment_categories_for_scope(
  p_scope text
)
RETURNS TABLE (
  key text,
  display_name text,
  scope text,
  sort_order int,
  image_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT c.key, c.display_name, c.scope, c.sort_order, c.image_url
  FROM public.equipment_categories c
  WHERE c.is_active = true
    AND (
      p_scope IS NULL
      OR c.scope = p_scope
      OR c.scope = 'both'
    )
  ORDER BY c.sort_order, c.display_name;
$$;
GRANT EXECUTE ON FUNCTION public.equipment_categories_for_scope(text) TO authenticated, anon;

-- Refresh admin_categories_list to include image_url.
CREATE OR REPLACE FUNCTION public.admin_categories_list()
RETURNS TABLE (
  key text,
  display_name text,
  scope text,
  sort_order int,
  is_active boolean,
  image_url text,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT c.key, c.display_name, c.scope, c.sort_order, c.is_active, c.image_url, c.updated_at
    FROM public.equipment_categories c
    ORDER BY c.scope, c.sort_order, c.display_name;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_categories_list() TO authenticated;

-- category-images bucket: public read, founder-only write via service role.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('category-images', 'category-images', true, 5242880,
        ARRAY['image/jpeg','image/jpg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Anyone can read; only founders can write (insert/update/delete via RLS).
DROP POLICY IF EXISTS category_images_public_read ON storage.objects;
CREATE POLICY category_images_public_read
  ON storage.objects
  FOR SELECT
  TO authenticated, anon
  USING (bucket_id = 'category-images');

DROP POLICY IF EXISTS category_images_founder_write ON storage.objects;
CREATE POLICY category_images_founder_write
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'category-images' AND public.is_founder());

DROP POLICY IF EXISTS category_images_founder_update ON storage.objects;
CREATE POLICY category_images_founder_update
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'category-images' AND public.is_founder())
  WITH CHECK (bucket_id = 'category-images' AND public.is_founder());

DROP POLICY IF EXISTS category_images_founder_delete ON storage.objects;
CREATE POLICY category_images_founder_delete
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'category-images' AND public.is_founder());
