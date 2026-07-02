-- Round 2921 — Founder Quarterly Strategic Founder-Mental-Health & Burnout Index Tracker
-- HEAVY founder ops round

BEGIN;

-- =========================================
-- Table 1: founder_mental_health_checkins_r2921
-- =========================================
CREATE TABLE IF NOT EXISTS public.founder_mental_health_checkins_r2921 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  checkin_date date NOT NULL,
  quarter text NOT NULL,
  burnout_index numeric(5,2) NOT NULL,
  sleep_hours numeric(4,2) NOT NULL,
  stress_level int NOT NULL CHECK (stress_level BETWEEN 1 AND 10),
  energy_level int NOT NULL CHECK (energy_level BETWEEN 1 AND 10),
  focus_minutes int NOT NULL,
  exercise_minutes int NOT NULL,
  mood_label text NOT NULL,
  journal_excerpt text NOT NULL,
  recovery_action text NOT NULL
);

ALTER TABLE public.founder_mental_health_checkins_r2921 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_select_founder_2921a ON public.founder_mental_health_checkins_r2921;
CREATE POLICY p_select_founder_2921a ON public.founder_mental_health_checkins_r2921
  FOR SELECT TO authenticated USING (public.is_founder());

-- =========================================
-- Table 2: founder_burnout_risk_signals_r2921
-- =========================================
CREATE TABLE IF NOT EXISTS public.founder_burnout_risk_signals_r2921 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  signal_date date NOT NULL,
  quarter text NOT NULL,
  signal_kind text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  source_system text NOT NULL,
  description text NOT NULL,
  trigger_metric numeric(8,2) NOT NULL,
  threshold_metric numeric(8,2) NOT NULL,
  mitigation_owner text NOT NULL,
  mitigation_status text NOT NULL CHECK (mitigation_status IN ('open','in_progress','resolved','snoozed')),
  resolved_at timestamptz
);

ALTER TABLE public.founder_burnout_risk_signals_r2921 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_select_founder_2921b ON public.founder_burnout_risk_signals_r2921;
CREATE POLICY p_select_founder_2921b ON public.founder_burnout_risk_signals_r2921
  FOR SELECT TO authenticated USING (public.is_founder());

-- =========================================
-- Seed: checkins (16 rows)
-- =========================================
INSERT INTO public.founder_mental_health_checkins_r2921
  (checkin_date, quarter, burnout_index, sleep_hours, stress_level, energy_level, focus_minutes, exercise_minutes, mood_label, journal_excerpt, recovery_action)
VALUES
  ('2026-04-02'::date, 'Q2-2026', 42.50, 6.20, 7, 5, 180, 20, 'tense', 'AMC churn spike rattled morning', 'walk + no laptop after 9pm'),
  ('2026-04-09'::date, 'Q2-2026', 38.10, 6.80, 6, 6, 220, 30, 'steady', 'Cashfree KYC dragging', 'breathing 10min'),
  ('2026-04-16'::date, 'Q2-2026', 51.40, 5.50, 8, 4, 140, 0,  'frayed', 'back-to-back hospital escalations', 'block half-day off'),
  ('2026-04-23'::date, 'Q2-2026', 47.30, 6.00, 7, 5, 165, 15, 'irritable', 'engineer payout failure stack', 'meditation 15min'),
  ('2026-04-30'::date, 'Q2-2026', 33.20, 7.10, 5, 7, 240, 45, 'ok', 'shipped 3 audits this week', 'sauna sunday'),
  ('2026-05-07'::date, 'Q2-2026', 58.90, 5.10, 9, 3, 110, 0,  'depleted', 'investor data room blew up', 'cancel non-critical calls'),
  ('2026-05-14'::date, 'Q2-2026', 44.60, 6.30, 7, 5, 175, 25, 'tense', 'spare-parts supplier dispute', 'long walk 60min'),
  ('2026-05-21'::date, 'Q2-2026', 29.80, 7.40, 4, 8, 260, 50, 'energised', 'ship streak feels good', 'protect deep work block'),
  ('2026-05-28'::date, 'Q2-2026', 36.10, 6.90, 6, 6, 210, 35, 'steady', 'roadmap clear, exec aligned', 'date night'),
  ('2026-06-04'::date, 'Q2-2026', 49.70, 5.80, 8, 4, 150, 10, 'frayed', 'payout audit found 3 criticals', 'no calls after 6pm'),
  ('2026-06-11'::date, 'Q2-2026', 41.20, 6.50, 7, 5, 185, 20, 'tense', 'NABH cert delays piling', 'gym + sleep early'),
  ('2026-06-18'::date, 'Q2-2026', 34.40, 7.00, 5, 7, 225, 40, 'ok', 'r1000 milestone, momentum back', 'celebrate small win'),
  ('2026-01-08'::date, 'Q1-2026', 55.20, 5.40, 8, 4, 130, 5,  'depleted', 'launch week burnt me out', 'mandatory 2-day off'),
  ('2026-01-22'::date, 'Q1-2026', 46.70, 6.10, 7, 5, 170, 20, 'tense', 'first hospital outage', 'breathing twice daily'),
  ('2026-02-12'::date, 'Q1-2026', 37.50, 6.80, 6, 6, 215, 30, 'steady', 'cashflow stable again', 'reading 30min'),
  ('2026-03-05'::date, 'Q1-2026', 31.20, 7.20, 5, 7, 250, 45, 'energised', 'pilot signed up', 'long weekend');

