-- Round 2602: engineer supervisor feedback loop
-- Tracks weekly engineer x supervisor feedback signals + growth outcomes.

BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_supervisor_feedback_r2602 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  supervisor_email text NOT NULL,
  feedback_at timestamptz NOT NULL DEFAULT now(),
  signal_kind text NOT NULL CHECK (signal_kind IN ('praise','concern','coachable_moment','escalation','recognition')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  feedback_md text NOT NULL,
  growth_action_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esf_r2602_engineer ON public.engineer_supervisor_feedback_r2602(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_esf_r2602_signal ON public.engineer_supervisor_feedback_r2602(signal_kind);
CREATE INDEX IF NOT EXISTS idx_esf_r2602_status ON public.engineer_supervisor_feedback_r2602(status);
CREATE INDEX IF NOT EXISTS idx_esf_r2602_feedback_at ON public.engineer_supervisor_feedback_r2602(feedback_at DESC);

CREATE TABLE IF NOT EXISTS public.feedback_growth_outcomes_r2602 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid NOT NULL REFERENCES public.engineer_supervisor_feedback_r2602(id) ON DELETE CASCADE,
  outcome_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('improved','regressed','no_change','dropped')),
  measurement_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fgo_r2602_feedback ON public.feedback_growth_outcomes_r2602(feedback_id);
CREATE INDEX IF NOT EXISTS idx_fgo_r2602_outcome_at ON public.feedback_growth_outcomes_r2602(outcome_at DESC);

ALTER TABLE public.engineer_supervisor_feedback_r2602 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback_growth_outcomes_r2602 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_supervisor_feedback_r2602;
CREATE POLICY founder_all ON public.engineer_supervisor_feedback_r2602
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.feedback_growth_outcomes_r2602;
CREATE POLICY founder_all ON public.feedback_growth_outcomes_r2602
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_fb1 uuid;
  v_fb2 uuid;
  v_fb3 uuid;
  v_fb4 uuid;
  v_fb5 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  INSERT INTO public.engineer_supervisor_feedback_r2602
    (engineer_user_id, supervisor_email, feedback_at, signal_kind, severity, feedback_md, growth_action_md, owner_email, status, notes)
  VALUES
    (v_eng1, 'supervisor-north@equipseva.in', now() - interval '21 days', 'praise', 'low',
     'Closed 18 jobs in week with 4.9 CSAT. Strong AMC upsell discipline.',
     'Nominate for Tier-1 promotion review next quarter.',
     'founder@equipseva.in', 'closed', 'Lead by example case study.')
  RETURNING id INTO v_fb1;

  INSERT INTO public.engineer_supervisor_feedback_r2602
    (engineer_user_id, supervisor_email, feedback_at, signal_kind, severity, feedback_md, growth_action_md, owner_email, status, notes)
  VALUES
    (v_eng2, 'supervisor-south@equipseva.in', now() - interval '14 days', 'coachable_moment', 'medium',
     'Two repeat-visit jobs in week; root-cause skipped on first visit. Engineer rushed diagnostics.',
     'Pair with Tier-2 mentor for 5 jobs. Recheck after 2 weeks.',
     'ops-lead@equipseva.in', 'in_progress', 'Mentor pairing started 2026-06-14.')
  RETURNING id INTO v_fb2;

  INSERT INTO public.engineer_supervisor_feedback_r2602
    (engineer_user_id, supervisor_email, feedback_at, signal_kind, severity, feedback_md, growth_action_md, owner_email, status, notes)
  VALUES
    (v_eng3, 'supervisor-east@equipseva.in', now() - interval '10 days', 'concern', 'high',
     'Customer complaint: rude on call, missed promised ETA twice. Hospital flagged escalation.',
     'Soft-skills coaching session + apology call to hospital admin. 30-day probation.',
     'founder@equipseva.in', 'in_progress', 'Apology call done; coaching scheduled.')
  RETURNING id INTO v_fb3;

  INSERT INTO public.engineer_supervisor_feedback_r2602
    (engineer_user_id, supervisor_email, feedback_at, signal_kind, severity, feedback_md, growth_action_md, owner_email, status, notes)
  VALUES
    (v_eng1, 'supervisor-north@equipseva.in', now() - interval '5 days', 'recognition', 'low',
     'Volunteered weekend code-red coverage. Saved P0 ventilator down.',
     'Spot bonus + public shoutout in town-hall.',
     'founder@equipseva.in', 'closed', 'Bonus paid via Cashfree.')
  RETURNING id INTO v_fb4;

  INSERT INTO public.engineer_supervisor_feedback_r2602
    (engineer_user_id, supervisor_email, feedback_at, signal_kind, severity, feedback_md, growth_action_md, owner_email, status, notes)
  VALUES
    (v_eng2, 'supervisor-south@equipseva.in', now() - interval '2 days', 'escalation', 'critical',
     'Hospital admin called founder directly: engineer no-showed on AMC visit, no comms. Trust at risk.',
     'Founder skip-level with engineer. Final written warning. Reassign account.',
     'founder@equipseva.in', 'open', 'Skip-level scheduled tomorrow.')
  RETURNING id INTO v_fb5;

  -- Outcomes
  INSERT INTO public.feedback_growth_outcomes_r2602
    (feedback_id, outcome_at, outcome_kind, measurement_md, owner_email, status, notes)
  VALUES
    (v_fb1, now() - interval '7 days', 'improved', 'CSAT held at 4.9; Tier-1 review approved.', 'founder@equipseva.in', 'done', 'Promotion locked.'),
    (v_fb2, now() - interval '3 days', 'improved', 'Zero repeat visits in last 5 jobs. Root-cause discipline holding.', 'ops-lead@equipseva.in', 'open', 'Continue mentor pairing 2 more weeks.'),
    (v_fb3, now() - interval '1 days', 'no_change', 'Apology call accepted but engineer still missed one ETA. Coaching not yet started.', 'founder@equipseva.in', 'open', 'Coaching this week.'),
    (v_fb4, now() - interval '2 days', 'improved', 'Engineer volunteered again. Sustained recognition behaviour.', 'founder@equipseva.in', 'done', 'Bonus + shoutout effective.'),
    (v_fb5, now() - interval '1 days', 'regressed', 'Second no-show reported same week. Termination conversation queued.', 'founder@equipseva.in', 'open', 'HR loop in.');
END
$seed$;

-- RPC 1: list feedback
CREATE OR REPLACE FUNCTION public.list_feedback_r2602()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  supervisor_email text,
  feedback_at timestamptz,
  signal_kind text,
  severity text,
  feedback_md text,
  growth_action_md text,
  owner_email text,
  status text,
  notes text,
  days_open integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    f.engineer_user_id,
    f.supervisor_email,
    f.feedback_at,
    f.signal_kind,
    f.severity,
    f.feedback_md,
    f.growth_action_md,
    f.owner_email,
    f.status,
    f.notes,
    GREATEST(0, EXTRACT(DAY FROM (now() - f.feedback_at))::integer) AS days_open
  FROM public.engineer_supervisor_feedback_r2602 f
  ORDER BY f.feedback_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_feedback_r2602() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_feedback_r2602() TO authenticated;

-- RPC 2: list growth outcomes
CREATE OR REPLACE FUNCTION public.list_growth_outcomes_r2602()
RETURNS TABLE (
  id uuid,
  feedback_id uuid,
  signal_kind text,
  severity text,
  feedback_excerpt text,
  outcome_at timestamptz,
  outcome_kind text,
  measurement_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.feedback_id,
    f.signal_kind,
    f.severity,
    LEFT(f.feedback_md, 80) AS feedback_excerpt,
    o.outcome_at,
    o.outcome_kind,
    o.measurement_md,
    o.owner_email,
    o.status,
    o.notes
  FROM public.feedback_growth_outcomes_r2602 o
  JOIN public.engineer_supervisor_feedback_r2602 f ON f.id = o.feedback_id
  ORDER BY o.outcome_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_growth_outcomes_r2602() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_growth_outcomes_r2602() TO authenticated;

-- RPC 3: top concern focus
CREATE OR REPLACE FUNCTION public.top_concern_focus_r2602()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  feedback_at timestamptz,
  signal_kind text,
  severity text,
  feedback_md text,
  growth_action_md text,
  status text,
  days_open integer,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    f.engineer_user_id,
    f.feedback_at,
    f.signal_kind,
    f.severity,
    f.feedback_md,
    f.growth_action_md,
    f.status,
    GREATEST(0, EXTRACT(DAY FROM (now() - f.feedback_at))::integer) AS days_open,
    f.owner_email
  FROM public.engineer_supervisor_feedback_r2602 f
  WHERE f.status IN ('open','in_progress')
    AND f.signal_kind IN ('concern','escalation','coachable_moment')
  ORDER BY
    CASE f.severity
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END ASC,
    f.feedback_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_concern_focus_r2602() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_concern_focus_r2602() TO authenticated;

-- RPC 4: signal kind breakdown
CREATE OR REPLACE FUNCTION public.signal_kind_breakdown_r2602()
RETURNS TABLE (
  signal_kind text,
  total_count integer,
  critical_count integer,
  high_count integer,
  open_count integer,
  closed_count integer,
  improved_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.signal_kind,
    COUNT(*)::integer AS total_count,
    COUNT(*) FILTER (WHERE f.severity = 'critical')::integer AS critical_count,
    COUNT(*) FILTER (WHERE f.severity = 'high')::integer AS high_count,
    COUNT(*) FILTER (WHERE f.status IN ('open','in_progress'))::integer AS open_count,
    COUNT(*) FILTER (WHERE f.status = 'closed')::integer AS closed_count,
    (SELECT COUNT(*)::integer FROM public.feedback_growth_outcomes_r2602 o
       JOIN public.engineer_supervisor_feedback_r2602 f2 ON f2.id = o.feedback_id
       WHERE f2.signal_kind = f.signal_kind AND o.outcome_kind = 'improved') AS improved_count
  FROM public.engineer_supervisor_feedback_r2602 f
  GROUP BY f.signal_kind
  ORDER BY total_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.signal_kind_breakdown_r2602() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signal_kind_breakdown_r2602() TO authenticated;

-- RPC 5: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2602()
RETURNS TABLE (
  status text,
  feedback_count integer,
  critical_count integer,
  high_count integer,
  oldest_days integer,
  newest_days integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.status,
    COUNT(*)::integer AS feedback_count,
    COUNT(*) FILTER (WHERE f.severity = 'critical')::integer AS critical_count,
    COUNT(*) FILTER (WHERE f.severity = 'high')::integer AS high_count,
    COALESCE(MAX(EXTRACT(DAY FROM (now() - f.feedback_at))::integer), 0) AS oldest_days,
    COALESCE(MIN(EXTRACT(DAY FROM (now() - f.feedback_at))::integer), 0) AS newest_days
  FROM public.engineer_supervisor_feedback_r2602 f
  GROUP BY f.status
  ORDER BY
    CASE f.status
      WHEN 'open' THEN 1
      WHEN 'in_progress' THEN 2
      WHEN 'closed' THEN 3
      WHEN 'dropped' THEN 4
      ELSE 5
    END ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2602() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2602() TO authenticated;

-- RPC 6: monthly feedback trend
CREATE OR REPLACE FUNCTION public.monthly_feedback_trend_r2602()
RETURNS TABLE (
  month_start date,
  feedback_count integer,
  praise_count integer,
  concern_count integer,
  escalation_count integer,
  critical_count integer,
  improved_outcomes integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', f.feedback_at)::date AS month_start,
    COUNT(*)::integer AS feedback_count,
    COUNT(*) FILTER (WHERE f.signal_kind = 'praise')::integer AS praise_count,
    COUNT(*) FILTER (WHERE f.signal_kind = 'concern')::integer AS concern_count,
    COUNT(*) FILTER (WHERE f.signal_kind = 'escalation')::integer AS escalation_count,
    COUNT(*) FILTER (WHERE f.severity = 'critical')::integer AS critical_count,
    (SELECT COUNT(*)::integer FROM public.feedback_growth_outcomes_r2602 o
       JOIN public.engineer_supervisor_feedback_r2602 f2 ON f2.id = o.feedback_id
       WHERE date_trunc('month', f2.feedback_at) = date_trunc('month', f.feedback_at)
         AND o.outcome_kind = 'improved') AS improved_outcomes
  FROM public.engineer_supervisor_feedback_r2602 f
  GROUP BY date_trunc('month', f.feedback_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_feedback_trend_r2602() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_feedback_trend_r2602() TO authenticated;

-- RPC 7: supervisor load
CREATE OR REPLACE FUNCTION public.supervisor_load_r2602()
RETURNS TABLE (
  supervisor_email text,
  feedback_count integer,
  praise_count integer,
  concern_count integer,
  escalation_count integer,
  open_count integer,
  closed_count integer,
  improved_outcomes integer,
  last_feedback_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.supervisor_email,
    COUNT(*)::integer AS feedback_count,
    COUNT(*) FILTER (WHERE f.signal_kind = 'praise')::integer AS praise_count,
    COUNT(*) FILTER (WHERE f.signal_kind = 'concern')::integer AS concern_count,
    COUNT(*) FILTER (WHERE f.signal_kind = 'escalation')::integer AS escalation_count,
    COUNT(*) FILTER (WHERE f.status IN ('open','in_progress'))::integer AS open_count,
    COUNT(*) FILTER (WHERE f.status = 'closed')::integer AS closed_count,
    (SELECT COUNT(*)::integer FROM public.feedback_growth_outcomes_r2602 o
       JOIN public.engineer_supervisor_feedback_r2602 f2 ON f2.id = o.feedback_id
       WHERE f2.supervisor_email = f.supervisor_email AND o.outcome_kind = 'improved') AS improved_outcomes,
    MAX(f.feedback_at) AS last_feedback_at
  FROM public.engineer_supervisor_feedback_r2602 f
  GROUP BY f.supervisor_email
  ORDER BY feedback_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.supervisor_load_r2602() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supervisor_load_r2602() TO authenticated;

