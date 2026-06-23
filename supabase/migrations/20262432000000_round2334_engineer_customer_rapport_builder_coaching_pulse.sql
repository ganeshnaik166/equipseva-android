BEGIN;

-- Round 2334: Engineer customer-rapport-builder coaching pulse
-- Founder-only console for ranking engineers on customer rapport indicators
-- (CSAT, repeat-request rate, name-recall) plus coaching log

CREATE TABLE IF NOT EXISTS public.engineer_rapport_pulse_r2334 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pulse_window_start date NOT NULL,
  pulse_window_end date NOT NULL,
  csat_avg numeric(4,2),
  csat_responses int NOT NULL DEFAULT 0,
  repeat_request_count int NOT NULL DEFAULT 0,
  repeat_request_rate numeric(5,2),
  name_recall_count int NOT NULL DEFAULT 0,
  name_recall_rate numeric(5,2),
  rapport_score numeric(5,2),
  rapport_tier text NOT NULL DEFAULT 'developing' CHECK (rapport_tier IN ('exemplary','strong','developing','at_risk')),
  notes text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rapport_pulse_engineer_r2334
  ON public.engineer_rapport_pulse_r2334(engineer_user_id, pulse_window_end DESC);
CREATE INDEX IF NOT EXISTS idx_rapport_pulse_tier_r2334
  ON public.engineer_rapport_pulse_r2334(rapport_tier, rapport_score DESC);

