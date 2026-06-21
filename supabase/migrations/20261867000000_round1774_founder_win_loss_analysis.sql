BEGIN;

-- ============================================================================
-- Round 1774 — Founder Win-Loss Analysis
-- Track every closed deal (won/lost/withdrawn) with reasons + competitor log.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_deal_outcomes_r1774 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  deal_value_rupees bigint NOT NULL DEFAULT 0,
  expected_close_date date,
  actual_close_date date,
  outcome text NOT NULL CHECK (outcome IN ('won','lost','withdrawn')),
  primary_reason text NOT NULL CHECK (primary_reason IN ('price','timing','competitor_chosen','no_budget','feature_gap','relationship','founder_pivot')),
  secondary_reason text,
  lessons_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fdo_r1774_hospital ON public.founder_deal_outcomes_r1774(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_fdo_r1774_outcome ON public.founder_deal_outcomes_r1774(outcome);
CREATE INDEX IF NOT EXISTS idx_fdo_r1774_reason ON public.founder_deal_outcomes_r1774(primary_reason);
CREATE INDEX IF NOT EXISTS idx_fdo_r1774_actual_close ON public.founder_deal_outcomes_r1774(actual_close_date);

CREATE TABLE IF NOT EXISTS public.founder_deal_competitor_log_r1774 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES public.founder_deal_outcomes_r1774(id) ON DELETE CASCADE,
  competitor_name text NOT NULL,
  competitor_offer_summary text,
  our_advantage text,
  their_advantage text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fdcl_r1774_deal ON public.founder_deal_competitor_log_r1774(deal_id);
CREATE INDEX IF NOT EXISTS idx_fdcl_r1774_competitor ON public.founder_deal_competitor_log_r1774(competitor_name);

ALTER TABLE public.founder_deal_outcomes_r1774 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_deal_competitor_log_r1774 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fdo_r1774 ON public.founder_deal_outcomes_r1774;
CREATE POLICY founder_all_fdo_r1774 ON public.founder_deal_outcomes_r1774
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fdcl_r1774 ON public.founder_deal_competitor_log_r1774;
CREATE POLICY founder_all_fdcl_r1774 ON public.founder_deal_competitor_log_r1774
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_deals_r1774
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_deals_r1774()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  deal_value_rupees bigint,
  expected_close_date date,
  actual_close_date date,
  outcome text,
  primary_reason text,
  secondary_reason text,
  competitor_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.hospital_user_id,
    p.email::text AS hospital_email,
    d.deal_value_rupees,
    d.expected_close_date,
    d.actual_close_date,
    d.outcome,
    d.primary_reason,
    d.secondary_reason,
    (SELECT COUNT(*) FROM public.founder_deal_competitor_log_r1774 c WHERE c.deal_id = d.id)::int AS competitor_count,
    d.created_at
  FROM public.founder_deal_outcomes_r1774 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  ORDER BY COALESCE(d.actual_close_date, d.expected_close_date, d.created_at::date) DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_deals_r1774() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_deals_r1774() TO authenticated;

-- ============================================================================
-- RPC 2: log_deal_outcome_r1774
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_deal_outcome_r1774(
  p_hospital_user_id uuid,
  p_deal_value_rupees bigint,
  p_expected_close_date date,
  p_actual_close_date date,
  p_outcome text,
  p_primary_reason text,
  p_secondary_reason text,
  p_lessons_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_deal_outcomes_r1774(
    hospital_user_id, deal_value_rupees, expected_close_date, actual_close_date,
    outcome, primary_reason, secondary_reason, lessons_md
  )
  VALUES (
    p_hospital_user_id, COALESCE(p_deal_value_rupees, 0), p_expected_close_date, p_actual_close_date,
    p_outcome, p_primary_reason, p_secondary_reason, p_lessons_md
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_deal_outcome_r1774',
    jsonb_build_object(
      'deal_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'outcome', p_outcome,
      'primary_reason', p_primary_reason,
      'deal_value_rupees', p_deal_value_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_deal_outcome_r1774(uuid, bigint, date, date, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_deal_outcome_r1774(uuid, bigint, date, date, text, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_competitors_r1774
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_competitors_r1774(p_deal_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  deal_id uuid,
  competitor_name text,
  competitor_offer_summary text,
  our_advantage text,
  their_advantage text,
  outcome text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.deal_id,
    c.competitor_name,
    c.competitor_offer_summary,
    c.our_advantage,
    c.their_advantage,
    d.outcome,
    c.created_at
  FROM public.founder_deal_competitor_log_r1774 c
  JOIN public.founder_deal_outcomes_r1774 d ON d.id = c.deal_id
  WHERE (p_deal_id IS NULL OR c.deal_id = p_deal_id)
  ORDER BY c.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_competitors_r1774(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_competitors_r1774(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_competitor_r1774
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_competitor_r1774(
  p_deal_id uuid,
  p_competitor_name text,
  p_competitor_offer_summary text,
  p_our_advantage text,
  p_their_advantage text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_deal_competitor_log_r1774(
    deal_id, competitor_name, competitor_offer_summary, our_advantage, their_advantage
  )
  VALUES (
    p_deal_id, p_competitor_name, p_competitor_offer_summary, p_our_advantage, p_their_advantage
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_competitor_r1774',
    jsonb_build_object(
      'competitor_log_id', v_id,
      'deal_id', p_deal_id,
      'competitor_name', p_competitor_name
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_competitor_r1774(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_competitor_r1774(uuid, text, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: reason_distribution_r1774
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reason_distribution_r1774()
RETURNS TABLE (
  primary_reason text,
  outcome text,
  deal_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.primary_reason,
    d.outcome,
    COUNT(*)::int AS deal_count,
    COALESCE(SUM(d.deal_value_rupees), 0)::bigint AS total_value_rupees
  FROM public.founder_deal_outcomes_r1774 d
  GROUP BY d.primary_reason, d.outcome
  ORDER BY d.primary_reason, d.outcome;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reason_distribution_r1774() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reason_distribution_r1774() TO authenticated;

-- ============================================================================
-- RPC 6: win_rate_summary_r1774
-- ============================================================================
CREATE OR REPLACE FUNCTION public.win_rate_summary_r1774()
RETURNS TABLE (
  total_deals int,
  won_deals int,
  lost_deals int,
  withdrawn_deals int,
  win_rate_pct numeric,
  won_value_rupees bigint,
  lost_value_rupees bigint,
  avg_won_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_won int;
  v_lost int;
  v_withdrawn int;
  v_won_val bigint;
  v_lost_val bigint;
  v_avg_won bigint;
  v_win_rate numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE outcome = 'won'))::int,
    (COUNT(*) FILTER (WHERE outcome = 'lost'))::int,
    (COUNT(*) FILTER (WHERE outcome = 'withdrawn'))::int,
    COALESCE(SUM(deal_value_rupees) FILTER (WHERE outcome = 'won'), 0)::bigint,
    COALESCE(SUM(deal_value_rupees) FILTER (WHERE outcome = 'lost'), 0)::bigint
  INTO v_total, v_won, v_lost, v_withdrawn, v_won_val, v_lost_val
  FROM public.founder_deal_outcomes_r1774;

  v_avg_won := CASE WHEN v_won > 0 THEN (v_won_val / v_won)::bigint ELSE 0 END;
  v_win_rate := CASE WHEN (v_won + v_lost) > 0 THEN ROUND(v_won::numeric * 100 / (v_won + v_lost), 2) ELSE 0 END;

  RETURN QUERY
  SELECT v_total, v_won, v_lost, v_withdrawn, v_win_rate, v_won_val, v_lost_val, v_avg_won;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.win_rate_summary_r1774() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.win_rate_summary_r1774() TO authenticated;

-- ============================================================================
-- RPC 7: top_competitors_r1774
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_competitors_r1774()
RETURNS TABLE (
  competitor_name text,
  encounter_count int,
  won_against int,
  lost_to int,
  deal_value_at_stake_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.competitor_name,
    COUNT(*)::int AS encounter_count,
    (COUNT(*) FILTER (WHERE d.outcome = 'won'))::int AS won_against,
    (COUNT(*) FILTER (WHERE d.outcome = 'lost' AND d.primary_reason = 'competitor_chosen'))::int AS lost_to,
    COALESCE(SUM(d.deal_value_rupees), 0)::bigint AS deal_value_at_stake_rupees
  FROM public.founder_deal_competitor_log_r1774 c
  JOIN public.founder_deal_outcomes_r1774 d ON d.id = c.deal_id
  GROUP BY c.competitor_name
  ORDER BY encounter_count DESC, lost_to DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_competitors_r1774() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_competitors_r1774() TO authenticated;

COMMIT;