BEGIN;

-- ============================================================
-- Round 2841: Founder Quarterly Strategic Bet Postmortem
-- bet x hypothesis x outcome x why x lesson x pattern x next bet implication
-- ============================================================

-- ---------- TABLE 1: strategic bet postmortems ----------
DROP TABLE IF EXISTS public.founder_strategic_bet_postmortems_r2841 CASCADE;

CREATE TABLE public.founder_strategic_bet_postmortems_r2841 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  bet_name text NOT NULL,
  bet_category text NOT NULL CHECK (bet_category IN ('product','growth','vertical','geo','pricing','channel','platform','ops')),
  hypothesis text NOT NULL,
  capital_deployed_inr bigint NOT NULL DEFAULT 0,
  team_weeks_deployed integer NOT NULL DEFAULT 0,
  outcome text NOT NULL CHECK (outcome IN ('win','partial_win','flat','partial_loss','loss','kill')),
  outcome_score integer NOT NULL CHECK (outcome_score BETWEEN 0 AND 100),
  why_summary text NOT NULL,
  lesson text NOT NULL,
  pattern_tag text NOT NULL,
  next_bet_implication text NOT NULL,
  decided_at date NOT NULL,
  closed_at date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategic_bet_postmortems_r2841 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.founder_strategic_bet_postmortems_r2841
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.founder_strategic_bet_postmortems_r2841
  (quarter, bet_name, bet_category, hypothesis, capital_deployed_inr, team_weeks_deployed, outcome, outcome_score, why_summary, lesson, pattern_tag, next_bet_implication, decided_at, closed_at)
VALUES
  ('2026-Q1','Dental vertical specialization','vertical','Dental clinics will pay 40 percent premium for specialized engineers',2400000,18,'win',82,'Won 31 of 38 dental AMC contracts in Hyderabad ring 1; ARPU 38 percent above mixed','Vertical depth beats horizontal width in city tier 1','vertical-depth-wins','Double down: add ophthalmology Q3 + ENT Q4','2026-01-08'::date,'2026-03-28'::date),
  ('2026-Q1','Cashfree Payouts at scale','platform','Direct UPI payouts will cut engineer churn by 25 percent',850000,9,'partial_loss',38,'KYC activation took 11 weeks; backlog accumulated; engineers lost trust temporarily','Never bet a release on a third-party regulatory milestone we do not control','external-dependency-trap','Always ship dual rails: keep manual payout fallback active until provider is proven','2026-01-15'::date,'2026-03-30'::date),
  ('2026-Q1','Hospital chain bulk AMC','growth','One signed chain HQ converts 80 percent of branches in 90 days',1900000,22,'flat',48,'HQ signs do not cascade; each branch GM re-evaluates; sales cycle 4x longer than modeled','Decentralized procurement defeats top-down sales motion in Indian hospitals','procurement-decentralization','Re-route field sales to branch GM directly; treat HQ as awareness layer not contract layer','2026-02-01'::date,'2026-03-29'::date),
  ('2026-Q1','Engineer tier ladder gamification','product','Visible tier ladder lifts top-quartile engineer NPS by 20 points',420000,6,'win',74,'Tier promotion notifications drove 2.3x weekly active engineer minutes; NPS plus 17','Public progress beats private recognition in trade workforce','status-visibility','Replicate pattern for hospital biomed engineers and AMC renewals','2026-01-22'::date,'2026-03-25'::date),
  ('2026-Q1','Sri Lanka pilot launch','geo','Sub-continent expansion proves before Tier 2 India deepening',680000,14,'kill',12,'Currency volatility plus regulatory ambiguity plus zero brand recall destroyed unit economics','International expansion requires 18-month runway buffer not 12','geo-premature','Kill all geo bets until India unit economics LTV/CAC > 3.5 sustained 2 quarters','2026-02-10'::date,'2026-03-31'::date),
  ('2026-Q1','AI-assisted triage v0.6','platform','LLM triage routes 60 percent of jobs in under 90 seconds',1100000,16,'partial_win',61,'LLM hit 47 percent autonomous routing; edge cases still need human; accuracy 91 percent','Compound work: ship 50 percent autonomous now, accept 100 percent autonomous is fantasy','autonomy-incremental','Productionize at 50 percent gate; reinvest savings into spare-parts AI not more routing','2026-01-28'::date,'2026-03-27'::date),
  ('2026-Q1','Investor monthly data room v2','channel','Live data room replaces decks and shortens diligence by 50 percent',180000,4,'win',88,'4 of 5 active LPs reported diligence cycle dropped from 6 weeks to 2.5','Transparency compounds investor trust faster than narrative polish','radical-transparency','Build customer-facing version: live ops dashboard for top 10 hospitals','2026-02-05'::date,'2026-03-30'::date);

