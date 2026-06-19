BEGIN;
-- round1352_founder_tech_debt_ledger.sql
-- Tech debt ledger: known debt items + payback priority for founder.
-- Founder-only writes via log_* RPCs; reads via founder_tech_debt_summary + founder_tech_debt_recent.

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_tech_debt_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  area text NOT NULL CHECK (area IN (
    'backend_postgres','backend_supabase_fn','android','web_console',
    'cron','infra','data','testing','docs','other'
  )),
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('high','medium','low')),
  payback_kind text CHECK (payback_kind IN (
    'refactor','rewrite','test_coverage','perf_optimize',
    'schema_migration','security_hardening','observability',
    'dependency_upgrade','documentation'
  )),
  estimated_effort_days int NOT NULL DEFAULT 1 CHECK (estimated_effort_days >= 0),
  payback_priority int NOT NULL DEFAULT 50 CHECK (payback_priority >= 0 AND payback_priority <= 100),
  reported_at timestamptz NOT NULL DEFAULT now(),
  reported_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','triaged','in_progress','paid_off','wont_do')),
  description text,
  mitigation_notes text,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_tech_debt_items_status_priority_idx
  ON public.founder_tech_debt_items (status, payback_priority DESC, reported_at DESC);
CREATE INDEX IF NOT EXISTS founder_tech_debt_items_area_idx
  ON public.founder_tech_debt_items (area);
CREATE INDEX IF NOT EXISTS founder_tech_debt_items_reported_at_idx
  ON public.founder_tech_debt_items (reported_at DESC);

ALTER TABLE public.founder_tech_debt_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.founder_tech_debt_items FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS founder_tech_debt_items_founder_all ON public.founder_tech_debt_items;
CREATE POLICY founder_tech_debt_items_founder_all
  ON public.founder_tech_debt_items
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ------------------------------------------------------------------
-- KPI summary RPC
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_tech_debt_summary();
CREATE OR REPLACE FUNCTION public.founder_tech_debt_summary()
RETURNS TABLE (
  total_items int,
  open_count int,
  triaged_count int,
  in_progress_count int,
  paid_off_count int,
  wont_do_count int,
  high_severity_open int,
  medium_severity_open int,
  low_severity_open int,
  total_estimated_effort_days_open int,
  oldest_open_age_days int,
  paid_off_last_30d int,
  top_area text,
  top_area_count int,
  avg_payback_priority_open numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_tech_debt_items
  ),
  area_rank AS (
    SELECT area, COUNT(*)::int AS n
    FROM base
    WHERE status IN ('open','triaged','in_progress')
    GROUP BY area
    ORDER BY n DESC, area ASC
    LIMIT 1
  )
  SELECT
    (SELECT COUNT(*)::int FROM base),
    (SELECT COUNT(*)::int FROM base WHERE status = 'open'),
    (SELECT COUNT(*)::int FROM base WHERE status = 'triaged'),
    (SELECT COUNT(*)::int FROM base WHERE status = 'in_progress'),
    (SELECT COUNT(*)::int FROM base WHERE status = 'paid_off'),
    (SELECT COUNT(*)::int FROM base WHERE status = 'wont_do'),
    (SELECT COUNT(*)::int FROM base WHERE status IN ('open','triaged','in_progress') AND severity = 'high'),
    (SELECT COUNT(*)::int FROM base WHERE status IN ('open','triaged','in_progress') AND severity = 'medium'),
    (SELECT COUNT(*)::int FROM base WHERE status IN ('open','triaged','in_progress') AND severity = 'low'),
    (SELECT COALESCE(SUM(estimated_effort_days),0)::int FROM base WHERE status IN ('open','triaged','in_progress')),
    (SELECT COALESCE(
       EXTRACT(EPOCH FROM (now() - MIN(reported_at)))::int / 86400,
       0)::int
     FROM base WHERE status IN ('open','triaged','in_progress')),
    (SELECT COUNT(*)::int FROM base WHERE status = 'paid_off' AND closed_at >= now() - interval '30 days'),
    (SELECT COALESCE((SELECT area FROM area_rank), '—')),
    (SELECT COALESCE((SELECT n FROM area_rank), 0)),
    (SELECT COALESCE(AVG(payback_priority)::numeric(6,2), 0)
     FROM base WHERE status IN ('open','triaged','in_progress'));
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_tech_debt_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tech_debt_summary() TO authenticated;

