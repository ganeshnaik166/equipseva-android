BEGIN;

-- =========================================================================
-- Round 1508 — Founder Strategic Bets Ledger
-- Capture quarterly strategic bets (cost, expected payoff, risk),
-- grade ex-post (win/loss/draw), and analyze winning-bet recipes.
-- =========================================================================

-- ---------------------------------------------------------------------------
-- Table 1: founder_strategic_bets — one row per quarterly bet
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_strategic_bets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,                  -- e.g. 'FY27-Q1'
  quarter_start_date date NOT NULL,
  quarter_end_date   date NOT NULL,
  bet_title text NOT NULL,
  bet_thesis text NOT NULL,                     -- why we're making this bet
  bet_category text NOT NULL DEFAULT 'product', -- product/market/ops/people/capital
  cost_rupees bigint NOT NULL DEFAULT 0,
  expected_payoff_rupees bigint NOT NULL DEFAULT 0,
  risk_level text NOT NULL DEFAULT 'medium',    -- low/medium/high/bet_the_company
  confidence_pct int NOT NULL DEFAULT 50,       -- 0..100
  success_criteria text NOT NULL,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'live',          -- live/graded/cancelled
  grade text,                                   -- win/loss/draw (NULL until graded)
  actual_payoff_rupees bigint,
  grade_notes text,
  graded_at timestamptz,
  graded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  recipe_tags text[] NOT NULL DEFAULT '{}',     -- e.g. {'small_team','customer_pull','pre_funded'}
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (confidence_pct BETWEEN 0 AND 100),
  CHECK (risk_level IN ('low','medium','high','bet_the_company')),
  CHECK (status IN ('live','graded','cancelled')),
  CHECK (grade IS NULL OR grade IN ('win','loss','draw')),
  CHECK (bet_category IN ('product','market','ops','people','capital'))
);

