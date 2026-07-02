BEGIN;

-- ============================================================================
-- Round 2785 — Founder Quarterly Strategic Experiment Cost Cap
-- experiment × bet × spend × cap × actual × outcome × continue/kill decision
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: quarterly_experiments_r2785
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.quarterly_experiments_r2785 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  experiment_code text NOT NULL UNIQUE,
  experiment_name text NOT NULL,
  strategic_bet text NOT NULL,
  hypothesis text NOT NULL,
  owner text NOT NULL,
  budget_cap_rupees bigint NOT NULL CHECK (budget_cap_rupees >= 0),
  spend_to_date_rupees bigint NOT NULL DEFAULT 0 CHECK (spend_to_date_rupees >= 0),
  target_metric text NOT NULL,
  target_value numeric NOT NULL,
  actual_value numeric NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('active','paused','killed','graduated','complete')),
  started_on date NOT NULL,
  review_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.quarterly_experiments_r2785 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.quarterly_experiments_r2785;
CREATE POLICY founder_all ON public.quarterly_experiments_r2785
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.quarterly_experiments_r2785
  (quarter, experiment_code, experiment_name, strategic_bet, hypothesis, owner, budget_cap_rupees, spend_to_date_rupees, target_metric, target_value, actual_value, status, started_on, review_on)
VALUES
  ('Q3-2026','EXP-301','Dental vertical pilot Hyderabad','vertical_dental','40 dental clinics sign AMC in 60 days at ARPU > 8000','founder',1500000,1175000,'amc_signups',40,33,'active','2026-04-01'::date,'2026-07-15'::date),
  ('Q3-2026','EXP-302','Tier-2 city expansion Vizag','geo_expansion','Vizag generates 25 jobs/week within 90 days','founder',800000,720000,'weekly_jobs',25,11,'paused','2026-04-10'::date,'2026-07-10'::date),
  ('Q3-2026','EXP-303','Engineer cert ladder gamification','engineer_retention','Cert badges lift weekly job acceptance by 18 pct','ops_lead',300000,180000,'acceptance_lift_pct',18,22,'graduated','2026-04-15'::date,'2026-07-01'::date),
  ('Q3-2026','EXP-304','Hospital chain bulk AMC','enterprise_motion','3 chains sign multi-site AMC > 25L each','founder',600000,580000,'chain_signups',3,1,'active','2026-05-01'::date,'2026-07-20'::date),
  ('Q3-2026','EXP-305','AI triage auto-routing','ops_efficiency','Cut median assignment time by 40 pct','tech_lead',450000,470000,'assign_time_reduction_pct',40,12,'killed','2026-05-05'::date,'2026-06-30'::date),
  ('Q3-2026','EXP-306','Founder customer spotlight library','brand_pull','Generate 12 inbound leads/month from spotlight content','marketing',200000,95000,'inbound_leads',12,8,'active','2026-05-20'::date,'2026-07-25'::date);

-- ----------------------------------------------------------------------------
-- Table 2: experiment_decisions_r2785
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.experiment_decisions_r2785 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id uuid NOT NULL REFERENCES public.quarterly_experiments_r2785(id) ON DELETE CASCADE,
  decided_on date NOT NULL,
  decision text NOT NULL CHECK (decision IN ('continue','kill','double_down','pivot','graduate','pause')),
  rationale text NOT NULL,
  cost_cap_hit boolean NOT NULL DEFAULT false,
  outcome_snapshot text NOT NULL,
  next_milestone text,
  decided_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.experiment_decisions_r2785 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.experiment_decisions_r2785;
CREATE POLICY founder_all ON public.experiment_decisions_r2785
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.experiment_decisions_r2785
  (experiment_id, decided_on, decision, rationale, cost_cap_hit, outcome_snapshot, next_milestone, decided_by)
SELECT id, '2026-06-15'::date, 'continue','83 pct of target reached at 78 pct of cap — extend 30 days', false, '33 of 40 signups · 117L spent of 150L cap', 'Hit 40 signups by 2026-07-15', 'founder'
  FROM public.quarterly_experiments_r2785 WHERE experiment_code='EXP-301';