-- ------------------------------------------------------------------
-- Ledger feed RPC (status filter + limit, ordered by priority desc)
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_tech_debt_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_tech_debt_recent(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  title text,
  area text,
  severity text,
  payback_kind text,
  estimated_effort_days int,
  payback_priority int,
  status text,
  reported_at timestamptz,
  reported_by uuid,
  reported_by_email text,
  assigned_to uuid,
  assigned_to_email text,
  description text,
  mitigation_notes text,
  closed_at timestamptz,
  age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.title,
    i.area,
    i.severity,
    i.payback_kind,
    i.estimated_effort_days,
    i.payback_priority,
    i.status,
    i.reported_at,
    i.reported_by,
    rep.email::text,
    i.assigned_to,
    asg.email::text,
    i.description,
    i.mitigation_notes,
    i.closed_at,
    (EXTRACT(EPOCH FROM (now() - i.reported_at))::int / 86400)::int
  FROM public.founder_tech_debt_items i
  LEFT JOIN auth.users rep ON rep.id = i.reported_by
  LEFT JOIN auth.users asg ON asg.id = i.assigned_to
  WHERE p_status IS NULL OR i.status = p_status
  ORDER BY i.payback_priority DESC, i.reported_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_tech_debt_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tech_debt_recent(text, int) TO authenticated;

-- ------------------------------------------------------------------
-- Write RPCs
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_tech_debt_register(text, text, text, text, int, int, text, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_tech_debt_register(
  p_title text,
  p_area text,
  p_severity text DEFAULT 'medium',
  p_payback_kind text DEFAULT NULL,
  p_estimated_effort_days int DEFAULT 1,
  p_payback_priority int DEFAULT 50,
  p_description text DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title required' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_tech_debt_items
    (title, area, severity, payback_kind, estimated_effort_days,
     payback_priority, description, reported_by, assigned_to)
  VALUES
    (p_title, p_area, COALESCE(p_severity,'medium'), p_payback_kind,
     COALESCE(p_estimated_effort_days,1), COALESCE(p_payback_priority,50),
     p_description, auth.uid(), p_assigned_to)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.log_founder_tech_debt_register(text, text, text, text, int, int, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_tech_debt_register(text, text, text, text, int, int, text, uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_tech_debt_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_tech_debt_status(
  p_id uuid,
  p_new_status text,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_new_status NOT IN ('open','triaged','in_progress','paid_off','wont_do') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_tech_debt_items
  SET status = p_new_status,
      mitigation_notes = COALESCE(NULLIF(trim(p_note),''), mitigation_notes),
      closed_at = CASE WHEN p_new_status IN ('paid_off','wont_do') THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'tech debt item % not found', p_id USING ERRCODE='P0002';
  END IF;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.log_founder_tech_debt_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_tech_debt_status(uuid, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_tech_debt_priority(uuid, int);
CREATE OR REPLACE FUNCTION public.log_founder_tech_debt_priority(
  p_id uuid,
  p_new_priority int
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_new_priority IS NULL OR p_new_priority < 0 OR p_new_priority > 100 THEN
    RAISE EXCEPTION 'priority must be 0..100' USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_tech_debt_items
  SET payback_priority = p_new_priority,
      updated_at = now()
  WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'tech debt item % not found', p_id USING ERRCODE='P0002';
  END IF;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.log_founder_tech_debt_priority(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_tech_debt_priority(uuid, int) TO authenticated;

COMMIT;