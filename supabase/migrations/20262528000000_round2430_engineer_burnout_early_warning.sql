-- Round r2430: engineer-burnout-early-warning
-- Rolling-7d work hours x no-rest days x CSAT slip x cancellations x early intervention

BEGIN;

-- ============================================================
-- Table 1: engineer_burnout_signals_r2430
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_burnout_signals_r2430 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  signal_week_start date NOT NULL,
  hours_worked_7d numeric NOT NULL CHECK (hours_worked_7d >= 0),
  days_no_rest int NOT NULL CHECK (days_no_rest >= 0 AND days_no_rest <= 7),
  csat_slip_pct numeric NOT NULL CHECK (csat_slip_pct >= -100 AND csat_slip_pct <= 100),
  cancellations_count int NOT NULL CHECK (cancellations_count >= 0),
  miss_count int NOT NULL CHECK (miss_count >= 0),
  signal_score int NOT NULL CHECK (signal_score >= 0 AND signal_score <= 100),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  top_signal text NOT NULL,
  notes text
);

ALTER TABLE public.engineer_burnout_signals_r2430 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_burnout_signals_r2430;
CREATE POLICY founder_all ON public.engineer_burnout_signals_r2430
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Table 2: burnout_interventions_r2430
-- ============================================================
CREATE TABLE IF NOT EXISTS public.burnout_interventions_r2430 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  intervention_kind text NOT NULL CHECK (intervention_kind IN ('coaching','time_off','load_reduce','buddy_pairing','escalation')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  owner_email text NOT NULL,
  planned_action text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  closed_at timestamptz,
  closed_by_email text,
  notes text
);

ALTER TABLE public.burnout_interventions_r2430 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.burnout_interventions_r2430;
CREATE POLICY founder_all ON public.burnout_interventions_r2430
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seed data (uses real engineer ids from engineers table)
-- ============================================================
DO $seed$
DECLARE
  eng_ids uuid[];
  e1 uuid; e2 uuid; e3 uuid; e4 uuid; e5 uuid;
BEGIN
  SELECT array_agg(id) INTO eng_ids FROM (SELECT id FROM public.engineers ORDER BY created_at LIMIT 5) t;
  IF eng_ids IS NULL OR array_length(eng_ids, 1) < 1 THEN
    RAISE NOTICE 'No engineers found, skipping seed';
    RETURN;
  END IF;
  e1 := eng_ids[1];
  e2 := COALESCE(eng_ids[2], eng_ids[1]);
  e3 := COALESCE(eng_ids[3], eng_ids[1]);
  e4 := COALESCE(eng_ids[4], eng_ids[1]);
  e5 := COALESCE(eng_ids[5], eng_ids[1]);

  INSERT INTO public.engineer_burnout_signals_r2430
    (engineer_user_id, signal_week_start, hours_worked_7d, days_no_rest, csat_slip_pct, cancellations_count, miss_count, signal_score, severity, top_signal, notes)
  VALUES
    (e1, current_date - interval '7 days', 78.5, 7, 18.5, 4, 2, 88, 'critical', 'no_rest_7d', 'Pushed through full week with zero off days, CSAT dropped sharply'),
    (e2, current_date - interval '7 days', 66.0, 5, 9.0, 2, 1, 64, 'high', 'csat_slip', 'CSAT slipping after sustained 60+ hour weeks'),
    (e3, current_date - interval '7 days', 52.0, 3, 3.5, 1, 0, 38, 'medium', 'cancellations', 'Recent uptick in cancellations, mild fatigue'),
    (e4, current_date - interval '7 days', 41.5, 1, -1.0, 0, 0, 12, 'low', 'baseline', 'Healthy week, recovering well'),
    (e5, current_date - interval '14 days', 72.0, 6, 14.0, 3, 1, 76, 'high', 'hours_worked_7d', 'Second consecutive heavy week, action recommended');

  INSERT INTO public.burnout_interventions_r2430
    (engineer_user_id, intervention_kind, opened_at, owner_email, planned_action, status, outcome, follow_up_at, closed_at, closed_by_email, notes)
  VALUES
    (e1, 'time_off', now() - interval '2 days', 'ops-lead@equipseva.in', 'Mandatory 3-day off-cycle starting Monday', 'in_progress', 'pending', now() + interval '4 days', null, null, 'Critical case, owner monitoring daily'),
    (e2, 'load_reduce', now() - interval '5 days', 'ops-lead@equipseva.in', 'Cap at 5 jobs/day for 2 weeks', 'in_progress', 'positive', now() + interval '7 days', null, null, 'Early signs of recovery'),
    (e3, 'coaching', now() - interval '10 days', 'senior-eng@equipseva.in', 'Weekly 30-min coaching call', 'done', 'positive', null, now() - interval '2 days', 'senior-eng@equipseva.in', 'Engineer reported better pacing'),
    (e5, 'buddy_pairing', now() - interval '3 days', 'ops-lead@equipseva.in', 'Pair with senior engineer for next 5 jobs', 'open', 'pending', now() + interval '5 days', null, null, 'Buddy assigned'),
    (e1, 'escalation', now() - interval '1 day', 'founder@equipseva.in', 'Founder 1:1 to address chronic overload', 'open', 'pending', now() + interval '2 days', null, null, 'Escalated by ops lead');
