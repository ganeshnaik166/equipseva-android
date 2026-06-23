-- Round 2462: Engineer Uniform PPE Issuance Tracker
-- Engineer × PPE item × size × replacement cycle × compliance audit × supplier × cost

-- =====================================================================
-- TABLE 1: engineer_ppe_issuances_r2462
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_ppe_issuances_r2462 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  issued_at timestamptz NOT NULL,
  item_kind text NOT NULL CHECK (item_kind IN ('uniform','helmet','gloves','safety_shoes','lab_coat','eye_protection','respirator','coverall')),
  size_label text,
  replacement_cycle_months int NOT NULL DEFAULT 12,
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  cost_rupees int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('issued','in_use','replaced','lost','returned')),
  next_replacement_due_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_ppe_issuances_r2462 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_ppe_issuances_r2462;
CREATE POLICY founder_all ON public.engineer_ppe_issuances_r2462
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: ppe_compliance_audits_r2462
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.ppe_compliance_audits_r2462 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  audit_date date NOT NULL,
  total_items int NOT NULL DEFAULT 0,
  missing_items int NOT NULL DEFAULT 0,
  expired_items int NOT NULL DEFAULT 0,
  compliance_score int NOT NULL CHECK (compliance_score BETWEEN 0 AND 100),
  audit_status text NOT NULL CHECK (audit_status IN ('green','amber','red')),
  corrective_action_md text,
  owner_email text,
  closed_at timestamptz,
  closed_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ppe_compliance_audits_r2462 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.ppe_compliance_audits_r2462;