ALTER TABLE public.engineer_rapport_pulse_r2334 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_rapport_pulse_r2334 ON public.engineer_rapport_pulse_r2334;
CREATE POLICY founder_all_rapport_pulse_r2334 ON public.engineer_rapport_pulse_r2334
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_rapport_coaching_log_r2334 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pulse_id uuid REFERENCES public.engineer_rapport_pulse_r2334(id) ON DELETE SET NULL,
  coach_email text NOT NULL,
  session_type text NOT NULL CHECK (session_type IN ('one_on_one','workshop','shadow_visit','call_review','written_feedback')),
  focus_area text NOT NULL CHECK (focus_area IN ('csat','repeat_request','name_recall','overall_warmth','escalation_handling')),
  observation text NOT NULL,
  action_committed text,
  follow_up_at date,
  outcome text CHECK (outcome IN ('pending','improved','no_change','regressed')),
  outcome_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rapport_coach_engineer_r2334
  ON public.engineer_rapport_coaching_log_r2334(engineer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rapport_coach_followup_r2334
  ON public.engineer_rapport_coaching_log_r2334(follow_up_at)
  WHERE outcome = 'pending' OR outcome IS NULL;

ALTER TABLE public.engineer_rapport_coaching_log_r2334 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_rapport_coach_r2334 ON public.engineer_rapport_coaching_log_r2334;
CREATE POLICY founder_all_rapport_coach_r2334 ON public.engineer_rapport_coaching_log_r2334
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: leaderboard of engineers by rapport score
CREATE OR REPLACE FUNCTION public.rapport_pulse_leaderboard_r2334(p_limit int DEFAULT 50)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  engineer_email text,
  rapport_score numeric,
  rapport_tier text,
  csat_avg numeric,
  csat_responses int,
  repeat_request_rate numeric,
  name_recall_rate numeric,
  pulse_window_end date,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (p.engineer_user_id)
    p.engineer_user_id,
    pr.full_name,
    pr.email,
    p.rapport_score,
    p.rapport_tier,
    p.csat_avg,
    p.csat_responses,
    p.repeat_request_rate,
    p.name_recall_rate,
    p.pulse_window_end,
    p.computed_at
  FROM public.engineer_rapport_pulse_r2334 p
  JOIN public.profiles pr ON pr.id = p.engineer_user_id
  ORDER BY p.engineer_user_id, p.pulse_window_end DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.rapport_pulse_leaderboard_r2334(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rapport_pulse_leaderboard_r2334(int) TO authenticated;

-- RPC 2: tier distribution
CREATE OR REPLACE FUNCTION public.rapport_pulse_tier_distribution_r2334()
RETURNS TABLE (
  rapport_tier text,
  engineer_count bigint,
  avg_rapport_score numeric,
  avg_csat numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (engineer_user_id)
      engineer_user_id, rapport_tier, rapport_score, csat_avg
    FROM public.engineer_rapport_pulse_r2334
    ORDER BY engineer_user_id, pulse_window_end DESC
  )
  SELECT l.rapport_tier,
         COUNT(*)::bigint,
         ROUND(AVG(l.rapport_score)::numeric, 2),
         ROUND(AVG(l.csat_avg)::numeric, 2)
  FROM latest l
  GROUP BY l.rapport_tier
  ORDER BY l.rapport_tier;
END;
$$;

REVOKE ALL ON FUNCTION public.rapport_pulse_tier_distribution_r2334() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rapport_pulse_tier_distribution_r2334() TO authenticated;

-- RPC 3: at-risk engineers needing coaching
CREATE OR REPLACE FUNCTION public.rapport_pulse_at_risk_r2334()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  engineer_email text,
  rapport_score numeric,
  csat_avg numeric,
  repeat_request_rate numeric,
  pulse_window_end date,
  open_coaching_sessions bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (engineer_user_id) *
    FROM public.engineer_rapport_pulse_r2334
    ORDER BY engineer_user_id, pulse_window_end DESC
  )
  SELECT l.engineer_user_id,
         pr.full_name,
         pr.email,
         l.rapport_score,
         l.csat_avg,
         l.repeat_request_rate,
         l.pulse_window_end,
         (SELECT COUNT(*) FROM public.engineer_rapport_coaching_log_r2334 c
          WHERE c.engineer_user_id = l.engineer_user_id
            AND (c.outcome IS NULL OR c.outcome = 'pending'))::bigint
  FROM latest l
  JOIN public.profiles pr ON pr.id = l.engineer_user_id
  WHERE l.rapport_tier = 'at_risk'
  ORDER BY l.rapport_score ASC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.rapport_pulse_at_risk_r2334() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rapport_pulse_at_risk_r2334() TO authenticated;

-- RPC 4: coaching log feed
CREATE OR REPLACE FUNCTION public.rapport_coaching_recent_r2334(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  coach_email text,
  session_type text,
  focus_area text,
  observation text,
  action_committed text,
  follow_up_at date,
  outcome text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, pr.full_name, c.coach_email,
         c.session_type, c.focus_area, c.observation, c.action_committed,
         c.follow_up_at, c.outcome, c.created_at
  FROM public.engineer_rapport_coaching_log_r2334 c
  JOIN public.profiles pr ON pr.id = c.engineer_user_id
  ORDER BY c.created_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.rapport_coaching_recent_r2334(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rapport_coaching_recent_r2334(int) TO authenticated;

-- RPC 5: focus area breakdown
CREATE OR REPLACE FUNCTION public.rapport_coaching_focus_breakdown_r2334()
RETURNS TABLE (
  focus_area text,
  session_count bigint,
  improved_count bigint,
  pending_count bigint,
  improvement_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.focus_area,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.outcome = 'improved')::bigint,
         COUNT(*) FILTER (WHERE c.outcome IS NULL OR c.outcome = 'pending')::bigint,
         ROUND(
           (COUNT(*) FILTER (WHERE c.outcome = 'improved')::numeric
            / NULLIF(COUNT(*) FILTER (WHERE c.outcome IS NOT NULL AND c.outcome <> 'pending'), 0)
           ) * 100, 2)
  FROM public.engineer_rapport_coaching_log_r2334 c
  GROUP BY c.focus_area
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.rapport_coaching_focus_breakdown_r2334() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rapport_coaching_focus_breakdown_r2334() TO authenticated;

-- RPC 6: log a new coaching session
CREATE OR REPLACE FUNCTION public.rapport_coaching_log_session_r2334(
  p_engineer uuid,
  p_session_type text,
  p_focus_area text,
  p_observation text,
  p_action_committed text DEFAULT NULL,
  p_follow_up_at date DEFAULT NULL,
  p_pulse_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_coach text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_coach := auth.jwt()->>'email';
  INSERT INTO public.engineer_rapport_coaching_log_r2334(
    engineer_user_id, pulse_id, coach_email, session_type, focus_area,
    observation, action_committed, follow_up_at, outcome
  ) VALUES (
    p_engineer, p_pulse_id, v_coach, p_session_type, p_focus_area,
    p_observation, p_action_committed, p_follow_up_at, 'pending'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.rapport_coaching_log_session_r2334(uuid, text, text, text, text, date, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rapport_coaching_log_session_r2334(uuid, text, text, text, text, date, uuid) TO authenticated;

-- RPC 7: mark coaching outcome
CREATE OR REPLACE FUNCTION public.rapport_coaching_mark_outcome_r2334(
  p_log_id uuid,
  p_outcome text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_outcome NOT IN ('pending','improved','no_change','regressed') THEN
    RAISE EXCEPTION 'invalid outcome';
  END IF;
  UPDATE public.engineer_rapport_coaching_log_r2334
     SET outcome = p_outcome,
         outcome_at = CASE WHEN p_outcome <> 'pending' THEN now() ELSE NULL END
   WHERE id = p_log_id;
END;
$$;

REVOKE ALL ON FUNCTION public.rapport_coaching_mark_outcome_r2334(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rapport_coaching_mark_outcome_r2334(uuid, text) TO authenticated;

COMMIT;