INSERT INTO public.experiment_decisions_r2785
  (experiment_id, decided_on, decision, rationale, cost_cap_hit, outcome_snapshot, next_milestone, decided_by)
SELECT id, '2026-06-10'::date, 'pause','Vizag CAC 3.2x Hyderabad — pause until playbook tightens', true, '11 of 25 weekly jobs · 90 pct cap burned', 'Re-evaluate Q4 with new GTM', 'founder'
  FROM public.quarterly_experiments_r2785 WHERE experiment_code='EXP-302';

INSERT INTO public.experiment_decisions_r2785
  (experiment_id, decided_on, decision, rationale, cost_cap_hit, outcome_snapshot, next_milestone, decided_by)
SELECT id, '2026-06-20'::date, 'graduate','Beat target by 22 pct — fold into core product', false, '22 pct lift vs 18 pct target', 'Ship to all engineers Q4', 'ops_lead'
  FROM public.quarterly_experiments_r2785 WHERE experiment_code='EXP-303';

INSERT INTO public.experiment_decisions_r2785
  (experiment_id, decided_on, decision, rationale, cost_cap_hit, outcome_snapshot, next_milestone, decided_by)
SELECT id, '2026-06-18'::date, 'double_down','1 chain signed = 30L ARR — fund 2 more BDs', false, '1 of 3 chains signed · 97 pct cap', 'Close 2 more chains by 2026-07-20', 'founder'
  FROM public.quarterly_experiments_r2785 WHERE experiment_code='EXP-304';

INSERT INTO public.experiment_decisions_r2785
  (experiment_id, decided_on, decision, rationale, cost_cap_hit, outcome_snapshot, next_milestone, decided_by)
SELECT id, '2026-06-12'::date, 'kill','12 pct improvement vs 40 pct target — not worth scaling spend', true, 'Cap exceeded · 12 pct vs 40 pct', 'Reallocate to EXP-304', 'tech_lead'
  FROM public.quarterly_experiments_r2785 WHERE experiment_code='EXP-305';

INSERT INTO public.experiment_decisions_r2785
  (experiment_id, decided_on, decision, rationale, cost_cap_hit, outcome_snapshot, next_milestone, decided_by)
SELECT id, '2026-06-21'::date, 'continue','67 pct progress at 48 pct of cap — track to plan', false, '8 of 12 leads · 47 pct cap burned', 'Hit 12 leads by 2026-07-25', 'marketing'
  FROM public.quarterly_experiments_r2785 WHERE experiment_code='EXP-306';

-- ============================================================================
-- RPCs
-- ============================================================================

-- RPC 1: portfolio summary
DROP FUNCTION IF EXISTS public.r2785_portfolio_summary();
CREATE FUNCTION public.r2785_portfolio_summary()
RETURNS TABLE(
  total_experiments int,
  active_count int,
  killed_count int,
  graduated_count int,
  paused_count int,
  total_budget_rupees bigint,
  total_spend_rupees bigint,
  cap_utilization_pct numeric,
  experiments_over_cap int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status='active')::int,
    COUNT(*) FILTER (WHERE status='killed')::int,
    COUNT(*) FILTER (WHERE status='graduated')::int,
    COUNT(*) FILTER (WHERE status='paused')::int,
    COALESCE(SUM(budget_cap_rupees),0)::bigint,
    COALESCE(SUM(spend_to_date_rupees),0)::bigint,
    CASE WHEN SUM(budget_cap_rupees) > 0
         THEN ROUND(100.0 * SUM(spend_to_date_rupees) / SUM(budget_cap_rupees), 1)
         ELSE 0 END,
    COUNT(*) FILTER (WHERE spend_to_date_rupees > budget_cap_rupees)::int
  FROM public.quarterly_experiments_r2785;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_portfolio_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_portfolio_summary() TO authenticated;