END;
$seed$;

-- ============================================================
-- RPC 1: list_signals_r2430
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_signals_r2430()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  signal_week_start date,
  hours_worked_7d numeric,
  days_no_rest int,
  csat_slip_pct numeric,
  cancellations_count int,
  miss_count int,
  signal_score int,
  severity text,
  top_signal text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id,
         COALESCE(p.full_name, e.contact_name, 'Engineer ' || left(s.engineer_user_id::text, 8)) AS engineer_name,
         s.signal_week_start, s.hours_worked_7d, s.days_no_rest, s.csat_slip_pct,
         s.cancellations_count, s.miss_count, s.signal_score, s.severity,
         s.top_signal, s.notes
  FROM public.engineer_burnout_signals_r2430 s
  LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY s.signal_score DESC, s.signal_week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_signals_r2430() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_signals_r2430() TO authenticated;

-- ============================================================
-- RPC 2: list_interventions_r2430
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_interventions_r2430()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  intervention_kind text,
  opened_at timestamptz,
  owner_email text,
  planned_action text,
  status text,
  outcome text,
  follow_up_at timestamptz,
  closed_at timestamptz,
  closed_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id,
         COALESCE(p.full_name, e.contact_name, 'Engineer ' || left(i.engineer_user_id::text, 8)) AS engineer_name,
         i.intervention_kind, i.opened_at, i.owner_email, i.planned_action,
         i.status, i.outcome, i.follow_up_at, i.closed_at, i.closed_by_email, i.notes
  FROM public.burnout_interventions_r2430 i
  LEFT JOIN public.engineers e ON e.id = i.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY i.opened_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_interventions_r2430() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_interventions_r2430() TO authenticated;

-- ============================================================
-- RPC 3: top_burnout_engineers_r2430
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_burnout_engineers_r2430()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  latest_score int,
  latest_severity text,
  latest_top_signal text,
  latest_week_start date,
  hours_worked_7d numeric,
  days_no_rest int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.engineer_user_id)
         s.engineer_user_id,
         COALESCE(p.full_name, e.contact_name, 'Engineer ' || left(s.engineer_user_id::text, 8)) AS engineer_name,
         s.signal_score, s.severity, s.top_signal, s.signal_week_start,
         s.hours_worked_7d, s.days_no_rest
  FROM public.engineer_burnout_signals_r2430 s
  LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY s.engineer_user_id, s.signal_week_start DESC, s.signal_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_burnout_engineers_r2430() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_burnout_engineers_r2430() TO authenticated;

