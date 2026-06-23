-- Round 2432: Customer feedback loop closure
-- Founder-only tracking of customer feedback through root-cause -> fix -> loop-closure -> NPS recovery.

BEGIN;

-- ============================================================
-- TABLE 1: customer_feedback_items_r2432
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customer_feedback_items_r2432 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  feedback_kind text NOT NULL CHECK (feedback_kind IN ('complaint','feature_request','bug','praise','suggestion')),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  root_cause_kind text NOT NULL CHECK (root_cause_kind IN ('product','process','people','policy','unknown')),
  root_cause_notes text,
  fix_shipped_at timestamptz,
  fix_pr_ref text,
  loop_closed_at timestamptz,
  loop_closure_kind text CHECK (loop_closure_kind IN ('call','email','visit','portal')),
  nps_before int CHECK (nps_before BETWEEN 0 AND 10),
  nps_after int CHECK (nps_after BETWEEN 0 AND 10),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_feedback_items_r2432 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_feedback_items_r2432;
CREATE POLICY founder_all ON public.customer_feedback_items_r2432
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE 2: feedback_root_cause_metrics_r2432
-- ============================================================
CREATE TABLE IF NOT EXISTS public.feedback_root_cause_metrics_r2432 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_start date NOT NULL,
  period_end date NOT NULL,
  root_cause_kind text NOT NULL CHECK (root_cause_kind IN ('product','process','people','policy','unknown')),
  item_count int NOT NULL DEFAULT 0,
  avg_close_days numeric(8,2) NOT NULL DEFAULT 0,
  total_nps_recovery int NOT NULL DEFAULT 0,
  closed_count int NOT NULL DEFAULT 0,
  open_count int NOT NULL DEFAULT 0,
  action_plan text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.feedback_root_cause_metrics_r2432 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.feedback_root_cause_metrics_r2432;
CREATE POLICY founder_all ON public.feedback_root_cause_metrics_r2432
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_feedback_r2432
-- ============================================================
DROP FUNCTION IF EXISTS public.list_feedback_r2432();
CREATE OR REPLACE FUNCTION public.list_feedback_r2432()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  feedback_kind text,
  submitted_at timestamptz,
  severity text,
  root_cause_kind text,
  root_cause_notes text,
  fix_shipped_at timestamptz,
  fix_pr_ref text,
  loop_closed_at timestamptz,
  loop_closure_kind text,
  nps_before int,
  nps_after int,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.hospital_user_id, f.feedback_kind, f.submitted_at, f.severity,
           f.root_cause_kind, f.root_cause_notes, f.fix_shipped_at, f.fix_pr_ref,
           f.loop_closed_at, f.loop_closure_kind, f.nps_before, f.nps_after,
           f.owner_email, f.notes, f.created_at
    FROM public.customer_feedback_items_r2432 f
    ORDER BY f.submitted_at DESC NULLS LAST, f.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_feedback_r2432() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_feedback_r2432() TO authenticated;

-- ============================================================
-- RPC 2: list_metrics_r2432
-- ============================================================
DROP FUNCTION IF EXISTS public.list_metrics_r2432();
CREATE OR REPLACE FUNCTION public.list_metrics_r2432()
RETURNS TABLE (
  id uuid,
  period_start date,
  period_end date,
  root_cause_kind text,
  item_count int,
  avg_close_days numeric,
  total_nps_recovery int,
  closed_count int,
  open_count int,
  action_plan text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.period_start, m.period_end, m.root_cause_kind, m.item_count,
           m.avg_close_days, m.total_nps_recovery, m.closed_count, m.open_count,
           m.action_plan, m.notes, m.created_at
    FROM public.feedback_root_cause_metrics_r2432 m
    ORDER BY m.period_start DESC, m.root_cause_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_metrics_r2432() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_metrics_r2432() TO authenticated;

-- ============================================================
-- RPC 3: top_root_causes_r2432
-- ============================================================
DROP FUNCTION IF EXISTS public.top_root_causes_r2432();
CREATE OR REPLACE FUNCTION public.top_root_causes_r2432()
RETURNS TABLE (
  root_cause_kind text,
  item_count bigint,
  closed_count bigint,
  open_count bigint,
  critical_count bigint,
  avg_close_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.root_cause_kind,
           COUNT(*)::bigint AS item_count,
           COUNT(*) FILTER (WHERE f.loop_closed_at IS NOT NULL)::bigint AS closed_count,
           COUNT(*) FILTER (WHERE f.loop_closed_at IS NULL)::bigint AS open_count,
           COUNT(*) FILTER (WHERE f.severity = 'critical')::bigint AS critical_count,
           COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/86400.0)
                          FILTER (WHERE f.loop_closed_at IS NOT NULL)::numeric, 2), 0) AS avg_close_days
    FROM public.customer_feedback_items_r2432 f
    GROUP BY f.root_cause_kind
    ORDER BY item_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_root_causes_r2432() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_root_causes_r2432() TO authenticated;

