BEGIN;

-- =====================================================================
-- Round 1722 — Founder Energy Audit Calendar
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_energy_audit_r1722 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_date date NOT NULL DEFAULT current_date,
  meeting_title text NOT NULL,
  meeting_duration_min int NOT NULL DEFAULT 30,
  energy_impact text NOT NULL CHECK (energy_impact IN ('drain','neutral','charge')),
  importance text NOT NULL CHECK (importance IN ('critical','important','optional')),
  attendee_emails text[] NOT NULL DEFAULT '{}',
  was_calendar_or_adhoc text NOT NULL CHECK (was_calendar_or_adhoc IN ('calendar','adhoc')),
  removable_next_time boolean NOT NULL DEFAULT false,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_energy_audit_r1722_date
  ON public.founder_energy_audit_r1722(audit_date DESC);
CREATE INDEX IF NOT EXISTS idx_founder_energy_audit_r1722_impact
  ON public.founder_energy_audit_r1722(energy_impact);

CREATE TABLE IF NOT EXISTS public.founder_energy_summary_r1722 (
  week_start date PRIMARY KEY,
  total_meetings int NOT NULL DEFAULT 0,
  drain_count int NOT NULL DEFAULT 0,
  charge_count int NOT NULL DEFAULT 0,
  neutral_count int NOT NULL DEFAULT 0,
  total_drain_min int NOT NULL DEFAULT 0,
  total_charge_min int NOT NULL DEFAULT 0,
  score int NOT NULL DEFAULT 0,
  recomputed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_energy_summary_r1722_week
  ON public.founder_energy_summary_r1722(week_start DESC);

ALTER TABLE public.founder_energy_audit_r1722 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_energy_summary_r1722 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1722_audit ON public.founder_energy_audit_r1722;
CREATE POLICY founder_all_r1722_audit ON public.founder_energy_audit_r1722
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1722_summary ON public.founder_energy_summary_r1722;
CREATE POLICY founder_all_r1722_summary ON public.founder_energy_summary_r1722
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_audits
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1722_list_audits();
CREATE OR REPLACE FUNCTION public.r1722_list_audits()
RETURNS TABLE (
  id uuid,
  audit_date date,
  meeting_title text,
  meeting_duration_min int,
  energy_impact text,
  importance text,
  attendee_emails text[],
  was_calendar_or_adhoc text,
  removable_next_time boolean,
  notes_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.audit_date, a.meeting_title, a.meeting_duration_min, a.energy_impact,
         a.importance, a.attendee_emails, a.was_calendar_or_adhoc, a.removable_next_time,
         a.notes_md, a.created_at
  FROM public.founder_energy_audit_r1722 a
  ORDER BY a.audit_date DESC, a.created_at DESC
  LIMIT 500;
END;
$$;

-- =====================================================================
-- RPC 2: log_audit (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1722_log_audit(date, text, int, text, text, text[], text, boolean, text);
CREATE OR REPLACE FUNCTION public.r1722_log_audit(
  p_audit_date date,
  p_meeting_title text,
  p_meeting_duration_min int,
  p_energy_impact text,
  p_importance text,
  p_attendee_emails text[],
  p_was_calendar_or_adhoc text,
  p_removable_next_time boolean,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.founder_energy_audit_r1722
    (audit_date, meeting_title, meeting_duration_min, energy_impact, importance,
     attendee_emails, was_calendar_or_adhoc, removable_next_time, notes_md)
  VALUES
    (COALESCE(p_audit_date, current_date), p_meeting_title, COALESCE(p_meeting_duration_min, 30),
     p_energy_impact, p_importance, COALESCE(p_attendee_emails, '{}'),
     p_was_calendar_or_adhoc, COALESCE(p_removable_next_time, false), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1722_log_audit',
    jsonb_build_object(
      'id', v_id,
      'meeting_title', p_meeting_title,
      'energy_impact', p_energy_impact,
      'importance', p_importance,
      'duration_min', p_meeting_duration_min
    )
  );

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_summaries
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1722_list_summaries();
CREATE OR REPLACE FUNCTION public.r1722_list_summaries()
RETURNS TABLE (
  week_start date,
  total_meetings int,
  drain_count int,
  charge_count int,
  neutral_count int,
  total_drain_min int,
  total_charge_min int,
  score int,
  recomputed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.week_start, s.total_meetings, s.drain_count, s.charge_count, s.neutral_count,
         s.total_drain_min, s.total_charge_min, s.score, s.recomputed_at
  FROM public.founder_energy_summary_r1722 s
  ORDER BY s.week_start DESC
  LIMIT 52;
END;
$$;

-- =====================================================================
-- RPC 4: recompute_summary (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1722_recompute_summary(date);
CREATE OR REPLACE FUNCTION public.r1722_recompute_summary(p_week_start date)
RETURNS date
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_drain int;
  v_charge int;
  v_neutral int;
  v_drain_min int;
  v_charge_min int;
  v_score int;
  v_week date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_week := date_trunc('week', COALESCE(p_week_start, current_date))::date;

  SELECT
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE energy_impact = 'drain'))::int,
    (COUNT(*) FILTER (WHERE energy_impact = 'charge'))::int,
    (COUNT(*) FILTER (WHERE energy_impact = 'neutral'))::int,
    COALESCE(SUM(meeting_duration_min) FILTER (WHERE energy_impact = 'drain'), 0)::int,
    COALESCE(SUM(meeting_duration_min) FILTER (WHERE energy_impact = 'charge'), 0)::int
  INTO v_total, v_drain, v_charge, v_neutral, v_drain_min, v_charge_min
  FROM public.founder_energy_audit_r1722
  WHERE audit_date >= v_week AND audit_date < v_week + INTERVAL '7 days';

  v_score := v_charge_min - v_drain_min;

  INSERT INTO public.founder_energy_summary_r1722
    (week_start, total_meetings, drain_count, charge_count, neutral_count,
     total_drain_min, total_charge_min, score, recomputed_at)
  VALUES (v_week, v_total, v_drain, v_charge, v_neutral, v_drain_min, v_charge_min, v_score, now())
  ON CONFLICT (week_start) DO UPDATE SET
    total_meetings = EXCLUDED.total_meetings,
    drain_count = EXCLUDED.drain_count,
    charge_count = EXCLUDED.charge_count,
    neutral_count = EXCLUDED.neutral_count,
    total_drain_min = EXCLUDED.total_drain_min,
    total_charge_min = EXCLUDED.total_charge_min,
    score = EXCLUDED.score,
    recomputed_at = now(),
    updated_at = now();

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1722_recompute_summary',
    jsonb_build_object(
      'week_start', v_week,
      'total_meetings', v_total,
      'score', v_score,
      'drain_min', v_drain_min,
      'charge_min', v_charge_min
    )
  );

  RETURN v_week;
END;
$$;

-- =====================================================================
-- RPC 5: removable_recurring_meetings
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1722_removable_recurring_meetings();
CREATE OR REPLACE FUNCTION public.r1722_removable_recurring_meetings()
RETURNS TABLE (
  meeting_title text,
  times_logged int,
  total_min int,
  drain_count int,
  avg_duration_min int,
  last_audit_date date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.meeting_title,
    COUNT(*)::int AS times_logged,
    COALESCE(SUM(a.meeting_duration_min), 0)::int AS total_min,
    (COUNT(*) FILTER (WHERE a.energy_impact = 'drain'))::int AS drain_count,
    COALESCE(AVG(a.meeting_duration_min), 0)::int AS avg_duration_min,
    MAX(a.audit_date) AS last_audit_date
  FROM public.founder_energy_audit_r1722 a
  WHERE a.removable_next_time = true
  GROUP BY a.meeting_title
  ORDER BY total_min DESC NULLS LAST
  LIMIT 100;
END;
$$;

-- =====================================================================
-- RPC 6: weekly_energy_score_trend
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1722_weekly_energy_score_trend();
CREATE OR REPLACE FUNCTION public.r1722_weekly_energy_score_trend()
RETURNS TABLE (
  week_start date,
  score int,
  total_drain_min int,
  total_charge_min int,
  total_meetings int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.week_start, s.score, s.total_drain_min, s.total_charge_min, s.total_meetings
  FROM public.founder_energy_summary_r1722 s
  ORDER BY s.week_start DESC
  LIMIT 26;
END;
$$;

-- =====================================================================
-- RPC 7: monthly_drain_top_offenders
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1722_monthly_drain_top_offenders();
CREATE OR REPLACE FUNCTION public.r1722_monthly_drain_top_offenders()
RETURNS TABLE (
  month_start date,
  meeting_title text,
  drain_count int,
  total_drain_min int,
  avg_duration_min int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', a.audit_date)::date AS month_start,
    a.meeting_title,
    COUNT(*)::int AS drain_count,
    COALESCE(SUM(a.meeting_duration_min), 0)::int AS total_drain_min,
    COALESCE(AVG(a.meeting_duration_min), 0)::int AS avg_duration_min
  FROM public.founder_energy_audit_r1722 a
  WHERE a.energy_impact = 'drain'
    AND a.audit_date >= (current_date - INTERVAL '90 days')
  GROUP BY date_trunc('month', a.audit_date), a.meeting_title
  ORDER BY month_start DESC, total_drain_min DESC NULLS LAST
  LIMIT 100;
END;
$$;

-- =====================================================================
-- REVOKE + GRANT
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.r1722_list_audits() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1722_log_audit(date, text, int, text, text, text[], text, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1722_list_summaries() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1722_recompute_summary(date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1722_removable_recurring_meetings() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1722_weekly_energy_score_trend() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1722_monthly_drain_top_offenders() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1722_list_audits() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1722_log_audit(date, text, int, text, text, text[], text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1722_list_summaries() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1722_recompute_summary(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1722_removable_recurring_meetings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1722_weekly_energy_score_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1722_monthly_drain_top_offenders() TO authenticated;

COMMIT;