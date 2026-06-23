-- Round 2605: Founder Weekly Team Coaching Investment
-- Track weekly coaching hours invested in team members, ROI, succession readiness, delegation lift.

BEGIN;

-- ============================================================
-- Table 1: founder_weekly_coaching_r2605
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_weekly_coaching_r2605 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  team_member_email text NOT NULL,
  hours_invested numeric(6,2) NOT NULL DEFAULT 0,
  coaching_kind text NOT NULL CHECK (coaching_kind IN ('skill','career','feedback','decision','wellbeing')),
  roi_estimate_rupees bigint NOT NULL DEFAULT 0,
  succession_readiness_pct int NOT NULL DEFAULT 0 CHECK (succession_readiness_pct >= 0 AND succession_readiness_pct <= 100),
  delegation_lift_pct numeric(6,2) NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwc_r2605_week ON public.founder_weekly_coaching_r2605(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_fwc_r2605_member ON public.founder_weekly_coaching_r2605(team_member_email);
CREATE INDEX IF NOT EXISTS idx_fwc_r2605_kind ON public.founder_weekly_coaching_r2605(coaching_kind);

ALTER TABLE public.founder_weekly_coaching_r2605 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.founder_weekly_coaching_r2605;
CREATE POLICY founder_all ON public.founder_weekly_coaching_r2605
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Table 2: coaching_succession_outcomes_r2605
-- ============================================================
CREATE TABLE IF NOT EXISTS public.coaching_succession_outcomes_r2605 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coaching_id uuid NOT NULL REFERENCES public.founder_weekly_coaching_r2605(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('promotion_ready','delegation_unlocked','no_change','regressed')),
  evidence_md text,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cso_r2605_coaching ON public.coaching_succession_outcomes_r2605(coaching_id);
CREATE INDEX IF NOT EXISTS idx_cso_r2605_observed ON public.coaching_succession_outcomes_r2605(observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_cso_r2605_outcome ON public.coaching_succession_outcomes_r2605(outcome_kind);

ALTER TABLE public.coaching_succession_outcomes_r2605 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.coaching_succession_outcomes_r2605;
CREATE POLICY founder_all ON public.coaching_succession_outcomes_r2605
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seed data
-- ============================================================
INSERT INTO public.founder_weekly_coaching_r2605
  (id, week_start, team_member_email, hours_invested, coaching_kind, roi_estimate_rupees, succession_readiness_pct, delegation_lift_pct, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101'::uuid, '2026-06-15', 'priya@equipseva.com', 4.50, 'skill', 250000, 65, 18.50, 'founder@equipseva.com', 'done', 'Compose deep-dive; ready to own engineer app v0.5 release'),
  ('11111111-1111-1111-1111-111111111102'::uuid, '2026-06-15', 'rahul@equipseva.com', 3.00, 'decision', 180000, 55, 12.00, 'founder@equipseva.com', 'done', 'Hospital chain pricing call; sole DRI now'),
  ('11111111-1111-1111-1111-111111111103'::uuid, '2026-06-15', 'anjali@equipseva.com', 2.25, 'career', 90000, 45, 8.00, 'founder@equipseva.com', 'done', 'IC to TL transition coaching; quarterly review prep'),
  ('11111111-1111-1111-1111-111111111104'::uuid, '2026-06-22', 'priya@equipseva.com', 2.00, 'feedback', 120000, 70, 22.00, 'founder@equipseva.com', 'planned', 'Mid-cycle 360 review delivery'),
  ('11111111-1111-1111-1111-111111111105'::uuid, '2026-06-22', 'vikram@equipseva.com', 1.50, 'wellbeing', 50000, 40, 5.00, 'founder@equipseva.com', 'planned', 'Burnout check-in; reset OKRs')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.coaching_succession_outcomes_r2605
  (coaching_id, observed_at, outcome_kind, evidence_md, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101'::uuid, now() - interval '2 days', 'promotion_ready', 'Shipped 3 design batches solo; zero founder edits', 'founder@equipseva.com', 'done', 'Promote to Staff Engineer next cycle'),
  ('11111111-1111-1111-1111-111111111102'::uuid, now() - interval '1 day', 'delegation_unlocked', 'Closed Apollo chain deal without founder on call', 'founder@equipseva.com', 'open', 'Monitor 2 more cycles'),
  ('11111111-1111-1111-1111-111111111103'::uuid, now() - interval '5 days', 'no_change', 'Still escalating low-stakes decisions weekly', 'founder@equipseva.com', 'open', 'Switch to decision coaching next week'),
  ('11111111-1111-1111-1111-111111111104'::uuid, now(), 'promotion_ready', 'Cross-team feedback unanimous: ready for Director', 'founder@equipseva.com', 'open', 'Confirm with board')
ON CONFLICT DO NOTHING;

-- ============================================================
-- RPC 1: list_coaching_r2605
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_coaching_r2605()
RETURNS TABLE (
  id uuid,
  week_start date,
  team_member_email text,
  hours_invested numeric,
  coaching_kind text,
  roi_estimate_rupees bigint,
  succession_readiness_pct int,
  delegation_lift_pct numeric,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.week_start, c.team_member_email, c.hours_invested, c.coaching_kind,
         c.roi_estimate_rupees, c.succession_readiness_pct, c.delegation_lift_pct,
         c.owner_email, c.status, c.notes, c.created_at
  FROM public.founder_weekly_coaching_r2605 c
  ORDER BY c.week_start DESC NULLS LAST, c.created_at DESC NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_coaching_r2605() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coaching_r2605() TO authenticated;

-- ============================================================
-- RPC 2: list_succession_outcomes_r2605
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_succession_outcomes_r2605()
RETURNS TABLE (
  id uuid,
  coaching_id uuid,
  team_member_email text,
  observed_at timestamptz,
  outcome_kind text,
  evidence_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.coaching_id, c.team_member_email, o.observed_at, o.outcome_kind,
         o.evidence_md, o.owner_email, o.status, o.notes, o.created_at
  FROM public.coaching_succession_outcomes_r2605 o
  LEFT JOIN public.founder_weekly_coaching_r2605 c ON c.id = o.coaching_id
  ORDER BY o.observed_at DESC NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_succession_outcomes_r2605() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_succession_outcomes_r2605() TO authenticated;

-- ============================================================
-- RPC 3: top_roi_coaching_r2605
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_roi_coaching_r2605()
RETURNS TABLE (
  team_member_email text,
  total_hours numeric,
  total_roi_rupees bigint,
  roi_per_hour numeric,
  avg_succession_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.team_member_email,
    COALESCE(SUM(c.hours_invested), 0)::numeric AS total_hours,
    COALESCE(SUM(c.roi_estimate_rupees), 0)::bigint AS total_roi_rupees,
    CASE WHEN COALESCE(SUM(c.hours_invested), 0) > 0
         THEN (COALESCE(SUM(c.roi_estimate_rupees), 0)::numeric / SUM(c.hours_invested))::numeric(14,2)
         ELSE 0::numeric END AS roi_per_hour,
    COALESCE(AVG(c.succession_readiness_pct), 0)::numeric(6,2) AS avg_succession_pct
  FROM public.founder_weekly_coaching_r2605 c
  GROUP BY c.team_member_email
  ORDER BY total_roi_rupees DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_roi_coaching_r2605() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_roi_coaching_r2605() TO authenticated;

-- ============================================================
-- RPC 4: kind_distribution_r2605
-- ============================================================
CREATE OR REPLACE FUNCTION public.kind_distribution_r2605()
RETURNS TABLE (
  coaching_kind text,
  session_count bigint,
  total_hours numeric,
  total_roi_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.coaching_kind,
    COUNT(*)::bigint AS session_count,
    COALESCE(SUM(c.hours_invested), 0)::numeric AS total_hours,
    COALESCE(SUM(c.roi_estimate_rupees), 0)::bigint AS total_roi_rupees
  FROM public.founder_weekly_coaching_r2605 c
  GROUP BY c.coaching_kind
  ORDER BY total_hours DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_distribution_r2605() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_distribution_r2605() TO authenticated;

-- ============================================================
-- RPC 5: succession_readiness_summary_r2605
-- ============================================================
CREATE OR REPLACE FUNCTION public.succession_readiness_summary_r2605()
RETURNS TABLE (
  team_member_email text,
  latest_readiness_pct int,
  latest_delegation_lift_pct numeric,
  promotion_ready_count bigint,
  delegation_unlocked_count bigint,
  no_change_count bigint,
  regressed_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (c.team_member_email)
      c.team_member_email, c.succession_readiness_pct, c.delegation_lift_pct
    FROM public.founder_weekly_coaching_r2605 c
    ORDER BY c.team_member_email ASC, c.week_start DESC NULLS LAST
  ),
  outcomes AS (
    SELECT c.team_member_email,
           COUNT(*) FILTER (WHERE o.outcome_kind = 'promotion_ready')::bigint AS promotion_ready,
           COUNT(*) FILTER (WHERE o.outcome_kind = 'delegation_unlocked')::bigint AS delegation_unlocked,
           COUNT(*) FILTER (WHERE o.outcome_kind = 'no_change')::bigint AS no_change,
           COUNT(*) FILTER (WHERE o.outcome_kind = 'regressed')::bigint AS regressed
    FROM public.coaching_succession_outcomes_r2605 o
    JOIN public.founder_weekly_coaching_r2605 c ON c.id = o.coaching_id
    GROUP BY c.team_member_email
  )
  SELECT
    l.team_member_email,
    l.succession_readiness_pct AS latest_readiness_pct,
    l.delegation_lift_pct AS latest_delegation_lift_pct,
    COALESCE(o.promotion_ready, 0) AS promotion_ready_count,
    COALESCE(o.delegation_unlocked, 0) AS delegation_unlocked_count,
    COALESCE(o.no_change, 0) AS no_change_count,
    COALESCE(o.regressed, 0) AS regressed_count
  FROM latest l
  LEFT JOIN outcomes o ON o.team_member_email = l.team_member_email
  ORDER BY l.succession_readiness_pct DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.succession_readiness_summary_r2605() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.succession_readiness_summary_r2605() TO authenticated;

-- ============================================================
-- RPC 6: weekly_investment_trend_r2605
-- ============================================================
CREATE OR REPLACE FUNCTION public.weekly_investment_trend_r2605()
RETURNS TABLE (
  week_start date,
  total_hours numeric,
  total_roi_rupees bigint,
  session_count bigint,
  avg_succession_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.week_start,
    COALESCE(SUM(c.hours_invested), 0)::numeric AS total_hours,
    COALESCE(SUM(c.roi_estimate_rupees), 0)::bigint AS total_roi_rupees,
    COUNT(*)::bigint AS session_count,
    COALESCE(AVG(c.succession_readiness_pct), 0)::numeric(6,2) AS avg_succession_pct
  FROM public.founder_weekly_coaching_r2605 c
  GROUP BY c.week_start
  ORDER BY c.week_start DESC NULLS LAST
  LIMIT 26;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_investment_trend_r2605() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_investment_trend_r2605() TO authenticated;

-- ============================================================
-- RPC 7: founder_pulse_summary_r2605
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2605()
RETURNS TABLE (
  total_sessions bigint,
  total_hours numeric,
  total_roi_rupees bigint,
  unique_team_members bigint,
  avg_succession_pct numeric,
  avg_delegation_lift_pct numeric,
  promotion_ready_outcomes bigint,
  delegation_unlocked_outcomes bigint,
  planned_sessions bigint,
  done_sessions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM public.founder_weekly_coaching_r2605) AS total_sessions,
    (SELECT COALESCE(SUM(hours_invested), 0)::numeric FROM public.founder_weekly_coaching_r2605) AS total_hours,
    (SELECT COALESCE(SUM(roi_estimate_rupees), 0)::bigint FROM public.founder_weekly_coaching_r2605) AS total_roi_rupees,
    (SELECT COUNT(DISTINCT team_member_email)::bigint FROM public.founder_weekly_coaching_r2605) AS unique_team_members,
    (SELECT COALESCE(AVG(succession_readiness_pct), 0)::numeric(6,2) FROM public.founder_weekly_coaching_r2605) AS avg_succession_pct,
    (SELECT COALESCE(AVG(delegation_lift_pct), 0)::numeric(6,2) FROM public.founder_weekly_coaching_r2605) AS avg_delegation_lift_pct,
    (SELECT COUNT(*)::bigint FROM public.coaching_succession_outcomes_r2605 WHERE outcome_kind = 'promotion_ready') AS promotion_ready_outcomes,
    (SELECT COUNT(*)::bigint FROM public.coaching_succession_outcomes_r2605 WHERE outcome_kind = 'delegation_unlocked') AS delegation_unlocked_outcomes,
    (SELECT COUNT(*)::bigint FROM public.founder_weekly_coaching_r2605 WHERE status = 'planned') AS planned_sessions,
    (SELECT COUNT(*)::bigint FROM public.founder_weekly_coaching_r2605 WHERE status = 'done') AS done_sessions;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2605() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2605() TO authenticated;

