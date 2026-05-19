-- Round 415 — cap free-form text on equipment_categories + RPC.
--
-- Background:
--   equipment_categories (created 20260425180000) and admin_categories_upsert
--   (last updated 20260426020000) accept p_key + p_display_name with no
--   length validation server-side. The Compose UI also takes uncapped text.
--   The table is admin-only (founder is_founder() gate), so risk is low —
--   but it's the only category-feed surface that lacks a length cap.
--
-- Fix:
--   1. CHECK constraints: key <= 50 chars, display_name <= 200 chars.
--   2. Explicit length validation in admin_categories_upsert so direct-RPC
--      callers get a readable 22001 instead of a 23514 CHECK violation.
--
-- Lineage: r406 (dispute_resolution_note 500), r724 (content_reports.notes),
--          r729 (user_addresses), r734 (engineers.bio), r736 (KYC fields).

ALTER TABLE public.equipment_categories
  DROP CONSTRAINT IF EXISTS equipment_categories_key_len_chk;
ALTER TABLE public.equipment_categories
  ADD CONSTRAINT equipment_categories_key_len_chk
  CHECK (length(key) <= 50);

ALTER TABLE public.equipment_categories
  DROP CONSTRAINT IF EXISTS equipment_categories_display_name_len_chk;
ALTER TABLE public.equipment_categories
  ADD CONSTRAINT equipment_categories_display_name_len_chk
  CHECK (length(display_name) <= 200);

-- Rebuild admin_categories_upsert with explicit length guards.
-- Body otherwise identical to 20260426020000_category_images.sql.
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
  -- Round 415: explicit length guards so direct RPC callers get a clear
  -- 22001 instead of a CHECK violation.
  IF p_key IS NULL OR length(trim(p_key)) = 0 THEN
    RAISE EXCEPTION 'key required' USING ERRCODE='22023';
  END IF;
  IF length(p_key) > 50 THEN
    RAISE EXCEPTION 'key too long (max 50 chars)' USING ERRCODE='22001';
  END IF;
  IF p_display_name IS NULL OR length(trim(p_display_name)) = 0 THEN
    RAISE EXCEPTION 'display_name required' USING ERRCODE='22023';
  END IF;
  IF length(p_display_name) > 200 THEN
    RAISE EXCEPTION 'display_name too long (max 200 chars)' USING ERRCODE='22001';
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
