BEGIN;

-- Table 1: portfolio winner showcase entries (per-investor success stories)
CREATE TABLE IF NOT EXISTS founder_investor_portfolio_winners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_fund_stage text NOT NULL DEFAULT 'seed' CHECK (investor_fund_stage IN ('angel','pre_seed','seed','series_a','series_b','growth')),
  portfolio_company text NOT NULL,
  win_category text NOT NULL DEFAULT 'revenue_growth' CHECK (win_category IN ('revenue_growth','customer_win','market_move','product_launch','team_hire','strategic_partnership','exit')),
  win_headline text NOT NULL,
  win_summary text,
  win_metric_value numeric(18,2),
  win_metric_unit text DEFAULT 'rupees',
  win_metric_delta_pct numeric(10,2),
  win_observed_at timestamptz NOT NULL DEFAULT now(),
  source_url text,
  confidence_score numeric(4,2) DEFAULT 0.80 CHECK (confidence_score BETWEEN 0 AND 1),
  is_pitch_ready boolean NOT NULL DEFAULT false,
  pitch_rank int NOT NULL DEFAULT 0,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_finv_winners_investor ON founder_investor_portfolio_winners(investor_name);
CREATE INDEX IF NOT EXISTS idx_finv_winners_category ON founder_investor_portfolio_winners(win_category);
CREATE INDEX IF NOT EXISTS idx_finv_winners_observed ON founder_investor_portfolio_winners(win_observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_finv_winners_pitch ON founder_investor_portfolio_winners(is_pitch_ready, pitch_rank DESC);

ALTER TABLE founder_investor_portfolio_winners ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS finv_winners_founder_only ON founder_investor_portfolio_winners;
CREATE POLICY finv_winners_founder_only ON founder_investor_portfolio_winners FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: pitch-deck usage log (which winners pulled into which pitch)
CREATE TABLE IF NOT EXISTS founder_investor_pitch_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  winner_id uuid NOT NULL REFERENCES founder_investor_portfolio_winners(id) ON DELETE CASCADE,
  pitched_to_investor text NOT NULL,
  pitch_meeting_at timestamptz NOT NULL DEFAULT now(),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','positive','neutral','negative','followup','closed_won','closed_lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_finv_pitch_usage_winner ON founder_investor_pitch_usage(winner_id);
CREATE INDEX IF NOT EXISTS idx_finv_pitch_usage_meeting ON founder_investor_pitch_usage(pitch_meeting_at DESC);

ALTER TABLE founder_investor_pitch_usage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS finv_pitch_usage_founder_only ON founder_investor_pitch_usage;
CREATE POLICY finv_pitch_usage_founder_only ON founder_investor_pitch_usage FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============ READ RPCs (STABLE) ============

CREATE OR REPLACE FUNCTION rpc_founder_invwin_overview()
RETURNS TABLE(
  total_winners bigint,
  pitch_ready_count bigint,
  archived_count bigint,
  distinct_investors bigint,
  distinct_companies bigint,
  revenue_wins bigint,
  customer_wins bigint,
  market_moves bigint,
  exits bigint,
  total_revenue_signal numeric,
  avg_delta_pct numeric,
  max_delta_pct numeric,
  last_30d_wins bigint,
  last_90d_wins bigint,
  pitches_used bigint,
  positive_outcomes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH w AS (
    SELECT * FROM founder_investor_portfolio_winners
  ),
  pu AS (
    SELECT * FROM founder_investor_pitch_usage
  )
  SELECT
    (SELECT count(*) FROM w),
    (SELECT count(*) FROM w WHERE is_pitch_ready),
    (SELECT count(*) FROM w WHERE archived_at IS NOT NULL),
    (SELECT count(DISTINCT investor_name) FROM w),
    (SELECT count(DISTINCT portfolio_company) FROM w),
    (SELECT count(*) FROM w WHERE win_category='revenue_growth'),
    (SELECT count(*) FROM w WHERE win_category='customer_win'),
    (SELECT count(*) FROM w WHERE win_category='market_move'),
    (SELECT count(*) FROM w WHERE win_category='exit'),
    (SELECT coalesce(sum(win_metric_value),0) FROM w WHERE win_category='revenue_growth'),
    (SELECT coalesce(avg(win_metric_delta_pct),0) FROM w),
    (SELECT coalesce(max(win_metric_delta_pct),0) FROM w),
    (SELECT count(*) FROM w WHERE win_observed_at > now() - interval '30 days'),
    (SELECT count(*) FROM w WHERE win_observed_at > now() - interval '90 days'),
    (SELECT count(*) FROM pu),
    (SELECT count(*) FROM pu WHERE outcome IN ('positive','closed_won'));
END;$$;

CREATE OR REPLACE FUNCTION rpc_founder_invwin_top_winners(p_limit int DEFAULT 25)
RETURNS TABLE(
  id uuid,
  investor_name text,
  portfolio_company text,
  win_category text,
  win_headline text,
  win_metric_value numeric,
  win_metric_delta_pct numeric,
  win_observed_at timestamptz,
  is_pitch_ready boolean,
  pitch_rank int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.investor_name, w.portfolio_company, w.win_category, w.win_headline,
         w.win_metric_value, w.win_metric_delta_pct, w.win_observed_at, w.is_pitch_ready, w.pitch_rank
  FROM founder_investor_portfolio_winners w
  WHERE w.archived_at IS NULL
  ORDER BY w.is_pitch_ready DESC, w.pitch_rank DESC, w.win_observed_at DESC
  LIMIT greatest(1, least(p_limit, 200));
END;$$;

CREATE OR REPLACE FUNCTION rpc_founder_invwin_by_investor()
RETURNS TABLE(
  investor_name text,
  win_count bigint,
  pitch_ready bigint,
  total_metric numeric,
  avg_delta_pct numeric,
  latest_win_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.investor_name,
         count(*),
         count(*) FILTER (WHERE w.is_pitch_ready),
         coalesce(sum(w.win_metric_value),0),
         coalesce(avg(w.win_metric_delta_pct),0),
         max(w.win_observed_at)
  FROM founder_investor_portfolio_winners w
  WHERE w.archived_at IS NULL
  GROUP BY w.investor_name
  ORDER BY count(*) DESC, max(w.win_observed_at) DESC NULLS LAST
  LIMIT 50;
END;$$;

CREATE OR REPLACE FUNCTION rpc_founder_invwin_by_category()
RETURNS TABLE(
  win_category text,
  cnt bigint,
  pitch_ready bigint,
  avg_delta_pct numeric,
  latest_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.win_category, count(*), count(*) FILTER (WHERE w.is_pitch_ready),
         coalesce(avg(w.win_metric_delta_pct),0), max(w.win_observed_at)
  FROM founder_investor_portfolio_winners w
  WHERE w.archived_at IS NULL
  GROUP BY w.win_category
  ORDER BY count(*) DESC;
END;$$;

CREATE OR REPLACE FUNCTION rpc_founder_invwin_recent_pitches(p_limit int DEFAULT 25)
RETURNS TABLE(
  id uuid,
  winner_id uuid,
  pitched_to_investor text,
  pitch_meeting_at timestamptz,
  outcome text,
  win_headline text,
  investor_name text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT pu.id, pu.winner_id, pu.pitched_to_investor, pu.pitch_meeting_at, pu.outcome,
         w.win_headline, w.investor_name
  FROM founder_investor_pitch_usage pu
  JOIN founder_investor_portfolio_winners w ON w.id = pu.winner_id
  ORDER BY pu.pitch_meeting_at DESC
  LIMIT greatest(1, least(p_limit, 100));
END;$$;

CREATE OR REPLACE FUNCTION rpc_founder_invwin_pitch_outcomes()
RETURNS TABLE(
  outcome text,
  cnt bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM founder_investor_pitch_usage;
  RETURN QUERY
  SELECT pu.outcome, count(*),
         CASE WHEN total > 0 THEN round((count(*)::numeric / total) * 100, 2) ELSE 0 END
  FROM founder_investor_pitch_usage pu
  GROUP BY pu.outcome
  ORDER BY count(*) DESC;
END;$$;

CREATE OR REPLACE FUNCTION rpc_founder_invwin_monthly_trend()
RETURNS TABLE(
  bucket_month date,
  wins_logged bigint,
  pitch_ready_added bigint,
  pitches_held bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH wm AS (
    SELECT date_trunc('month', win_observed_at)::date AS m,
           count(*) AS wins,
           count(*) FILTER (WHERE is_pitch_ready) AS pr
    FROM founder_investor_portfolio_winners
    WHERE win_observed_at > now() - interval '12 months'
    GROUP BY 1
  ),
  pm AS (
    SELECT date_trunc('month', pitch_meeting_at)::date AS m,
           count(*) AS pitches
    FROM founder_investor_pitch_usage
    WHERE pitch_meeting_at > now() - interval '12 months'
    GROUP BY 1
  )
  SELECT coalesce(wm.m, pm.m), coalesce(wm.wins,0), coalesce(wm.pr,0), coalesce(pm.pitches,0)
  FROM wm FULL OUTER JOIN pm ON wm.m = pm.m
  ORDER BY 1 DESC;
END;$$;

-- ============ WRITE / LOG helpers (VOLATILE SECDEF) ============

CREATE OR REPLACE FUNCTION log_founder_invwin_create(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invwin.create', coalesce(p_payload,'{}'::jsonb), now());
END;$$;

CREATE OR REPLACE FUNCTION log_founder_invwin_mark_pitch_ready(p_winner_id uuid, p_rank int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invwin.mark_pitch_ready',
          jsonb_build_object('winner_id', p_winner_id, 'rank', p_rank), now());
END;$$;

CREATE OR REPLACE FUNCTION log_founder_invwin_archive(p_winner_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invwin.archive',
          jsonb_build_object('winner_id', p_winner_id, 'reason', p_reason), now());
END;$$;

CREATE OR REPLACE FUNCTION log_founder_invwin_record_pitch(p_winner_id uuid, p_investor text, p_outcome text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invwin.record_pitch',
          jsonb_build_object('winner_id', p_winner_id, 'investor', p_investor, 'outcome', p_outcome), now());
END;$$;

-- ============ GRANTS ============

REVOKE EXECUTE ON FUNCTION rpc_founder_invwin_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_invwin_top_winners(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_invwin_by_investor() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_invwin_by_category() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_invwin_recent_pitches(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_invwin_pitch_outcomes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_invwin_monthly_trend() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invwin_create(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invwin_mark_pitch_ready(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invwin_archive(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invwin_record_pitch(uuid, text, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_founder_invwin_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_invwin_top_winners(int) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_invwin_by_investor() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_invwin_by_category() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_invwin_recent_pitches(int) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_invwin_pitch_outcomes() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_invwin_monthly_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invwin_create(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invwin_mark_pitch_ready(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invwin_archive(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invwin_record_pitch(uuid, text, text) TO authenticated;

COMMIT;