-- =========================================
-- Seed: signals (18 rows)
-- =========================================
INSERT INTO public.founder_burnout_risk_signals_r2921
  (signal_date, quarter, signal_kind, severity, source_system, description, trigger_metric, threshold_metric, mitigation_owner, mitigation_status, resolved_at)
VALUES
  ('2026-04-03'::date, 'Q2-2026', 'sleep_deficit', 'high', 'fitness_tracker', '3 nights below 6h sleep', 5.40, 7.00, 'self', 'resolved', '2026-04-06 22:00'::timestamptz),
  ('2026-04-10'::date, 'Q2-2026', 'meeting_overload', 'medium', 'calendar', '34 meetings in 5 days', 34.00, 25.00, 'EA', 'resolved', '2026-04-12 18:00'::timestamptz),
  ('2026-04-17'::date, 'Q2-2026', 'incident_load', 'critical', 'founder_incidents', '4 p1 incidents in 48h', 4.00, 2.00, 'ops_lead', 'resolved', '2026-04-20 09:00'::timestamptz),
  ('2026-04-24'::date, 'Q2-2026', 'cashflow_stress', 'high', 'finance', 'runway dipped under 9 months', 8.40, 9.00, 'self', 'in_progress', NULL),
  ('2026-05-01'::date, 'Q2-2026', 'no_exercise', 'medium', 'fitness_tracker', '6 days zero exercise', 0.00, 90.00, 'self', 'resolved', '2026-05-04 19:00'::timestamptz),
  ('2026-05-08'::date, 'Q2-2026', 'investor_pressure', 'critical', 'crm', 'urgent investor follow-ups stacked', 7.00, 3.00, 'self', 'resolved', '2026-05-11 17:00'::timestamptz),
  ('2026-05-15'::date, 'Q2-2026', 'support_backlog', 'high', 'support', 'tickets > 48h SLA', 12.00, 5.00, 'support_lead', 'resolved', '2026-05-17 14:00'::timestamptz),
  ('2026-05-22'::date, 'Q2-2026', 'positive_streak', 'low', 'self_report', 'energy >= 8 four days in a row', 8.00, 6.00, 'self', 'resolved', '2026-05-22 20:00'::timestamptz),
  ('2026-05-29'::date, 'Q2-2026', 'deep_work_loss', 'medium', 'calendar', 'deep work blocks fragmented', 90.00, 180.00, 'EA', 'in_progress', NULL),
  ('2026-06-05'::date, 'Q2-2026', 'audit_overrun', 'high', 'audit', 'audit-fix sweep 14 bugs', 14.00, 5.00, 'eng_lead', 'resolved', '2026-06-08 11:00'::timestamptz),
  ('2026-06-12'::date, 'Q2-2026', 'late_nights', 'high', 'commits', '5 commits past midnight', 5.00, 2.00, 'self', 'in_progress', NULL),
  ('2026-06-19'::date, 'Q2-2026', 'family_time_low', 'medium', 'self_report', 'family hours below baseline', 4.00, 10.00, 'self', 'open', NULL),
  ('2026-01-09'::date, 'Q1-2026', 'launch_crunch', 'critical', 'release', 'launch week 80h logged', 80.00, 55.00, 'self', 'resolved', '2026-01-15 18:00'::timestamptz),
  ('2026-01-23'::date, 'Q1-2026', 'hospital_outage', 'critical', 'incidents', 'first p0 in production', 1.00, 0.00, 'ops_lead', 'resolved', '2026-01-24 04:00'::timestamptz),
  ('2026-02-13'::date, 'Q1-2026', 'cashflow_relief', 'low', 'finance', 'first revenue month closed', 1.00, 1.00, 'self', 'resolved', '2026-02-13 23:00'::timestamptz),
  ('2026-03-06'::date, 'Q1-2026', 'pilot_signed', 'low', 'crm', 'first pilot signed', 1.00, 1.00, 'self', 'resolved', '2026-03-06 19:00'::timestamptz),
  ('2026-03-19'::date, 'Q1-2026', 'sleep_recovery', 'low', 'fitness_tracker', '7 nights >= 7h sleep', 7.20, 7.00, 'self', 'resolved', '2026-03-19 22:00'::timestamptz),
  ('2026-03-27'::date, 'Q1-2026', 'travel_fatigue', 'medium', 'calendar', 'three city trip in a week', 3.00, 1.00, 'EA', 'snoozed', NULL);