CREATE INDEX idx_bet_postmortem_quarter ON public.founder_strategic_bet_postmortems_r2841(quarter);
CREATE INDEX idx_bet_postmortem_outcome ON public.founder_strategic_bet_postmortems_r2841(outcome);
CREATE INDEX idx_bet_postmortem_pattern ON public.founder_strategic_bet_postmortems_r2841(pattern_tag);

-- ---------- TABLE 2: pattern library + next-bet implications ----------
DROP TABLE IF EXISTS public.founder_bet_patterns_r2841 CASCADE;

CREATE TABLE public.founder_bet_patterns_r2841 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_tag text NOT NULL UNIQUE,
  pattern_label text NOT NULL,
  pattern_description text NOT NULL,
  observed_in_bets integer NOT NULL DEFAULT 0,
  recommended_action text NOT NULL,
  confidence text NOT NULL CHECK (confidence IN ('low','medium','high','very_high')),
  capital_to_redirect_inr bigint NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_bet_patterns_r2841 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.founder_bet_patterns_r2841
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.founder_bet_patterns_r2841
  (pattern_tag, pattern_label, pattern_description, observed_in_bets, recommended_action, confidence, capital_to_redirect_inr)
VALUES
  ('vertical-depth-wins','Vertical depth beats horizontal width','Specialization in single clinical vertical yields 30-40 percent ARPU premium versus mixed playbook',4,'Allocate 60 percent of growth capital to 2 chosen verticals; cap horizontal expansion','very_high',3200000),
  ('external-dependency-trap','External regulatory dependency blocks GTM','Bets gated on third-party KYC or licensing slip 2-3x; dual rails are mandatory',2,'Mandate dual-rail design review for any bet touching payments licensing or partnerships','very_high',1500000),
  ('procurement-decentralization','Indian hospital procurement is branch-local','HQ signatures do not cascade; treat as awareness not contract',2,'Redirect chain-sales team to branch GM motion; HQ is a marketing surface only','high',900000),
  ('status-visibility','Public progress beats private recognition','Visible tier ladders lift workforce engagement 2x versus hidden metrics',3,'Add public progress surfaces to AMC tier ladder + hospital scorecards','high',400000),
  ('geo-premature','International expansion needs LTV/CAC > 3.5','Sub-continent unit economics collapse without sustained domestic profitability',1,'Freeze all geo bets until India LTV/CAC sustained > 3.5 for 2 consecutive quarters','very_high',2000000),
  ('autonomy-incremental','Ship 50 percent autonomy not 100','LLM autonomy plateaus near 50 percent; chasing last 50 percent burns 3x cost',2,'Productionize at autonomy gates; reinvest into adjacent compounding bets','high',800000),
  ('radical-transparency','Live data beats narrative decks','Live dashboards compress diligence 50 percent for investors and customers alike',2,'Build customer-facing live ops dashboards for top accounts','very_high',1200000);

CREATE INDEX idx_bet_patterns_confidence ON public.founder_bet_patterns_r2841(confidence);
CREATE INDEX idx_bet_patterns_active ON public.founder_bet_patterns_r2841(active);

-- ============================================================
-- RPCs (7+, all SECDEF, is_founder gated)
-- ============================================================