-- RPC 2: list experiments
DROP FUNCTION IF EXISTS public.r2785_list_experiments();
CREATE FUNCTION public.r2785_list_experiments()
RETURNS TABLE(
  experiment_code text,
  experiment_name text,
  strategic_bet text,
  owner text,
  status text,
  budget_cap_rupees bigint,
  spend_to_date_rupees bigint,
  cap_utilization_pct numeric,
  target_metric text,
  target_value numeric,
  actual_value numeric,
  attainment_pct numeric,
  review_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.experiment_code, e.experiment_name, e.strategic_bet, e.owner, e.status,
    e.budget_cap_rupees, e.spend_to_date_rupees,
    CASE WHEN e.budget_cap_rupees > 0
         THEN ROUND(100.0 * e.spend_to_date_rupees / e.budget_cap_rupees, 1)
         ELSE 0 END,
    e.target_metric, e.target_value, e.actual_value,
    CASE WHEN e.target_value > 0
         THEN ROUND(100.0 * e.actual_value / e.target_value, 1)
         ELSE 0 END,
    e.review_on
  FROM public.quarterly_experiments_r2785 e
  ORDER BY e.review_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_list_experiments() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_list_experiments() TO authenticated;

-- RPC 3: continue/kill scoreboard
DROP FUNCTION IF EXISTS public.r2785_continue_kill_scoreboard();
CREATE FUNCTION public.r2785_continue_kill_scoreboard()
RETURNS TABLE(
  experiment_code text,
  experiment_name text,
  attainment_pct numeric,
  cap_utilization_pct numeric,
  recommendation text,
  reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.experiment_code,
    e.experiment_name,
    CASE WHEN e.target_value > 0 THEN ROUND(100.0 * e.actual_value / e.target_value, 1) ELSE 0 END,
    CASE WHEN e.budget_cap_rupees > 0 THEN ROUND(100.0 * e.spend_to_date_rupees / e.budget_cap_rupees, 1) ELSE 0 END,
    CASE
      WHEN e.target_value > 0 AND e.actual_value / e.target_value >= 1.0 THEN 'graduate'
      WHEN e.spend_to_date_rupees > e.budget_cap_rupees AND e.actual_value / NULLIF(e.target_value,0) < 0.5 THEN 'kill'
      WHEN e.target_value > 0 AND e.actual_value / e.target_value >= 0.75 THEN 'continue'
      WHEN e.spend_to_date_rupees > 0.8 * e.budget_cap_rupees AND e.actual_value / NULLIF(e.target_value,0) < 0.5 THEN 'pause'
      ELSE 'continue'
    END,
    CASE
      WHEN e.target_value > 0 AND e.actual_value / e.target_value >= 1.0 THEN 'Beat target — fold into core'
      WHEN e.spend_to_date_rupees > e.budget_cap_rupees AND e.actual_value / NULLIF(e.target_value,0) < 0.5 THEN 'Cap blown with low traction'
      WHEN e.target_value > 0 AND e.actual_value / e.target_value >= 0.75 THEN 'Strong attainment under cap'
      WHEN e.spend_to_date_rupees > 0.8 * e.budget_cap_rupees AND e.actual_value / NULLIF(e.target_value,0) < 0.5 THEN 'Burning cap without traction'
      ELSE 'On plan — keep going'
    END
  FROM public.quarterly_experiments_r2785 e
  ORDER BY e.review_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_continue_kill_scoreboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_continue_kill_scoreboard() TO authenticated;

-- RPC 4: bet rollup
DROP FUNCTION IF EXISTS public.r2785_bet_rollup();
CREATE FUNCTION public.r2785_bet_rollup()
RETURNS TABLE(
  strategic_bet text,
  experiment_count int,
  total_budget_rupees bigint,
  total_spend_rupees bigint,
  avg_attainment_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.strategic_bet,
    COUNT(*)::int,
    COALESCE(SUM(e.budget_cap_rupees),0)::bigint,
    COALESCE(SUM(e.spend_to_date_rupees),0)::bigint,
    ROUND(AVG(CASE WHEN e.target_value > 0 THEN 100.0 * e.actual_value / e.target_value ELSE 0 END), 1)
  FROM public.quarterly_experiments_r2785 e
  GROUP BY e.strategic_bet
  ORDER BY total_spend_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_bet_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_bet_rollup() TO authenticated;

-- RPC 5: decisions log
DROP FUNCTION IF EXISTS public.r2785_decisions_log();
CREATE FUNCTION public.r2785_decisions_log()
RETURNS TABLE(
  experiment_code text,
  decided_on date,
  decision text,
  rationale text,
  cost_cap_hit boolean,
  outcome_snapshot text,
  next_milestone text,
  decided_by text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.experiment_code, d.decided_on, d.decision, d.rationale,
    d.cost_cap_hit, d.outcome_snapshot, d.next_milestone, d.decided_by
  FROM public.experiment_decisions_r2785 d
  JOIN public.quarterly_experiments_r2785 e ON e.id = d.experiment_id
  ORDER BY d.decided_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_decisions_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_decisions_log() TO authenticated;

-- RPC 6: cap breach watchlist
DROP FUNCTION IF EXISTS public.r2785_cap_breach_watchlist();
CREATE FUNCTION public.r2785_cap_breach_watchlist()
RETURNS TABLE(
  experiment_code text,
  experiment_name text,
  budget_cap_rupees bigint,
  spend_to_date_rupees bigint,
  overspend_rupees bigint,
  attainment_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.experiment_code, e.experiment_name, e.budget_cap_rupees, e.spend_to_date_rupees,
    GREATEST(e.spend_to_date_rupees - e.budget_cap_rupees, 0)::bigint,
    CASE WHEN e.target_value > 0 THEN ROUND(100.0 * e.actual_value / e.target_value, 1) ELSE 0 END,
    e.status
  FROM public.quarterly_experiments_r2785 e
  WHERE e.spend_to_date_rupees >= 0.8 * e.budget_cap_rupees
  ORDER BY (e.spend_to_date_rupees - e.budget_cap_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_cap_breach_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_cap_breach_watchlist() TO authenticated;

-- RPC 7: graduates and kills tally
DROP FUNCTION IF EXISTS public.r2785_graduates_and_kills();
CREATE FUNCTION public.r2785_graduates_and_kills()
RETURNS TABLE(
  bucket text,
  experiment_count int,
  total_spend_rupees bigint,
  experiments text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.status,
    COUNT(*)::int,
    COALESCE(SUM(e.spend_to_date_rupees),0)::bigint,
    string_agg(e.experiment_code, ', ' ORDER BY e.experiment_code)
  FROM public.quarterly_experiments_r2785 e
  GROUP BY e.status
  ORDER BY e.status;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_graduates_and_kills() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_graduates_and_kills() TO authenticated;

-- RPC 8: upcoming reviews
DROP FUNCTION IF EXISTS public.r2785_upcoming_reviews();
CREATE FUNCTION public.r2785_upcoming_reviews()
RETURNS TABLE(
  experiment_code text,
  experiment_name text,
  review_on date,
  days_until int,
  attainment_pct numeric,
  cap_utilization_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.experiment_code, e.experiment_name, e.review_on,
    (e.review_on - CURRENT_DATE)::int,
    CASE WHEN e.target_value > 0 THEN ROUND(100.0 * e.actual_value / e.target_value, 1) ELSE 0 END,
    CASE WHEN e.budget_cap_rupees > 0 THEN ROUND(100.0 * e.spend_to_date_rupees / e.budget_cap_rupees, 1) ELSE 0 END,
    e.status
  FROM public.quarterly_experiments_r2785 e
  WHERE e.status IN ('active','paused')
  ORDER BY e.review_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2785_upcoming_reviews() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2785_upcoming_reviews() TO authenticated;

COMMIT;