-- ============================================================
-- RPC 4: severity_breakdown_r2430
-- ============================================================
CREATE OR REPLACE FUNCTION public.severity_breakdown_r2430()
RETURNS TABLE (
  severity text,
  signal_count bigint,
  engineer_count bigint,
  avg_score numeric,
  avg_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.severity,
         count(*)::bigint AS signal_count,
         count(DISTINCT s.engineer_user_id)::bigint AS engineer_count,
         round(avg(s.signal_score)::numeric, 1) AS avg_score,
         round(avg(s.hours_worked_7d)::numeric, 1) AS avg_hours
  FROM public.engineer_burnout_signals_r2430 s
  GROUP BY s.severity
  ORDER BY CASE s.severity
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
    ELSE 5
  END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.severity_breakdown_r2430() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.severity_breakdown_r2430() TO authenticated;

-- ============================================================
-- RPC 5: intervention_outcome_summary_r2430
-- ============================================================
CREATE OR REPLACE FUNCTION public.intervention_outcome_summary_r2430()
RETURNS TABLE (
  intervention_kind text,
  total_count bigint,
  open_count bigint,
  in_progress_count bigint,
  done_count bigint,
  dropped_count bigint,
  positive_outcomes bigint,
  negative_outcomes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.intervention_kind,
         count(*)::bigint AS total_count,
         count(*) FILTER (WHERE i.status = 'open')::bigint AS open_count,
         count(*) FILTER (WHERE i.status = 'in_progress')::bigint AS in_progress_count,
         count(*) FILTER (WHERE i.status = 'done')::bigint AS done_count,
         count(*) FILTER (WHERE i.status = 'dropped')::bigint AS dropped_count,
         count(*) FILTER (WHERE i.outcome = 'positive')::bigint AS positive_outcomes,
         count(*) FILTER (WHERE i.outcome = 'negative')::bigint AS negative_outcomes
  FROM public.burnout_interventions_r2430 i
  GROUP BY i.intervention_kind
  ORDER BY total_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.intervention_outcome_summary_r2430() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.intervention_outcome_summary_r2430() TO authenticated;

-- ============================================================
-- RPC 6: weekly_score_trend_r2430
-- ============================================================
CREATE OR REPLACE FUNCTION public.weekly_score_trend_r2430()
RETURNS TABLE (
  signal_week_start date,
  signals_recorded bigint,
  engineers_tracked bigint,
  avg_score numeric,
  max_score int,
  critical_count bigint,
  high_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.signal_week_start,
         count(*)::bigint AS signals_recorded,
         count(DISTINCT s.engineer_user_id)::bigint AS engineers_tracked,
         round(avg(s.signal_score)::numeric, 1) AS avg_score,
         max(s.signal_score)::int AS max_score,
         count(*) FILTER (WHERE s.severity = 'critical')::bigint AS critical_count,
         count(*) FILTER (WHERE s.severity = 'high')::bigint AS high_count
  FROM public.engineer_burnout_signals_r2430 s
  GROUP BY s.signal_week_start
  ORDER BY s.signal_week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_score_trend_r2430() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_score_trend_r2430() TO authenticated;

-- ============================================================
-- RPC 7: this_week_focus_r2430
-- ============================================================
CREATE OR REPLACE FUNCTION public.this_week_focus_r2430()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  signal_score int,
  severity text,
  top_signal text,
  hours_worked_7d numeric,
  days_no_rest int,
  open_interventions bigint,
  recommended_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_user_id)
      s.engineer_user_id, s.signal_score, s.severity, s.top_signal,
      s.hours_worked_7d, s.days_no_rest
    FROM public.engineer_burnout_signals_r2430 s
    ORDER BY s.engineer_user_id, s.signal_week_start DESC
  ),
  open_ints AS (
    SELECT i.engineer_user_id, count(*)::bigint AS open_count
    FROM public.burnout_interventions_r2430 i
    WHERE i.status IN ('open','in_progress')
    GROUP BY i.engineer_user_id
  )
  SELECT l.engineer_user_id,
         COALESCE(p.full_name, e.contact_name, 'Engineer ' || left(l.engineer_user_id::text, 8)) AS engineer_name,
         l.signal_score, l.severity, l.top_signal, l.hours_worked_7d, l.days_no_rest,
         COALESCE(o.open_count, 0) AS open_interventions,
         CASE
           WHEN l.severity = 'critical' AND COALESCE(o.open_count, 0) = 0 THEN 'OPEN INTERVENTION NOW - mandatory time off'
           WHEN l.severity = 'critical' THEN 'Monitor active intervention - escalate if no recovery'
           WHEN l.severity = 'high' AND COALESCE(o.open_count, 0) = 0 THEN 'Load reduction + coaching this week'
           WHEN l.severity = 'high' THEN 'Continue active intervention'
           WHEN l.severity = 'medium' THEN 'Schedule check-in within 7 days'
           ELSE 'Healthy - maintain cadence'
         END AS recommended_action
  FROM latest l
  LEFT JOIN public.engineers e ON e.id = l.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  LEFT JOIN open_ints o ON o.engineer_user_id = l.engineer_user_id
  WHERE l.severity IN ('critical','high','medium')
  ORDER BY
    CASE l.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    l.signal_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.this_week_focus_r2430() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_focus_r2430() TO authenticated;

