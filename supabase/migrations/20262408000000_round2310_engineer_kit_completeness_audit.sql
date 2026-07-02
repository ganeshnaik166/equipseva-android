BEGIN;

-- ============================================================================
-- r2310 — Engineer kit-completeness audit
-- Random spot-checks that field engineers carry all required kit items.
-- Tracks missing items and replacement cost so finance can recover from
-- engineer payouts and ops can spot chronic offenders.
-- ============================================================================

-- ---- Table 1: required kit catalog -----------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_kit_required_items_r2310 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_code       text NOT NULL UNIQUE,
  item_name       text NOT NULL,
  category        text NOT NULL CHECK (category IN ('tool','consumable','safety','document','spare')),
  is_mandatory    boolean NOT NULL DEFAULT true,
  replacement_cost_rupees integer NOT NULL DEFAULT 0 CHECK (replacement_cost_rupees >= 0),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_ekri_r2310_cat
  ON public.engineer_kit_required_items_r2310 (category);

ALTER TABLE public.engineer_kit_required_items_r2310 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ekri_r2310_founder_all ON public.engineer_kit_required_items_r2310;
CREATE POLICY ekri_r2310_founder_all
  ON public.engineer_kit_required_items_r2310
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---- Table 2: spot-check audit log -----------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_kit_audits_r2310 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  auditor_user_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  audited_at      timestamptz NOT NULL DEFAULT now(),
  location_city   text,
  audit_kind      text NOT NULL DEFAULT 'random' CHECK (audit_kind IN ('random','scheduled','complaint','followup')),
  missing_item_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
  total_missing   integer NOT NULL DEFAULT 0 CHECK (total_missing >= 0),
  replacement_cost_rupees integer NOT NULL DEFAULT 0 CHECK (replacement_cost_rupees >= 0),
  passed          boolean NOT NULL DEFAULT true,
  recovered_from_payout boolean NOT NULL DEFAULT false,
  notes           text
);

CREATE INDEX IF NOT EXISTS idx_eka_r2310_engineer
  ON public.engineer_kit_audits_r2310 (engineer_user_id, audited_at DESC);
CREATE INDEX IF NOT EXISTS idx_eka_r2310_audited_at
  ON public.engineer_kit_audits_r2310 (audited_at DESC);
CREATE INDEX IF NOT EXISTS idx_eka_r2310_passed
  ON public.engineer_kit_audits_r2310 (passed);

ALTER TABLE public.engineer_kit_audits_r2310 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eka_r2310_founder_all ON public.engineer_kit_audits_r2310;
CREATE POLICY eka_r2310_founder_all
  ON public.engineer_kit_audits_r2310
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs (7) — all founder-gated, LANGUAGE plpgsql SECURITY DEFINER
-- ============================================================================