-- RPC 1: portfolio summary
DROP FUNCTION IF EXISTS public.founder_bet_portfolio_summary_r2841();
CREATE OR REPLACE FUNCTION public.founder_bet_portfolio_summary_r2841()
RETURNS TABLE (
  total_bets bigint,
  total_capital_inr bigint,
  total_team_weeks bigint,
  wins bigint,
  partial_wins bigint,
  losses bigint,
  kills bigint,
  avg_outcome_score numeric,
  win_rate_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    coalesce(sum(capital_deployed_inr),0)::bigint,
    coalesce(sum(team_weeks_deployed),0)::bigint,
    count(*) FILTER (WHERE outcome='win')::bigint,
    count(*) FILTER (WHERE outcome='partial_win')::bigint,
    count(*) FILTER (WHERE outcome IN ('loss','partial_loss'))::bigint,
    count(*) FILTER (WHERE outcome='kill')::bigint,
    round(coalesce(avg(outcome_score),0)::numeric, 1),
    round((count(*) FILTER (WHERE outcome IN ('win','partial_win'))::numeric / NULLIF(count(*),0)::numeric) * 100, 1)
  FROM public.founder_strategic_bet_postmortems_r2841;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_portfolio_summary_r2841() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_portfolio_summary_r2841() TO authenticated;

-- RPC 2: bets ranked by outcome score
DROP FUNCTION IF EXISTS public.founder_bet_ranked_r2841();
CREATE OR REPLACE FUNCTION public.founder_bet_ranked_r2841()
RETURNS TABLE (
  bet_name text,
  quarter text,
  outcome text,
  outcome_score integer,
  capital_deployed_inr bigint,
  pattern_tag text,
  next_bet_implication text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.bet_name, p.quarter, p.outcome, p.outcome_score,
    p.capital_deployed_inr, p.pattern_tag, p.next_bet_implication
  FROM public.founder_strategic_bet_postmortems_r2841 p
  ORDER BY p.outcome_score DESC, p.capital_deployed_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_ranked_r2841() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_ranked_r2841() TO authenticated;

-- RPC 3: category breakdown
DROP FUNCTION IF EXISTS public.founder_bet_by_category_r2841();
CREATE OR REPLACE FUNCTION public.founder_bet_by_category_r2841()
RETURNS TABLE (
  bet_category text,
  bets bigint,
  capital_inr bigint,
  avg_score numeric,
  wins bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.bet_category,
    count(*)::bigint,
    coalesce(sum(p.capital_deployed_inr),0)::bigint,
    round(avg(p.outcome_score)::numeric,1),
    count(*) FILTER (WHERE p.outcome IN ('win','partial_win'))::bigint
  FROM public.founder_strategic_bet_postmortems_r2841 p
  GROUP BY p.bet_category
  ORDER BY capital_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_by_category_r2841() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_by_category_r2841() TO authenticated;

-- RPC 4: top patterns to act on
DROP FUNCTION IF EXISTS public.founder_bet_top_patterns_r2841();
CREATE OR REPLACE FUNCTION public.founder_bet_top_patterns_r2841()
RETURNS TABLE (
  pattern_label text,
  observed_in_bets integer,
  confidence text,
  capital_to_redirect_inr bigint,
  recommended_action text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    bp.pattern_label, bp.observed_in_bets, bp.confidence,
    bp.capital_to_redirect_inr, bp.recommended_action
  FROM public.founder_bet_patterns_r2841 bp
  WHERE bp.active = true
  ORDER BY
    CASE bp.confidence WHEN 'very_high' THEN 4 WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END DESC,
    bp.capital_to_redirect_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_top_patterns_r2841() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_top_patterns_r2841() TO authenticated;

-- RPC 5: losses and kills with lessons
DROP FUNCTION IF EXISTS public.founder_bet_losses_lessons_r2841();
CREATE OR REPLACE FUNCTION public.founder_bet_losses_lessons_r2841()
RETURNS TABLE (
  bet_name text,
  outcome text,
  capital_burned_inr bigint,
  why_summary text,
  lesson text,
  next_bet_implication text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.bet_name, p.outcome, p.capital_deployed_inr,
    p.why_summary, p.lesson, p.next_bet_implication
  FROM public.founder_strategic_bet_postmortems_r2841 p
  WHERE p.outcome IN ('loss','partial_loss','kill','flat')
  ORDER BY p.capital_deployed_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_losses_lessons_r2841() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_losses_lessons_r2841() TO authenticated;

-- RPC 6: capital efficiency (score per lakh)
DROP FUNCTION IF EXISTS public.founder_bet_capital_efficiency_r2841();
CREATE OR REPLACE FUNCTION public.founder_bet_capital_efficiency_r2841()
RETURNS TABLE (
  bet_name text,
  capital_lakh numeric,
  outcome_score integer,
  score_per_lakh numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.bet_name,
    round((p.capital_deployed_inr::numeric / 100000.0),2),
    p.outcome_score,
    round((p.outcome_score::numeric / NULLIF((p.capital_deployed_inr::numeric / 100000.0),0))::numeric, 2)
  FROM public.founder_strategic_bet_postmortems_r2841 p
  ORDER BY score_per_lakh DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_capital_efficiency_r2841() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_capital_efficiency_r2841() TO authenticated;

-- RPC 7: next-quarter capital reallocation
DROP FUNCTION IF EXISTS public.founder_bet_next_quarter_reallocation_r2841();
CREATE OR REPLACE FUNCTION public.founder_bet_next_quarter_reallocation_r2841()
RETURNS TABLE (
  pattern_label text,
  recommended_action text,
  capital_to_redirect_inr bigint,
  confidence text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    bp.pattern_label, bp.recommended_action,
    bp.capital_to_redirect_inr, bp.confidence
  FROM public.founder_bet_patterns_r2841 bp
  WHERE bp.active = true
    AND bp.confidence IN ('high','very_high')
  ORDER BY bp.capital_to_redirect_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_next_quarter_reallocation_r2841() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_next_quarter_reallocation_r2841() TO authenticated;

-- RPC 8: deactivate a pattern (admin action)
DROP FUNCTION IF EXISTS public.founder_bet_deactivate_pattern_r2841(text);
CREATE OR REPLACE FUNCTION public.founder_bet_deactivate_pattern_r2841(p_pattern_tag text)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_bet_patterns_r2841
  SET active = false
  WHERE pattern_tag = p_pattern_tag;
  RETURN FOUND;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bet_deactivate_pattern_r2841(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bet_deactivate_pattern_r2841(text) TO authenticated;

COMMIT;
