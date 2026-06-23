BEGIN;

-- Promised customer callbacks logged by engineers (or auto-created when a customer requests a callback)
CREATE TABLE IF NOT EXISTS public.engineer_customer_callbacks_r2386 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  customer_org text,
  related_job_id uuid,
  reason text NOT NULL CHECK (reason IN ('quote_followup','part_eta','repair_status','amc_renewal','complaint','general')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
  promised_at timestamptz NOT NULL,
  callback_due_by timestamptz NOT NULL,
  actual_callback_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','met','missed','recovered','cancelled')),
  outcome_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eccb_r2386_engineer ON public.engineer_customer_callbacks_r2386(engineer_user_id, callback_due_by DESC);
CREATE INDEX IF NOT EXISTS idx_eccb_r2386_status ON public.engineer_customer_callbacks_r2386(status, callback_due_by DESC);

ALTER TABLE public.engineer_customer_callbacks_r2386 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_customer_callbacks_r2386;
CREATE POLICY founder_all ON public.engineer_customer_callbacks_r2386
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Recovery actions when a callback was missed: did engineer recover, when, and customer satisfaction
CREATE TABLE IF NOT EXISTS public.engineer_callback_recoveries_r2386 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  callback_id uuid NOT NULL REFERENCES public.engineer_customer_callbacks_r2386(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recovered_at timestamptz NOT NULL DEFAULT now(),
  hours_late numeric(8,2) NOT NULL,
  recovery_channel text NOT NULL CHECK (recovery_channel IN ('phone','whatsapp','email','in_person')),
  customer_acknowledged boolean NOT NULL DEFAULT false,
  customer_satisfaction smallint CHECK (customer_satisfaction BETWEEN 1 AND 5),
  apology_offered boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecr_r2386_engineer ON public.engineer_callback_recoveries_r2386(engineer_user_id, recovered_at DESC);
CREATE INDEX IF NOT EXISTS idx_ecr_r2386_callback ON public.engineer_callback_recoveries_r2386(callback_id);

ALTER TABLE public.engineer_callback_recoveries_r2386 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_callback_recoveries_r2386;
CREATE POLICY founder_all ON public.engineer_callback_recoveries_r2386
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: Overall discipline KPIs across the engineer roster
CREATE OR REPLACE FUNCTION public.r2386_callback_discipline_kpis(p_days int DEFAULT 30)
RETURNS TABLE (
  total_callbacks bigint,
  met_count bigint,
  missed_count bigint,
  recovered_count bigint,
  pending_count bigint,
  met_pct numeric,
  recovery_pct numeric,
  avg_response_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status = 'met')::bigint,
    COUNT(*) FILTER (WHERE status = 'missed')::bigint,
    COUNT(*) FILTER (WHERE status = 'recovered')::bigint,
    COUNT(*) FILTER (WHERE status = 'pending')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'met') / NULLIF(COUNT(*) FILTER (WHERE status IN ('met','missed','recovered')), 0), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'recovered') / NULLIF(COUNT(*) FILTER (WHERE status IN ('missed','recovered')), 0), 2),
    ROUND(AVG(EXTRACT(EPOCH FROM (actual_callback_at - promised_at)) / 60.0) FILTER (WHERE actual_callback_at IS NOT NULL), 1)
  FROM public.engineer_customer_callbacks_r2386
  WHERE promised_at >= now() - make_interval(days => p_days);
END;
$$;