-- 1. list_required_items_r2310 ------------------------------------------------
DROP FUNCTION IF EXISTS public.list_required_items_r2310();
CREATE OR REPLACE FUNCTION public.list_required_items_r2310()
RETURNS TABLE (
  id uuid,
  item_code text,
  item_name text,
  category text,
  is_mandatory boolean,
  replacement_cost_rupees integer,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.item_code, r.item_name, r.category, r.is_mandatory, r.replacement_cost_rupees, r.notes
    FROM public.engineer_kit_required_items_r2310 r
   ORDER BY r.is_mandatory DESC, r.category, r.item_name;
END;
$$;

REVOKE ALL ON FUNCTION public.list_required_items_r2310() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_required_items_r2310() TO authenticated;

-- 2. list_audits_r2310 --------------------------------------------------------
DROP FUNCTION IF EXISTS public.list_audits_r2310();
CREATE OR REPLACE FUNCTION public.list_audits_r2310()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  auditor_email text,
  audited_at timestamptz,
  location_city text,
  audit_kind text,
  missing_item_codes text[],
  total_missing integer,
  replacement_cost_rupees integer,
  passed boolean,
  recovered_from_payout boolean,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id,
         a.engineer_user_id,
         pe.email::text AS engineer_email,
         pa.email::text AS auditor_email,
         a.audited_at,
         a.location_city,
         a.audit_kind,
         a.missing_item_codes,
         a.total_missing,
         a.replacement_cost_rupees,
         a.passed,
         a.recovered_from_payout,
         a.notes
    FROM public.engineer_kit_audits_r2310 a
    LEFT JOIN public.profiles pe ON pe.id = a.engineer_user_id
    LEFT JOIN public.profiles pa ON pa.id = a.auditor_user_id
   ORDER BY a.audited_at DESC
   LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.list_audits_r2310() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_audits_r2310() TO authenticated;

-- 3. audit_summary_r2310 ------------------------------------------------------
DROP FUNCTION IF EXISTS public.audit_summary_r2310();
CREATE OR REPLACE FUNCTION public.audit_summary_r2310()
RETURNS TABLE (
  total_audits integer,
  passed_count integer,
  failed_count integer,
  pass_pct integer,
  total_missing_items integer,
  total_replacement_cost_rupees integer,
  recovered_cost_rupees integer,
  unrecovered_cost_rupees integer,
  last_audit_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::integer AS total_audits,
         COUNT(*) FILTER (WHERE a.passed)::integer AS passed_count,
         COUNT(*) FILTER (WHERE NOT a.passed)::integer AS failed_count,
         CASE WHEN COUNT(*) > 0
              THEN (COUNT(*) FILTER (WHERE a.passed) * 100 / COUNT(*))::integer
              ELSE 0 END AS pass_pct,
         COALESCE(SUM(a.total_missing), 0)::integer AS total_missing_items,
         COALESCE(SUM(a.replacement_cost_rupees), 0)::integer AS total_replacement_cost_rupees,
         COALESCE(SUM(a.replacement_cost_rupees) FILTER (WHERE a.recovered_from_payout), 0)::integer AS recovered_cost_rupees,
         COALESCE(SUM(a.replacement_cost_rupees) FILTER (WHERE NOT a.recovered_from_payout), 0)::integer AS unrecovered_cost_rupees,
         MAX(a.audited_at) AS last_audit_at
    FROM public.engineer_kit_audits_r2310 a;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_summary_r2310() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_summary_r2310() TO authenticated;

-- 4. engineer_offenders_r2310 -------------------------------------------------
DROP FUNCTION IF EXISTS public.engineer_offenders_r2310();
CREATE OR REPLACE FUNCTION public.engineer_offenders_r2310()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  audit_count integer,
  failed_count integer,
  total_missing integer,
  total_cost_rupees integer,
  recovered_cost_rupees integer,
  last_audit_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_user_id,
         pe.email::text AS engineer_email,
         COUNT(*)::integer AS audit_count,
         COUNT(*) FILTER (WHERE NOT a.passed)::integer AS failed_count,
         COALESCE(SUM(a.total_missing), 0)::integer AS total_missing,
         COALESCE(SUM(a.replacement_cost_rupees), 0)::integer AS total_cost_rupees,
         COALESCE(SUM(a.replacement_cost_rupees) FILTER (WHERE a.recovered_from_payout), 0)::integer AS recovered_cost_rupees,
         MAX(a.audited_at) AS last_audit_at
    FROM public.engineer_kit_audits_r2310 a
    LEFT JOIN public.profiles pe ON pe.id = a.engineer_user_id
   GROUP BY a.engineer_user_id, pe.email
   ORDER BY failed_count DESC, total_cost_rupees DESC
   LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_offenders_r2310() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_offenders_r2310() TO authenticated;

-- 5. missing_item_frequency_r2310 --------------------------------------------
DROP FUNCTION IF EXISTS public.missing_item_frequency_r2310();
CREATE OR REPLACE FUNCTION public.missing_item_frequency_r2310()
RETURNS TABLE (
  item_code text,
  item_name text,
  category text,
  miss_count integer,
  replacement_cost_rupees integer,
  total_cost_exposure_rupees integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH unnested AS (
    SELECT unnest(a.missing_item_codes) AS code
      FROM public.engineer_kit_audits_r2310 a
  ),
  counts AS (
    SELECT code, COUNT(*)::integer AS c
      FROM unnested
     GROUP BY code
  )
  SELECT r.item_code,
         r.item_name,
         r.category,
         COALESCE(c.c, 0)::integer AS miss_count,
         r.replacement_cost_rupees,
         (COALESCE(c.c, 0) * r.replacement_cost_rupees)::integer AS total_cost_exposure_rupees
    FROM public.engineer_kit_required_items_r2310 r
    LEFT JOIN counts c ON c.code = r.item_code
   ORDER BY miss_count DESC, r.item_name
   LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.missing_item_frequency_r2310() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.missing_item_frequency_r2310() TO authenticated;

-- 6. audits_by_month_r2310 ----------------------------------------------------
DROP FUNCTION IF EXISTS public.audits_by_month_r2310();
CREATE OR REPLACE FUNCTION public.audits_by_month_r2310()
RETURNS TABLE (
  month_start date,
  audit_count integer,
  failed_count integer,
  total_missing integer,
  total_cost_rupees integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.audited_at)::date AS month_start,
         COUNT(*)::integer AS audit_count,
         COUNT(*) FILTER (WHERE NOT a.passed)::integer AS failed_count,
         COALESCE(SUM(a.total_missing), 0)::integer AS total_missing,
         COALESCE(SUM(a.replacement_cost_rupees), 0)::integer AS total_cost_rupees
    FROM public.engineer_kit_audits_r2310 a
   GROUP BY date_trunc('month', a.audited_at)
   ORDER BY month_start DESC
   LIMIT 24;
END;
$$;

REVOKE ALL ON FUNCTION public.audits_by_month_r2310() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audits_by_month_r2310() TO authenticated;

-- 7. audits_by_kind_r2310 -----------------------------------------------------
DROP FUNCTION IF EXISTS public.audits_by_kind_r2310();
CREATE OR REPLACE FUNCTION public.audits_by_kind_r2310()
RETURNS TABLE (
  audit_kind text,
  audit_count integer,
  failed_count integer,
  fail_pct integer,
  total_cost_rupees integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.audit_kind,
         COUNT(*)::integer AS audit_count,
         COUNT(*) FILTER (WHERE NOT a.passed)::integer AS failed_count,
         CASE WHEN COUNT(*) > 0
              THEN (COUNT(*) FILTER (WHERE NOT a.passed) * 100 / COUNT(*))::integer
              ELSE 0 END AS fail_pct,
         COALESCE(SUM(a.replacement_cost_rupees), 0)::integer AS total_cost_rupees
    FROM public.engineer_kit_audits_r2310 a
   GROUP BY a.audit_kind
   ORDER BY audit_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.audits_by_kind_r2310() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audits_by_kind_r2310() TO authenticated;

COMMIT;
