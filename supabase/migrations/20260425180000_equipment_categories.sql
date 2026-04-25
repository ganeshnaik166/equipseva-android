-- Server-managed equipment_categories table.
--
-- Replaces the hardcoded `PartCategory` and `RepairEquipmentCategory` enums in
-- the Android app: the keys stay as known constants on the client (so old
-- builds keep working), but display name + sort order + is_active can be
-- curated server-side without an app release.
--
-- Scope splits the list into the buckets each surface uses:
--   'spare_part' → marketplace + Add Listing
--   'repair'     → repair-jobs feed + Engineer KYC categories
--   'both'       → shared (Sterilization, Imaging, Patient monitoring, etc.)

CREATE TABLE IF NOT EXISTS public.equipment_categories (
  key text PRIMARY KEY,
  display_name text NOT NULL,
  scope text NOT NULL,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT equipment_categories_scope_check
    CHECK (scope IN ('spare_part','repair','both'))
);

ALTER TABLE public.equipment_categories ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read active rows. Inactive rows hidden from the app.
DROP POLICY IF EXISTS equipment_categories_select_active ON public.equipment_categories;
CREATE POLICY equipment_categories_select_active
  ON public.equipment_categories
  FOR SELECT
  TO authenticated, anon
  USING (is_active = true);

-- Founders read everything (including disabled rows for the admin curator).
DROP POLICY IF EXISTS equipment_categories_select_all_for_founder ON public.equipment_categories;
CREATE POLICY equipment_categories_select_all_for_founder
  ON public.equipment_categories
  FOR SELECT
  TO authenticated
  USING (public.is_founder() = true);

-- No client INSERT/UPDATE/DELETE policies — admin RPCs below mutate as
-- SECURITY DEFINER.

-- Seed: union of PartCategory + RepairEquipmentCategory enums currently in
-- the Android app. Idempotent — re-running keeps existing rows untouched.
INSERT INTO public.equipment_categories (key, display_name, scope, sort_order) VALUES
  ('imaging_radiology',    'Imaging & radiology',    'both',       10),
  ('patient_monitoring',   'Patient monitoring',     'both',       20),
  ('life_support',         'Life support',           'both',       30),
  ('sterilization',        'Sterilization',          'both',       40),
  ('cardiology',           'Cardiology',             'both',       50),
  ('surgical',             'Surgical',               'repair',     60),
  ('laboratory',           'Laboratory',             'repair',     70),
  ('dental',               'Dental',                 'repair',     80),
  ('ophthalmology',        'Ophthalmology',          'repair',     90),
  ('physiotherapy',        'Physiotherapy',          'repair',    100),
  ('neonatal',             'Neonatal',               'repair',    110),
  ('hospital_furniture',   'Hospital furniture',     'repair',    120),
  ('dialysis',             'Dialysis',               'repair',    130),
  ('oncology',              'Oncology',              'repair',    140),
  ('ent',                  'ENT',                    'repair',    150),
  ('other',                'Other',                  'both',      999)
ON CONFLICT (key) DO NOTHING;

-- Admin RPCs (founder-only).

CREATE OR REPLACE FUNCTION public.admin_categories_list()
RETURNS TABLE (
  key text,
  display_name text,
  scope text,
  sort_order int,
  is_active boolean,
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
    SELECT c.key, c.display_name, c.scope, c.sort_order, c.is_active, c.updated_at
    FROM public.equipment_categories c
    ORDER BY c.scope, c.sort_order, c.display_name;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_categories_list() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_categories_upsert(
  p_key text,
  p_display_name text,
  p_scope text,
  p_sort_order int DEFAULT 100,
  p_is_active boolean DEFAULT true
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
  INSERT INTO public.equipment_categories (key, display_name, scope, sort_order, is_active, updated_at)
  VALUES (p_key, p_display_name, p_scope, coalesce(p_sort_order, 100), coalesce(p_is_active, true), now())
  ON CONFLICT (key) DO UPDATE
    SET display_name = excluded.display_name,
        scope        = excluded.scope,
        sort_order   = excluded.sort_order,
        is_active    = excluded.is_active,
        updated_at   = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_categories_upsert(text, text, text, int, boolean) TO authenticated;

-- Public-facing read RPC the app calls instead of selecting straight from the
-- table; lets us evolve the projection later without breaking clients.
CREATE OR REPLACE FUNCTION public.equipment_categories_for_scope(
  p_scope text
)
RETURNS TABLE (
  key text,
  display_name text,
  scope text,
  sort_order int
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT c.key, c.display_name, c.scope, c.sort_order
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