-- ============================================================
-- RPC 4: nps_recovery_summary_r2432
-- ============================================================
DROP FUNCTION IF EXISTS public.nps_recovery_summary_r2432();
CREATE OR REPLACE FUNCTION public.nps_recovery_summary_r2432()
RETURNS TABLE (
  total_items bigint,
  items_with_nps bigint,
  avg_nps_before numeric,
  avg_nps_after numeric,
  total_nps_lift numeric,
  recovered_count bigint,
  regressed_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint AS total_items,
           COUNT(*) FILTER (WHERE f.nps_before IS NOT NULL AND f.nps_after IS NOT NULL)::bigint AS items_with_nps,
           COALESCE(ROUND(AVG(f.nps_before)::numeric, 2), 0) AS avg_nps_before,
           COALESCE(ROUND(AVG(f.nps_after)::numeric, 2), 0) AS avg_nps_after,
           COALESCE(SUM(f.nps_after - f.nps_before)::numeric, 0) AS total_nps_lift,
           COUNT(*) FILTER (WHERE f.nps_after > f.nps_before)::bigint AS recovered_count,
           COUNT(*) FILTER (WHERE f.nps_after < f.nps_before)::bigint AS regressed_count
    FROM public.customer_feedback_items_r2432 f;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_recovery_summary_r2432() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_recovery_summary_r2432() TO authenticated;

-- ============================================================
-- RPC 5: closure_velocity_r2432
-- ============================================================
DROP FUNCTION IF EXISTS public.closure_velocity_r2432();
CREATE OR REPLACE FUNCTION public.closure_velocity_r2432()
RETURNS TABLE (
  severity text,
  item_count bigint,
  closed_count bigint,
  avg_fix_days numeric,
  avg_close_days numeric,
  fastest_close_days numeric,
  slowest_close_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.severity,
           COUNT(*)::bigint AS item_count,
           COUNT(*) FILTER (WHERE f.loop_closed_at IS NOT NULL)::bigint AS closed_count,
           COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (f.fix_shipped_at - f.submitted_at))/86400.0)
                          FILTER (WHERE f.fix_shipped_at IS NOT NULL)::numeric, 2), 0) AS avg_fix_days,
           COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/86400.0)
                          FILTER (WHERE f.loop_closed_at IS NOT NULL)::numeric, 2), 0) AS avg_close_days,
           COALESCE(ROUND(MIN(EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/86400.0)
                          FILTER (WHERE f.loop_closed_at IS NOT NULL)::numeric, 2), 0) AS fastest_close_days,
           COALESCE(ROUND(MAX(EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/86400.0)
                          FILTER (WHERE f.loop_closed_at IS NOT NULL)::numeric, 2), 0) AS slowest_close_days
    FROM public.customer_feedback_items_r2432 f
    GROUP BY f.severity
    ORDER BY CASE f.severity
               WHEN 'critical' THEN 1
               WHEN 'high' THEN 2
               WHEN 'medium' THEN 3
               WHEN 'low' THEN 4
               ELSE 5
             END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.closure_velocity_r2432() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.closure_velocity_r2432() TO authenticated;

