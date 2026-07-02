-- Round 2526: Engineer Weekend Overtime Fairness
-- Weekend OT × consent × distribution fairness × premium × peer comparison × refusal log

BEGIN;

-- =========================================================================
-- Table 1: engineer_weekend_ot_logs_r2526
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_weekend_ot_logs_r2526 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  weekend_date date NOT NULL,
  hours_worked numeric(6,2) NOT NULL DEFAULT 0,
  premium_rupees int NOT NULL DEFAULT 0,
  consent_given boolean NOT NULL DEFAULT true,
  refusal_reason_kind text NOT NULL DEFAULT 'none'
    CHECK (refusal_reason_kind IN ('none','health','family','burnout','personal','other')),
  peer_count_same_zone int NOT NULL DEFAULT 0,
  peer_avg_hours numeric(6,2) NOT NULL DEFAULT 0,
  fairness_delta_hours numeric(6,2) NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('approved','pending','disputed','refused')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ewot_logs_r2526_engineer
  ON public.engineer_weekend_ot_logs_r2526(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ewot_logs_r2526_date
  ON public.engineer_weekend_ot_logs_r2526(weekend_date);
CREATE INDEX IF NOT EXISTS idx_ewot_logs_r2526_status
  ON public.engineer_weekend_ot_logs_r2526(status);

ALTER TABLE public.engineer_weekend_ot_logs_r2526 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_weekend_ot_logs_r2526;
CREATE POLICY founder_all
  ON public.engineer_weekend_ot_logs_r2526
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- Table 2: weekend_ot_fairness_metrics_r2526
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.weekend_ot_fairness_metrics_r2526 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_weekends_worked int NOT NULL DEFAULT 0,
  total_premium_rupees bigint NOT NULL DEFAULT 0,
  fairness_target_hours numeric(8,2) NOT NULL DEFAULT 0,
  fairness_actual_hours numeric(8,2) NOT NULL DEFAULT 0,
  fairness_status text NOT NULL DEFAULT 'balanced'
    CHECK (fairness_status IN ('under','balanced','over')),
  refusal_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'monitoring'
    CHECK (status IN ('monitoring','coaching','at_risk','balanced')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wot_metrics_r2526_engineer
  ON public.weekend_ot_fairness_metrics_r2526(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_wot_metrics_r2526_period
  ON public.weekend_ot_fairness_metrics_r2526(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_wot_metrics_r2526_status
  ON public.weekend_ot_fairness_metrics_r2526(status);

ALTER TABLE public.weekend_ot_fairness_metrics_r2526 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.weekend_ot_fairness_metrics_r2526;
CREATE POLICY founder_all
  ON public.weekend_ot_fairness_metrics_r2526
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- Seeds
-- =========================================================================
INSERT INTO public.engineer_weekend_ot_logs_r2526
  (engineer_user_id, weekend_date, hours_worked, premium_rupees, consent_given,
   refusal_reason_kind, peer_count_same_zone, peer_avg_hours, fairness_delta_hours,
   owner_email, status, notes)
SELECT e.id,
       '2026-06-14'::date,
       9.50,
       4800,
       true,
       'none',
       6,
       7.20,
       2.30,
       'ops@equipseva.com',
       'approved',
       'OR1 emergency call, consent confirmed via SMS'
FROM public.engineers e
ORDER BY e.created_at
LIMIT 1;

INSERT INTO public.engineer_weekend_ot_logs_r2526
  (engineer_user_id, weekend_date, hours_worked, premium_rupees, consent_given,
   refusal_reason_kind, peer_count_same_zone, peer_avg_hours, fairness_delta_hours,
   owner_email, status, notes)
SELECT e.id,
       '2026-06-15'::date,
       0.00,
       0,
       false,
       'family',
       5,
       6.40,
       -6.40,
       'ops@equipseva.com',
       'refused',
       'engineer declined, family event'
FROM public.engineers e
ORDER BY e.created_at
LIMIT 1;

INSERT INTO public.engineer_weekend_ot_logs_r2526
  (engineer_user_id, weekend_date, hours_worked, premium_rupees, consent_given,
   refusal_reason_kind, peer_count_same_zone, peer_avg_hours, fairness_delta_hours,
   owner_email, status, notes)
SELECT e.id,
       '2026-06-21'::date,
       7.00,
       3500,
       true,
       'none',
       4,
       6.10,
       0.90,
       'ops@equipseva.com',
       'approved',
       'AMC weekend visit, fair share'
FROM public.engineers e
ORDER BY e.created_at
LIMIT 1;

INSERT INTO public.engineer_weekend_ot_logs_r2526
  (engineer_user_id, weekend_date, hours_worked, premium_rupees, consent_given,
   refusal_reason_kind, peer_count_same_zone, peer_avg_hours, fairness_delta_hours,
   owner_email, status, notes)
SELECT e.id,
       '2026-06-22'::date,
       4.00,
       2000,
       true,
       'none',
       5,
       7.80,
       -3.80,
       'ops@equipseva.com',
       'disputed',
       'engineer disputes premium calculation'
FROM public.engineers e
ORDER BY e.created_at
LIMIT 1;

INSERT INTO public.weekend_ot_fairness_metrics_r2526
  (engineer_user_id, period_start, period_end, total_weekends_worked,
   total_premium_rupees, fairness_target_hours, fairness_actual_hours,
   fairness_status, refusal_count, status, notes)
SELECT e.id,
       '2026-06-01'::date,
       '2026-06-30'::date,
       6,
       18600,
       28.00,
       34.50,
       'over',
       1,
       'at_risk',
       'over-quota by 6.5h, schedule coaching'
FROM public.engineers e
ORDER BY e.created_at
LIMIT 1;

INSERT INTO public.weekend_ot_fairness_metrics_r2526
  (engineer_user_id, period_start, period_end, total_weekends_worked,
   total_premium_rupees, fairness_target_hours, fairness_actual_hours,
   fairness_status, refusal_count, status, notes)
SELECT e.id,
       '2026-06-01'::date,
       '2026-06-30'::date,
       3,
       9200,
       28.00,
       19.00,
       'under',
       2,
       'monitoring',
       'under-quota, refusals tracked for context'
FROM public.engineers e
ORDER BY e.created_at
LIMIT 1;

INSERT INTO public.weekend_ot_fairness_metrics_r2526
  (engineer_user_id, period_start, period_end, total_weekends_worked,
   total_premium_rupees, fairness_target_hours, fairness_actual_hours,
   fairness_status, refusal_count, status, notes)
SELECT e.id,
       '2026-06-01'::date,
       '2026-06-30'::date,
       4,
       14400,
       28.00,
       27.50,
       'balanced',
       0,
       'balanced',
       'fairness within target, no action needed'
FROM public.engineers e
ORDER BY e.created_at
LIMIT 1;

-- =========================================================================
-- RPC 1: list_ot_logs_r2526
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_ot_logs_r2526()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  weekend_date date,
  hours_worked numeric,
  premium_rupees int,
  consent_given boolean,
  refusal_reason_kind text,
  peer_count_same_zone int,
  peer_avg_hours numeric,
  fairness_delta_hours numeric,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.engineer_user_id, l.weekend_date, l.hours_worked, l.premium_rupees,
         l.consent_given, l.refusal_reason_kind, l.peer_count_same_zone,
         l.peer_avg_hours, l.fairness_delta_hours, l.owner_email, l.status,
         l.notes, l.created_at
  FROM public.engineer_weekend_ot_logs_r2526 l
  ORDER BY l.weekend_date DESC, l.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_ot_logs_r2526() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ot_logs_r2526() TO authenticated;

-- =========================================================================
-- RPC 2: list_fairness_metrics_r2526
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_fairness_metrics_r2526()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_start date,
  period_end date,
  total_weekends_worked int,
  total_premium_rupees bigint,
  fairness_target_hours numeric,
  fairness_actual_hours numeric,
  fairness_status text,
  refusal_count int,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.engineer_user_id, m.period_start, m.period_end,
         m.total_weekends_worked, m.total_premium_rupees,
         m.fairness_target_hours, m.fairness_actual_hours, m.fairness_status,
         m.refusal_count, m.status, m.notes, m.created_at
  FROM public.weekend_ot_fairness_metrics_r2526 m
  ORDER BY m.period_end DESC, m.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_fairness_metrics_r2526() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_fairness_metrics_r2526() TO authenticated;

-- =========================================================================
-- RPC 3: top_over_quota_engineers_r2526
-- =========================================================================
CREATE OR REPLACE FUNCTION public.top_over_quota_engineers_r2526()
RETURNS TABLE (
  engineer_user_id uuid,
  total_weekends_worked int,
  fairness_actual_hours numeric,
  fairness_target_hours numeric,
  delta_hours numeric,
  fairness_status text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.engineer_user_id,
         m.total_weekends_worked,
         m.fairness_actual_hours,
         m.fairness_target_hours,
         (m.fairness_actual_hours - m.fairness_target_hours)::numeric AS delta_hours,
         m.fairness_status,
         m.status
  FROM public.weekend_ot_fairness_metrics_r2526 m
  WHERE m.fairness_status = 'over'
  ORDER BY (m.fairness_actual_hours - m.fairness_target_hours) DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_over_quota_engineers_r2526() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_over_quota_engineers_r2526() TO authenticated;

-- =========================================================================
-- RPC 4: refusal_breakdown_r2526
-- =========================================================================
CREATE OR REPLACE FUNCTION public.refusal_breakdown_r2526()
RETURNS TABLE (
  refusal_reason_kind text,
  refusal_count bigint,
  pct_of_refusals numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_total
  FROM public.engineer_weekend_ot_logs_r2526
  WHERE refusal_reason_kind <> 'none';

  RETURN QUERY
  SELECT l.refusal_reason_kind,
         COUNT(*)::bigint AS refusal_count,
         CASE WHEN v_total > 0
              THEN ROUND((COUNT(*)::numeric / v_total) * 100, 2)
              ELSE 0::numeric END AS pct_of_refusals
  FROM public.engineer_weekend_ot_logs_r2526 l
  WHERE l.refusal_reason_kind <> 'none'
  GROUP BY l.refusal_reason_kind
  ORDER BY refusal_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.refusal_breakdown_r2526() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refusal_breakdown_r2526() TO authenticated;

-- =========================================================================
-- RPC 5: weekly_premium_trend_r2526
-- =========================================================================
CREATE OR REPLACE FUNCTION public.weekly_premium_trend_r2526()
RETURNS TABLE (
  week_start date,
  total_premium_rupees bigint,
  total_hours numeric,
  log_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', l.weekend_date)::date AS week_start,
         COALESCE(SUM(l.premium_rupees), 0)::bigint AS total_premium_rupees,
         COALESCE(SUM(l.hours_worked), 0)::numeric AS total_hours,
         COUNT(*)::bigint AS log_count
  FROM public.engineer_weekend_ot_logs_r2526 l
  WHERE l.status = 'approved'
  GROUP BY date_trunc('week', l.weekend_date)
  ORDER BY week_start DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_premium_trend_r2526() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_premium_trend_r2526() TO authenticated;

-- =========================================================================
-- RPC 6: fairness_distribution_r2526
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fairness_distribution_r2526()
RETURNS TABLE (
  fairness_status text,
  engineer_count bigint,
  avg_actual_hours numeric,
  avg_target_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.fairness_status,
         COUNT(*)::bigint AS engineer_count,
         ROUND(AVG(m.fairness_actual_hours)::numeric, 2) AS avg_actual_hours,
         ROUND(AVG(m.fairness_target_hours)::numeric, 2) AS avg_target_hours
  FROM public.weekend_ot_fairness_metrics_r2526 m
  GROUP BY m.fairness_status
  ORDER BY engineer_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fairness_distribution_r2526() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fairness_distribution_r2526() TO authenticated;

-- =========================================================================
-- RPC 7: zone_peer_comparison_r2526
-- =========================================================================
CREATE OR REPLACE FUNCTION public.zone_peer_comparison_r2526()
RETURNS TABLE (
  engineer_user_id uuid,
  avg_hours_worked numeric,
  avg_peer_hours numeric,
  avg_delta_hours numeric,
  log_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.engineer_user_id,
         ROUND(AVG(l.hours_worked)::numeric, 2) AS avg_hours_worked,
         ROUND(AVG(l.peer_avg_hours)::numeric, 2) AS avg_peer_hours,
         ROUND(AVG(l.fairness_delta_hours)::numeric, 2) AS avg_delta_hours,
         COUNT(*)::bigint AS log_count
  FROM public.engineer_weekend_ot_logs_r2526 l
  GROUP BY l.engineer_user_id
  ORDER BY avg_delta_hours DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.zone_peer_comparison_r2526() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.zone_peer_comparison_r2526() TO authenticated;