CREATE INDEX IF NOT EXISTS idx_fsb_quarter      ON public.founder_strategic_bets(quarter_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_fsb_status_grade ON public.founder_strategic_bets(status, grade);
CREATE INDEX IF NOT EXISTS idx_fsb_category     ON public.founder_strategic_bets(bet_category);

ALTER TABLE public.founder_strategic_bets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fsb_founder_only ON public.founder_strategic_bets;
CREATE POLICY fsb_founder_only ON public.founder_strategic_bets
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- Table 2: founder_strategic_bet_milestones — interim checkpoints per bet
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_strategic_bet_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id uuid NOT NULL REFERENCES public.founder_strategic_bets(id) ON DELETE CASCADE,
  milestone_label text NOT NULL,
  due_date date NOT NULL,
  hit boolean NOT NULL DEFAULT false,
  hit_at timestamptz,
  evidence_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsbm_bet ON public.founder_strategic_bet_milestones(bet_id);
CREATE INDEX IF NOT EXISTS idx_fsbm_due ON public.founder_strategic_bet_milestones(due_date);

ALTER TABLE public.founder_strategic_bet_milestones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fsbm_founder_only ON public.founder_strategic_bet_milestones;
CREATE POLICY fsbm_founder_only ON public.founder_strategic_bet_milestones
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- Helper logging functions (write to founder_action_log)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_founder_bet_created(
  p_bet_id uuid, p_title text, p_cost bigint, p_payoff bigint
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bet_created',
    jsonb_build_object('bet_id', p_bet_id, 'title', p_title, 'cost', p_cost, 'payoff', p_payoff));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_bet_created(uuid,text,bigint,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_bet_created(uuid,text,bigint,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_bet_graded(
  p_bet_id uuid, p_grade text, p_actual_payoff bigint
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bet_graded',
    jsonb_build_object('bet_id', p_bet_id, 'grade', p_grade, 'actual_payoff', p_actual_payoff));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_bet_graded(uuid,text,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_bet_graded(uuid,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_bet_milestone_hit(
  p_bet_id uuid, p_milestone_id uuid, p_label text
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bet_milestone_hit',
    jsonb_build_object('bet_id', p_bet_id, 'milestone_id', p_milestone_id, 'label', p_label));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_bet_milestone_hit(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_bet_milestone_hit(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_bet_cancelled(
  p_bet_id uuid, p_reason text
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bet_cancelled',
    jsonb_build_object('bet_id', p_bet_id, 'reason', p_reason));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_bet_cancelled(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_bet_cancelled(uuid,text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 1: founder_bets_overview — KPIs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bets_overview()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total int;
  v_live int;
  v_graded int;
  v_cancelled int;
  v_wins int;
  v_losses int;
  v_draws int;
  v_total_cost bigint;
  v_expected_payoff bigint;
  v_actual_payoff bigint;
  v_win_rate numeric;
  v_roi_pct numeric;
  v_avg_confidence numeric;
  v_bet_the_company int;
  v_quarter_count int;
  v_oldest_live_days numeric;
  v_milestones_total int;
  v_milestones_hit int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE status='live'),
         COUNT(*) FILTER (WHERE status='graded'),
         COUNT(*) FILTER (WHERE status='cancelled'),
         COUNT(*) FILTER (WHERE grade='win'),
         COUNT(*) FILTER (WHERE grade='loss'),
         COUNT(*) FILTER (WHERE grade='draw'),
         COALESCE(SUM(cost_rupees),0),
         COALESCE(SUM(expected_payoff_rupees),0),
         COALESCE(SUM(actual_payoff_rupees),0),
         COALESCE(AVG(confidence_pct),0),
         COUNT(*) FILTER (WHERE risk_level='bet_the_company')
    INTO v_total, v_live, v_graded, v_cancelled,
         v_wins, v_losses, v_draws,
         v_total_cost, v_expected_payoff, v_actual_payoff,
         v_avg_confidence, v_bet_the_company
    FROM public.founder_strategic_bets;

  v_win_rate := CASE WHEN v_graded > 0 THEN (v_wins::numeric * 100.0 / v_graded) ELSE 0 END;
  v_roi_pct  := CASE WHEN v_total_cost > 0 THEN ((v_actual_payoff - v_total_cost)::numeric * 100.0 / v_total_cost) ELSE 0 END;

  SELECT COUNT(DISTINCT quarter_label) INTO v_quarter_count FROM public.founder_strategic_bets;

  SELECT COALESCE(EXTRACT(EPOCH FROM (now() - MIN(created_at)))/86400.0, 0)
    INTO v_oldest_live_days
    FROM public.founder_strategic_bets WHERE status='live';

  SELECT COUNT(*), COUNT(*) FILTER (WHERE hit)
    INTO v_milestones_total, v_milestones_hit
    FROM public.founder_strategic_bet_milestones;

  RETURN jsonb_build_object(
    'total_bets', v_total,
    'live_bets', v_live,
    'graded_bets', v_graded,
    'cancelled_bets', v_cancelled,
    'wins', v_wins,
    'losses', v_losses,
    'draws', v_draws,
    'win_rate_pct', round(v_win_rate, 1),
    'total_cost_rupees', v_total_cost,
    'expected_payoff_rupees', v_expected_payoff,
    'actual_payoff_rupees', v_actual_payoff,
    'roi_pct', round(v_roi_pct, 1),
    'avg_confidence', round(v_avg_confidence, 1),
    'bet_the_company_count', v_bet_the_company,
    'quarters_tracked', v_quarter_count,
    'oldest_live_days', round(v_oldest_live_days, 1),
    'milestones_total', v_milestones_total,
    'milestones_hit', v_milestones_hit,
    'milestone_hit_rate_pct', CASE WHEN v_milestones_total > 0 THEN round(v_milestones_hit::numeric * 100.0 / v_milestones_total, 1) ELSE 0 END
  );
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_bets_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bets_overview() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: founder_bets_list — all bets, newest first
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bets_list()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  bet_title text,
  bet_category text,
  cost_rupees bigint,
  expected_payoff_rupees bigint,
  risk_level text,
  confidence_pct int,
  status text,
  grade text,
  actual_payoff_rupees bigint,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.quarter_label, b.bet_title, b.bet_category,
           b.cost_rupees, b.expected_payoff_rupees, b.risk_level,
           b.confidence_pct, b.status, b.grade, b.actual_payoff_rupees, b.created_at
      FROM public.founder_strategic_bets b
     ORDER BY b.quarter_start_date DESC, b.created_at DESC
     LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_bets_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bets_list() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: founder_bets_by_quarter — quarter rollup
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bets_by_quarter()
RETURNS TABLE (
  id text,
  quarter_label text,
  bet_count bigint,
  total_cost bigint,
  total_expected bigint,
  total_actual bigint,
  wins bigint,
  losses bigint,
  win_rate_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.quarter_label AS id,
           b.quarter_label,
           COUNT(*) AS bet_count,
           COALESCE(SUM(b.cost_rupees),0)::bigint AS total_cost,
           COALESCE(SUM(b.expected_payoff_rupees),0)::bigint AS total_expected,
           COALESCE(SUM(b.actual_payoff_rupees),0)::bigint AS total_actual,
           COUNT(*) FILTER (WHERE b.grade='win') AS wins,
           COUNT(*) FILTER (WHERE b.grade='loss') AS losses,
           CASE WHEN COUNT(*) FILTER (WHERE b.status='graded') > 0
                THEN round(COUNT(*) FILTER (WHERE b.grade='win')::numeric * 100.0
                           / COUNT(*) FILTER (WHERE b.status='graded'), 1)
                ELSE 0 END AS win_rate_pct
      FROM public.founder_strategic_bets b
     GROUP BY b.quarter_label
     ORDER BY b.quarter_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_bets_by_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bets_by_quarter() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: founder_bets_winning_recipes — tag analysis of winning bets
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bets_winning_recipes()
RETURNS TABLE (
  id text,
  recipe_tag text,
  win_count bigint,
  loss_count bigint,
  draw_count bigint,
  total_appearances bigint,
  win_rate_pct numeric,
  avg_roi_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH unnested AS (
      SELECT unnest(b.recipe_tags) AS tag, b.grade, b.cost_rupees, b.actual_payoff_rupees
        FROM public.founder_strategic_bets b
       WHERE b.status='graded'
    )
    SELECT u.tag AS id,
           u.tag AS recipe_tag,
           COUNT(*) FILTER (WHERE u.grade='win')  AS win_count,
           COUNT(*) FILTER (WHERE u.grade='loss') AS loss_count,
           COUNT(*) FILTER (WHERE u.grade='draw') AS draw_count,
           COUNT(*) AS total_appearances,
           round(COUNT(*) FILTER (WHERE u.grade='win')::numeric * 100.0 / NULLIF(COUNT(*),0), 1) AS win_rate_pct,
           round(AVG(CASE WHEN u.cost_rupees > 0
                          THEN (COALESCE(u.actual_payoff_rupees,0) - u.cost_rupees)::numeric * 100.0 / u.cost_rupees
                          ELSE 0 END), 1) AS avg_roi_pct
      FROM unnested u
     GROUP BY u.tag
     ORDER BY win_rate_pct DESC NULLS LAST, total_appearances DESC
     LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_bets_winning_recipes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bets_winning_recipes() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: founder_bets_by_category — category-level performance
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bets_by_category()
RETURNS TABLE (
  id text,
  bet_category text,
  bet_count bigint,
  wins bigint,
  losses bigint,
  win_rate_pct numeric,
  total_cost bigint,
  total_actual_payoff bigint,
  roi_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bet_category AS id,
           b.bet_category,
           COUNT(*) AS bet_count,
           COUNT(*) FILTER (WHERE b.grade='win')  AS wins,
           COUNT(*) FILTER (WHERE b.grade='loss') AS losses,
           CASE WHEN COUNT(*) FILTER (WHERE b.status='graded') > 0
                THEN round(COUNT(*) FILTER (WHERE b.grade='win')::numeric * 100.0
                           / COUNT(*) FILTER (WHERE b.status='graded'), 1)
                ELSE 0 END AS win_rate_pct,
           COALESCE(SUM(b.cost_rupees),0)::bigint AS total_cost,
           COALESCE(SUM(b.actual_payoff_rupees),0)::bigint AS total_actual_payoff,
           CASE WHEN COALESCE(SUM(b.cost_rupees),0) > 0
                THEN round((COALESCE(SUM(b.actual_payoff_rupees),0) - COALESCE(SUM(b.cost_rupees),0))::numeric
                           * 100.0 / COALESCE(SUM(b.cost_rupees),0), 1)
                ELSE 0 END AS roi_pct
      FROM public.founder_strategic_bets b
     GROUP BY b.bet_category
     ORDER BY win_rate_pct DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_bets_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bets_by_category() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: founder_bets_live_watchlist — live bets with milestone burn rate
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bets_live_watchlist()
RETURNS TABLE (
  id uuid,
  bet_title text,
  quarter_label text,
  risk_level text,
  confidence_pct int,
  age_days numeric,
  milestones_total bigint,
  milestones_hit bigint,
  next_milestone text,
  next_due_date date
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id,
           b.bet_title,
           b.quarter_label,
           b.risk_level,
           b.confidence_pct,
           round(EXTRACT(EPOCH FROM (now() - b.created_at))/86400.0, 1) AS age_days,
           (SELECT COUNT(*) FROM public.founder_strategic_bet_milestones m WHERE m.bet_id=b.id) AS milestones_total,
           (SELECT COUNT(*) FROM public.founder_strategic_bet_milestones m WHERE m.bet_id=b.id AND m.hit) AS milestones_hit,
           (SELECT m.milestone_label FROM public.founder_strategic_bet_milestones m
             WHERE m.bet_id=b.id AND NOT m.hit ORDER BY m.due_date ASC LIMIT 1) AS next_milestone,
           (SELECT m.due_date FROM public.founder_strategic_bet_milestones m
             WHERE m.bet_id=b.id AND NOT m.hit ORDER BY m.due_date ASC LIMIT 1) AS next_due_date
      FROM public.founder_strategic_bets b
     WHERE b.status='live'
     ORDER BY b.risk_level DESC, b.created_at ASC
     LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_bets_live_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bets_live_watchlist() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: founder_bets_grade_distribution — grade × risk crosstab
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bets_grade_distribution()
RETURNS TABLE (
  id text,
  risk_level text,
  graded bigint,
  wins bigint,
  losses bigint,
  draws bigint,
  win_rate_pct numeric,
  avg_confidence numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.risk_level AS id,
           b.risk_level,
           COUNT(*) FILTER (WHERE b.status='graded') AS graded,
           COUNT(*) FILTER (WHERE b.grade='win')  AS wins,
           COUNT(*) FILTER (WHERE b.grade='loss') AS losses,
           COUNT(*) FILTER (WHERE b.grade='draw') AS draws,
           CASE WHEN COUNT(*) FILTER (WHERE b.status='graded') > 0
                THEN round(COUNT(*) FILTER (WHERE b.grade='win')::numeric * 100.0
                           / COUNT(*) FILTER (WHERE b.status='graded'), 1)
                ELSE 0 END AS win_rate_pct,
           round(AVG(b.confidence_pct), 1) AS avg_confidence
      FROM public.founder_strategic_bets b
     GROUP BY b.risk_level
     ORDER BY CASE b.risk_level
                WHEN 'bet_the_company' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                WHEN 'low' THEN 4
                ELSE 5 END;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_bets_grade_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bets_grade_distribution() TO authenticated;

COMMIT;