-- ============================================================
-- RPC 6: top_impacted_hospitals_r2432
-- ============================================================
DROP FUNCTION IF EXISTS public.top_impacted_hospitals_r2432();
CREATE OR REPLACE FUNCTION public.top_impacted_hospitals_r2432()
RETURNS TABLE (
  hospital_user_id uuid,
  feedback_count bigint,
  critical_count bigint,
  open_count bigint,
  avg_nps_lift numeric,
  last_submitted_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.hospital_user_id,
           COUNT(*)::bigint AS feedback_count,
           COUNT(*) FILTER (WHERE f.severity = 'critical')::bigint AS critical_count,
           COUNT(*) FILTER (WHERE f.loop_closed_at IS NULL)::bigint AS open_count,
           COALESCE(ROUND(AVG(f.nps_after - f.nps_before)
                          FILTER (WHERE f.nps_before IS NOT NULL AND f.nps_after IS NOT NULL)::numeric, 2), 0) AS avg_nps_lift,
           MAX(f.submitted_at) AS last_submitted_at
    FROM public.customer_feedback_items_r2432 f
    GROUP BY f.hospital_user_id
    ORDER BY feedback_count DESC, critical_count DESC
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_impacted_hospitals_r2432() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_impacted_hospitals_r2432() TO authenticated;

-- ============================================================
-- RPC 7: open_critical_focus_r2432
-- ============================================================
DROP FUNCTION IF EXISTS public.open_critical_focus_r2432();
CREATE OR REPLACE FUNCTION public.open_critical_focus_r2432()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  feedback_kind text,
  severity text,
  root_cause_kind text,
  root_cause_notes text,
  submitted_at timestamptz,
  days_open numeric,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.hospital_user_id, f.feedback_kind, f.severity, f.root_cause_kind,
           f.root_cause_notes, f.submitted_at,
           ROUND(EXTRACT(EPOCH FROM (now() - f.submitted_at))/86400.0::numeric, 2) AS days_open,
           f.owner_email
    FROM public.customer_feedback_items_r2432 f
    WHERE f.loop_closed_at IS NULL
      AND f.severity IN ('critical','high')
    ORDER BY CASE f.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
             f.submitted_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.open_critical_focus_r2432() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_critical_focus_r2432() TO authenticated;

-- ============================================================
-- Seed data
-- ============================================================
DO $seed$
DECLARE
  v_hosp uuid;
BEGIN
  SELECT id INTO v_hosp FROM public.profiles WHERE role = 'hospital_admin' LIMIT 1;
  IF v_hosp IS NULL THEN
    SELECT id INTO v_hosp FROM public.profiles LIMIT 1;
  END IF;

  IF v_hosp IS NOT NULL THEN
    INSERT INTO public.customer_feedback_items_r2432
      (hospital_user_id, feedback_kind, submitted_at, severity, root_cause_kind, root_cause_notes,
       fix_shipped_at, fix_pr_ref, loop_closed_at, loop_closure_kind,
       nps_before, nps_after, owner_email, notes)
    VALUES
      (v_hosp, 'complaint', now() - interval '14 days', 'critical', 'product',
       'AMC billing showed wrong tier after upgrade',
       now() - interval '10 days', 'PR #1850', now() - interval '8 days', 'call',
       3, 8, 'founder@equipseva.in', 'Recovered detractor to promoter post-fix'),
      (v_hosp, 'bug', now() - interval '7 days', 'high', 'product',
       'Job photo upload failed on Android 14',
       now() - interval '5 days', 'PR #1862', now() - interval '4 days', 'portal',
       5, 7, 'eng@equipseva.in', 'Hospital staff confirmed fix on device'),
      (v_hosp, 'feature_request', now() - interval '3 days', 'medium', 'product',
       'Hospital wants bulk-export of AMC invoices', NULL, NULL, NULL, NULL,
       7, NULL, 'pm@equipseva.in', 'On v0.6 roadmap'),
      (v_hosp, 'complaint', now() - interval '21 days', 'high', 'people',
       'Engineer arrived 2hrs late twice', NULL, NULL,
       now() - interval '20 days', 'visit',
       4, 7, 'ops@equipseva.in', 'Engineer reassigned + apology visit'),
      (v_hosp, 'praise', now() - interval '5 days', 'low', 'unknown',
       'Hospital admin loved the new dashboard', NULL, NULL,
       now() - interval '5 days', 'email',
       9, 10, 'founder@equipseva.in', 'Quoted in spotlight library');

    INSERT INTO public.feedback_root_cause_metrics_r2432
      (period_start, period_end, root_cause_kind, item_count, avg_close_days,
       total_nps_recovery, closed_count, open_count, action_plan, notes)
    VALUES
      ((now() - interval '30 days')::date, now()::date, 'product', 12, 6.20, 28, 9, 3,
       'Tighten release QA; add hospital beta channel', 'Product-class issues dominate volume'),
      ((now() - interval '30 days')::date, now()::date, 'people', 5, 3.50, 11, 4, 1,
       'Engineer SLA scorecard + retraining', 'Late arrivals -> reassignment policy'),
      ((now() - interval '30 days')::date, now()::date, 'process', 4, 4.10, 6, 3, 1,
       'Billing handoff checklist', 'Most fixable via runbook'),
      ((now() - interval '30 days')::date, now()::date, 'policy', 2, 9.00, 3, 1, 1,
       'Review AMC tier mismatch policy', 'Slow due to compliance review'),
      ((now() - interval '30 days')::date, now()::date, 'unknown', 3, 2.00, 5, 3, 0,
       'Triage harder before classifying', 'Reduce unknowns by 50%');
  END IF;
END;
$seed$;