-- =========================================
-- RPC 1: burnout index timeline
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_burnout_timeline()
RETURNS TABLE (
  checkin_date date,
  quarter text,
  burnout_index numeric,
  stress_level int,
  energy_level int,
  mood_label text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT c.checkin_date, c.quarter, c.burnout_index, c.stress_level, c.energy_level, c.mood_label
  FROM public.founder_mental_health_checkins_r2921 c
  ORDER BY c.checkin_date DESC;
END;
$$;

-- =========================================
-- RPC 2: quarterly summary
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_quarterly_summary()
RETURNS TABLE (
  quarter text,
  checkins_count bigint,
  avg_burnout numeric,
  avg_sleep numeric,
  avg_stress numeric,
  avg_energy numeric,
  total_focus_min bigint,
  total_exercise_min bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT c.quarter,
         count(*)::bigint,
         round(avg(c.burnout_index)::numeric, 2),
         round(avg(c.sleep_hours)::numeric, 2),
         round(avg(c.stress_level)::numeric, 2),
         round(avg(c.energy_level)::numeric, 2),
         sum(c.focus_minutes)::bigint,
         sum(c.exercise_minutes)::bigint
  FROM public.founder_mental_health_checkins_r2921 c
  GROUP BY c.quarter
  ORDER BY c.quarter DESC;
END;
$$;

-- =========================================
-- RPC 3: open burnout signals
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_open_signals()
RETURNS TABLE (
  signal_date date,
  signal_kind text,
  severity text,
  source_system text,
  description text,
  trigger_metric numeric,
  threshold_metric numeric,
  mitigation_owner text,
  mitigation_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT s.signal_date, s.signal_kind, s.severity, s.source_system, s.description,
         s.trigger_metric, s.threshold_metric, s.mitigation_owner, s.mitigation_status
  FROM public.founder_burnout_risk_signals_r2921 s
  WHERE s.mitigation_status IN ('open','in_progress')
  ORDER BY
    CASE s.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    s.signal_date DESC;
END;
$$;

-- =========================================
-- RPC 4: signal severity rollup
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_signal_severity_rollup()
RETURNS TABLE (
  severity text,
  signals_total bigint,
  open_count bigint,
  resolved_count bigint,
  avg_overshoot numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT s.severity,
         count(*)::bigint,
         count(*) FILTER (WHERE s.mitigation_status IN ('open','in_progress'))::bigint,
         count(*) FILTER (WHERE s.mitigation_status = 'resolved')::bigint,
         round(avg(s.trigger_metric - s.threshold_metric)::numeric, 2)
  FROM public.founder_burnout_risk_signals_r2921 s
  GROUP BY s.severity
  ORDER BY
    CASE s.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;

-- =========================================
-- RPC 5: sleep vs burnout correlation buckets
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_sleep_burnout_buckets()
RETURNS TABLE (
  sleep_bucket text,
  checkins bigint,
  avg_burnout numeric,
  avg_focus_min numeric,
  avg_energy numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN c.sleep_hours < 6 THEN 'lt_6h'
      WHEN c.sleep_hours < 7 THEN '6_7h'
      WHEN c.sleep_hours < 8 THEN '7_8h'
      ELSE 'gte_8h'
    END AS sleep_bucket,
    count(*)::bigint,
    round(avg(c.burnout_index)::numeric, 2),
    round(avg(c.focus_minutes)::numeric, 2),
    round(avg(c.energy_level)::numeric, 2)
  FROM public.founder_mental_health_checkins_r2921 c
  GROUP BY 1
  ORDER BY 1;
END;
$$;

-- =========================================
-- RPC 6: mood distribution
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_mood_distribution()
RETURNS TABLE (
  mood_label text,
  occurrences bigint,
  avg_burnout numeric,
  avg_stress numeric,
  last_seen date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT c.mood_label,
         count(*)::bigint,
         round(avg(c.burnout_index)::numeric, 2),
         round(avg(c.stress_level)::numeric, 2),
         max(c.checkin_date)
  FROM public.founder_mental_health_checkins_r2921 c
  GROUP BY c.mood_label
  ORDER BY occurrences DESC;
END;
$$;

-- =========================================
-- RPC 7: recent recovery actions
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_recovery_log()
RETURNS TABLE (
  checkin_date date,
  mood_label text,
  burnout_index numeric,
  recovery_action text,
  journal_excerpt text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT c.checkin_date, c.mood_label, c.burnout_index, c.recovery_action, c.journal_excerpt
  FROM public.founder_mental_health_checkins_r2921 c
  ORDER BY c.checkin_date DESC
  LIMIT 12;
END;
$$;

-- =========================================
-- RPC 8: KPI summary
-- =========================================
CREATE OR REPLACE FUNCTION public.r2921_kpi_summary()
RETURNS TABLE (
  total_checkins bigint,
  current_burnout numeric,
  avg_burnout_90d numeric,
  open_signals bigint,
  critical_signals_total bigint,
  avg_sleep_90d numeric,
  avg_focus_min_90d numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::bigint FROM public.founder_mental_health_checkins_r2921),
    (SELECT c.burnout_index FROM public.founder_mental_health_checkins_r2921 c ORDER BY c.checkin_date DESC LIMIT 1),
    (SELECT round(avg(c.burnout_index)::numeric,2) FROM public.founder_mental_health_checkins_r2921 c WHERE c.checkin_date >= (now()::date - 90)),
    (SELECT count(*)::bigint FROM public.founder_burnout_risk_signals_r2921 WHERE mitigation_status IN ('open','in_progress')),
    (SELECT count(*)::bigint FROM public.founder_burnout_risk_signals_r2921 WHERE severity = 'critical'),
    (SELECT round(avg(c.sleep_hours)::numeric,2) FROM public.founder_mental_health_checkins_r2921 c WHERE c.checkin_date >= (now()::date - 90)),
    (SELECT round(avg(c.focus_minutes)::numeric,2) FROM public.founder_mental_health_checkins_r2921 c WHERE c.checkin_date >= (now()::date - 90));
END;
$$;

-- =========================================
-- Grants
-- =========================================
REVOKE EXECUTE ON FUNCTION public.r2921_burnout_timeline() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2921_quarterly_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2921_open_signals() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2921_signal_severity_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2921_sleep_burnout_buckets() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2921_mood_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2921_recovery_log() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2921_kpi_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2921_burnout_timeline() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2921_quarterly_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2921_open_signals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2921_signal_severity_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2921_sleep_burnout_buckets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2921_mood_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2921_recovery_log() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2921_kpi_summary() TO authenticated;

COMMIT;