REVOKE ALL ON FUNCTION public.r2386_callback_discipline_kpis(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2386_callback_discipline_kpis(int) TO authenticated;

-- RPC 2: Per-engineer leaderboard
CREATE OR REPLACE FUNCTION public.r2386_engineer_callback_leaderboard(p_days int DEFAULT 30)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_callbacks bigint,
  met_count bigint,
  missed_count bigint,
  met_pct numeric,
  avg_response_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.engineer_user_id,
    p.email,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.status = 'met')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'missed')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.status = 'met') / NULLIF(COUNT(*) FILTER (WHERE c.status IN ('met','missed','recovered')), 0), 2),
    ROUND(AVG(EXTRACT(EPOCH FROM (c.actual_callback_at - c.promised_at)) / 60.0) FILTER (WHERE c.actual_callback_at IS NOT NULL), 1)
  FROM public.engineer_customer_callbacks_r2386 c
  JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.promised_at >= now() - make_interval(days => p_days)
  GROUP BY c.engineer_user_id, p.email
  ORDER BY COUNT(*) FILTER (WHERE c.status = 'met')::numeric / NULLIF(COUNT(*), 0) DESC NULLS LAST, COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2386_engineer_callback_leaderboard(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2386_engineer_callback_leaderboard(int) TO authenticated;

-- RPC 3: Currently overdue (past due_by, still pending)
CREATE OR REPLACE FUNCTION public.r2386_overdue_callbacks()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  customer_name text,
  customer_phone text,
  reason text,
  priority text,
  promised_at timestamptz,
  callback_due_by timestamptz,
  hours_overdue numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    p.email,
    c.customer_name,
    c.customer_phone,
    c.reason,
    c.priority,
    c.promised_at,
    c.callback_due_by,
    ROUND(EXTRACT(EPOCH FROM (now() - c.callback_due_by)) / 3600.0, 2)
  FROM public.engineer_customer_callbacks_r2386 c
  JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.status = 'pending' AND c.callback_due_by < now()
  ORDER BY c.callback_due_by ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2386_overdue_callbacks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2386_overdue_callbacks() TO authenticated;

-- RPC 4: Recovery analytics
CREATE OR REPLACE FUNCTION public.r2386_recovery_analytics(p_days int DEFAULT 30)
RETURNS TABLE (
  total_missed bigint,
  total_recovered bigint,
  acknowledged_count bigint,
  apology_count bigint,
  avg_hours_late numeric,
  avg_satisfaction numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.engineer_customer_callbacks_r2386 WHERE status IN ('missed','recovered') AND promised_at >= now() - make_interval(days => p_days))::bigint,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE customer_acknowledged)::bigint,
    COUNT(*) FILTER (WHERE apology_offered)::bigint,
    ROUND(AVG(hours_late), 2),
    ROUND(AVG(customer_satisfaction)::numeric, 2)
  FROM public.engineer_callback_recoveries_r2386
  WHERE recovered_at >= now() - make_interval(days => p_days);
END;
$$;

REVOKE ALL ON FUNCTION public.r2386_recovery_analytics(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2386_recovery_analytics(int) TO authenticated;

-- RPC 5: Breakdown by reason
CREATE OR REPLACE FUNCTION public.r2386_callback_breakdown_by_reason(p_days int DEFAULT 30)
RETURNS TABLE (
  reason text,
  total_count bigint,
  met_count bigint,
  missed_count bigint,
  met_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.reason,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.status = 'met')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'missed')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.status = 'met') / NULLIF(COUNT(*) FILTER (WHERE c.status IN ('met','missed','recovered')), 0), 2)
  FROM public.engineer_customer_callbacks_r2386 c
  WHERE c.promised_at >= now() - make_interval(days => p_days)
  GROUP BY c.reason
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2386_callback_breakdown_by_reason(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2386_callback_breakdown_by_reason(int) TO authenticated;

-- RPC 6: Repeat offender engineers (missed > N)
CREATE OR REPLACE FUNCTION public.r2386_repeat_offenders(p_days int DEFAULT 30, p_threshold int DEFAULT 3)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  missed_count bigint,
  recovered_count bigint,
  total_count bigint,
  miss_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.engineer_user_id,
    p.email,
    COUNT(*) FILTER (WHERE c.status = 'missed')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'recovered')::bigint,
    COUNT(*)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.status IN ('missed','recovered')) / NULLIF(COUNT(*), 0), 2)
  FROM public.engineer_customer_callbacks_r2386 c
  JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.promised_at >= now() - make_interval(days => p_days)
  GROUP BY c.engineer_user_id, p.email
  HAVING COUNT(*) FILTER (WHERE c.status IN ('missed','recovered')) >= p_threshold
  ORDER BY COUNT(*) FILTER (WHERE c.status = 'missed') DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2386_repeat_offenders(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2386_repeat_offenders(int, int) TO authenticated;

-- RPC 7: Recent recovery events feed
CREATE OR REPLACE FUNCTION public.r2386_recent_recovery_events(p_limit int DEFAULT 50)
RETURNS TABLE (
  recovery_id uuid,
  engineer_email text,
  customer_name text,
  reason text,
  hours_late numeric,
  recovery_channel text,
  customer_acknowledged boolean,
  customer_satisfaction smallint,
  apology_offered boolean,
  recovered_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    p.email,
    c.customer_name,
    c.reason,
    r.hours_late,
    r.recovery_channel,
    r.customer_acknowledged,
    r.customer_satisfaction,
    r.apology_offered,
    r.recovered_at
  FROM public.engineer_callback_recoveries_r2386 r
  JOIN public.engineer_customer_callbacks_r2386 c ON c.id = r.callback_id
  JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.recovered_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.r2386_recent_recovery_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2386_recent_recovery_events(int) TO authenticated;

COMMIT;