CREATE POLICY founder_all ON public.ppe_compliance_audits_r2462
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_sup1 uuid;
  v_sup2 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.profiles WHERE role = 'engineer' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.profiles WHERE role = 'engineer' AND id <> COALESCE(v_eng1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng3 FROM public.profiles WHERE role = 'engineer' AND id NOT IN (COALESCE(v_eng1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_eng2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_sup1 FROM public.organizations ORDER BY created_at LIMIT 1;
  SELECT id INTO v_sup2 FROM public.organizations WHERE id <> COALESCE(v_sup1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;

  IF v_eng1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.engineer_ppe_issuances_r2462 (engineer_user_id, issued_at, item_kind, size_label, replacement_cycle_months, supplier_org_id, cost_rupees, status, next_replacement_due_at, notes)
  VALUES
    (v_eng1, (now() - interval '45 days')::timestamptz, 'uniform', 'L', 12, v_sup1, 1800, 'in_use', (now() + interval '320 days')::timestamptz, 'Annual issue'),
    (v_eng1, (now() - interval '30 days')::timestamptz, 'safety_shoes', 'UK 9', 18, v_sup1, 2400, 'in_use', (now() + interval '510 days')::timestamptz, 'Steel toe'),
    (COALESCE(v_eng2, v_eng1), (now() - interval '60 days')::timestamptz, 'gloves', 'M', 3, v_sup2, 350, 'replaced', (now() + interval '20 days')::timestamptz, 'Nitrile - replaced once'),
    (COALESCE(v_eng2, v_eng1), (now() - interval '10 days')::timestamptz, 'lab_coat', 'L', 12, v_sup1, 950, 'issued', (now() + interval '355 days')::timestamptz, 'New issue'),
    (COALESCE(v_eng3, v_eng1), (now() - interval '180 days')::timestamptz, 'helmet', 'one-size', 24, v_sup2, 1200, 'lost', NULL, 'Lost on site - to reissue');

  INSERT INTO public.ppe_compliance_audits_r2462 (engineer_user_id, audit_date, total_items, missing_items, expired_items, compliance_score, audit_status, corrective_action_md, owner_email, closed_at, closed_by_email, notes)
  VALUES
    (v_eng1, (current_date - interval '15 days')::date, 8, 0, 0, 100, 'green', '- All PPE present and within cycle', 'safety@equipseva.com', (now() - interval '14 days')::timestamptz, 'safety@equipseva.com', 'Spot check clean'),
    (COALESCE(v_eng2, v_eng1), (current_date - interval '7 days')::date, 8, 1, 1, 75, 'amber', '- Replace expired gloves\n- Reissue helmet within 7 days', 'safety@equipseva.com', NULL, NULL, 'Open corrective action'),
    (COALESCE(v_eng3, v_eng1), (current_date - interval '2 days')::date, 8, 3, 0, 55, 'red', '- Lost helmet\n- Missing eye protection\n- Missing respirator\n- Escalate to ops head', 'safety@equipseva.com', NULL, NULL, 'Red audit - escalated');
END
$seed$;

-- =====================================================================
-- RPC 1: list_issuances_r2462
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_issuances_r2462()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  issued_at timestamptz,
  item_kind text,
  size_label text,
  replacement_cycle_months int,
  supplier_org_id uuid,
  cost_rupees int,
  status text,
  next_replacement_due_at timestamptz,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, p.email, i.issued_at, i.item_kind, i.size_label, i.replacement_cycle_months, i.supplier_org_id, i.cost_rupees, i.status, i.next_replacement_due_at, i.notes
  FROM public.engineer_ppe_issuances_r2462 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
  ORDER BY i.issued_at DESC
  LIMIT 200;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_issuances_r2462() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_issuances_r2462() TO authenticated;

-- =====================================================================
-- RPC 2: list_audits_r2462
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_audits_r2462()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  audit_date date,
  total_items int,
  missing_items int,
  expired_items int,
  compliance_score int,
  audit_status text,
  corrective_action_md text,
  owner_email text,
  closed_at timestamptz,
  closed_by_email text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, p.email, a.audit_date, a.total_items, a.missing_items, a.expired_items, a.compliance_score, a.audit_status, a.corrective_action_md, a.owner_email, a.closed_at, a.closed_by_email, a.notes
  FROM public.ppe_compliance_audits_r2462 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  ORDER BY a.audit_date DESC
  LIMIT 200;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_audits_r2462() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_audits_r2462() TO authenticated;

-- =====================================================================
-- RPC 3: top_replacement_due_r2462
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_replacement_due_r2462()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  item_kind text,
  size_label text,
  next_replacement_due_at timestamptz,
  days_until_due int,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id,
    p.email,
    i.item_kind,
    i.size_label,
    i.next_replacement_due_at,
    EXTRACT(DAY FROM (i.next_replacement_due_at - now()))::int,
    i.status
  FROM public.engineer_ppe_issuances_r2462 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
  WHERE i.next_replacement_due_at IS NOT NULL
    AND i.status IN ('issued','in_use')
  ORDER BY i.next_replacement_due_at ASC
  LIMIT 50;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.top_replacement_due_r2462() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_replacement_due_r2462() TO authenticated;

-- =====================================================================
-- RPC 4: supplier_breakdown_r2462
-- =====================================================================
CREATE OR REPLACE FUNCTION public.supplier_breakdown_r2462()
RETURNS TABLE (
  supplier_org_id uuid,
  supplier_name text,
  issuance_count bigint,
  total_cost_rupees bigint,
  avg_cost_rupees numeric,
  lost_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.supplier_org_id,
    o.name,
    count(*)::bigint,
    sum(i.cost_rupees)::bigint,
    round(avg(i.cost_rupees)::numeric, 2),
    count(*) FILTER (WHERE i.status = 'lost')::bigint
  FROM public.engineer_ppe_issuances_r2462 i
  LEFT JOIN public.organizations o ON o.id = i.supplier_org_id
  GROUP BY i.supplier_org_id, o.name
  ORDER BY count(*) DESC
  LIMIT 25;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.supplier_breakdown_r2462() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supplier_breakdown_r2462() TO authenticated;

-- =====================================================================
-- RPC 5: monthly_cost_trend_r2462
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_cost_trend_r2462()
RETURNS TABLE (
  month_label text,
  issuance_count bigint,
  total_cost_rupees bigint,
  avg_cost_rupees numeric,
  lost_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', i.issued_at), 'YYYY-MM'),
    count(*)::bigint,
    sum(i.cost_rupees)::bigint,
    round(avg(i.cost_rupees)::numeric, 2),
    count(*) FILTER (WHERE i.status = 'lost')::bigint
  FROM public.engineer_ppe_issuances_r2462 i
  GROUP BY 1
  ORDER BY 1 DESC
  LIMIT 12;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.monthly_cost_trend_r2462() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_cost_trend_r2462() TO authenticated;

-- =====================================================================
-- RPC 6: compliance_score_summary_r2462
-- =====================================================================
CREATE OR REPLACE FUNCTION public.compliance_score_summary_r2462()
RETURNS TABLE (
  audit_status text,
  audit_count bigint,
  avg_score numeric,
  avg_missing numeric,
  avg_expired numeric,
  open_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.audit_status,
    count(*)::bigint,
    round(avg(a.compliance_score)::numeric, 2),
    round(avg(a.missing_items)::numeric, 2),
    round(avg(a.expired_items)::numeric, 2),
    count(*) FILTER (WHERE a.closed_at IS NULL)::bigint
  FROM public.ppe_compliance_audits_r2462 a
  GROUP BY a.audit_status
  ORDER BY a.audit_status;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.compliance_score_summary_r2462() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compliance_score_summary_r2462() TO authenticated;

-- =====================================================================
-- RPC 7: lost_items_focus_r2462
-- =====================================================================
CREATE OR REPLACE FUNCTION public.lost_items_focus_r2462()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  item_kind text,
  size_label text,
  issued_at timestamptz,
  cost_rupees int,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, p.email, i.item_kind, i.size_label, i.issued_at, i.cost_rupees, i.notes
  FROM public.engineer_ppe_issuances_r2462 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
  WHERE i.status = 'lost'
  ORDER BY i.issued_at DESC
  LIMIT 100;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.lost_items_focus_r2462() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lost_items_focus_r2462() TO authenticated;
