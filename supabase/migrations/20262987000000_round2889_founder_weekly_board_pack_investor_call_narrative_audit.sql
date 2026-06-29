-- Round 2889 — Founder Weekly Board-Pack Pre-Investor-Call Narrative Audit
-- HEAVY ★★★★ founder ops round
-- Two tables, seven founder-gated RPCs, board-pack narrative audit for investor calls.

BEGIN;

-- ============================================================================
-- TABLE 1: board_pack_narrative_claims_r2889
-- Each claim asserted in the weekly board pack, with source metric + variance.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.board_pack_narrative_claims_r2889 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  week_ending date NOT NULL,
  section text NOT NULL CHECK (section IN ('growth','unit_economics','retention','ops','risk','team','outlook')),
  claim_headline text NOT NULL,
  claim_metric_name text NOT NULL,
  claim_value_text text NOT NULL,
  source_system text NOT NULL CHECK (source_system IN ('analytics_ledger','stripe','razorpay','cashfree','supabase_rpc','manual_spreadsheet','crm','field_ops')),
  source_query_ref text,
  reconciled boolean NOT NULL DEFAULT false,
  variance_pct numeric(6,2),
  narrative_risk text NOT NULL CHECK (narrative_risk IN ('clean','soft_spin','aggressive_spin','unsupported','contradicted')),
  investor_qna_likelihood text NOT NULL CHECK (investor_qna_likelihood IN ('low','medium','high','certain')),
  fallback_answer text,
  reviewer_initials text,
  status text NOT NULL CHECK (status IN ('draft','reviewed','locked','retracted'))
);

ALTER TABLE public.board_pack_narrative_claims_r2889 ENABLE ROW LEVEL SECURITY;

CREATE POLICY claims_r2889_founder_all ON public.board_pack_narrative_claims_r2889
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- TABLE 2: investor_call_objection_drills_r2889
-- Anticipated investor objections and prepared founder responses.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.investor_call_objection_drills_r2889 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  investor_name text NOT NULL,
  investor_fund text NOT NULL,
  call_scheduled_at timestamptz NOT NULL,
  objection_category text NOT NULL CHECK (objection_category IN ('tam','unit_economics','moat','retention','founder_market_fit','regulatory','competitive','burn','team_gaps','exit_path')),
  objection_text text NOT NULL,
  prepared_response text NOT NULL,
  supporting_metric text,
  weakness_self_score int NOT NULL CHECK (weakness_self_score BETWEEN 1 AND 5),
  rehearsed boolean NOT NULL DEFAULT false,
  rehearsal_notes text,
  escalation_required boolean NOT NULL DEFAULT false,
  status text NOT NULL CHECK (status IN ('pending','rehearsed','locked','obsolete'))
);

ALTER TABLE public.investor_call_objection_drills_r2889 ENABLE ROW LEVEL SECURITY;

CREATE POLICY drills_r2889_founder_all ON public.investor_call_objection_drills_r2889
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- SEED DATA — board_pack_narrative_claims_r2889 (18 rows)
-- ============================================================================
INSERT INTO public.board_pack_narrative_claims_r2889
  (week_ending, section, claim_headline, claim_metric_name, claim_value_text, source_system, source_query_ref, reconciled, variance_pct, narrative_risk, investor_qna_likelihood, fallback_answer, reviewer_initials, status)
VALUES
  ('2026-06-28','growth','GMV up 38% WoW driven by Tier-1 hospital chains','weekly_gmv_rupees','₹48.2L','analytics_ledger','rpc_weekly_gmv',true,2.10,'clean','high','Includes one ₹6L outlier AMC pre-pay; ex-outlier 22% WoW','GD','locked'),
  ('2026-06-28','growth','Active hospitals crossed 1,400','distinct_hospitals_30d','1,412','supabase_rpc','rpc_active_hospitals',true,0.00,'clean','medium','30-day active = at least one repair OR AMC ping','GD','locked'),
  ('2026-06-28','unit_economics','Contribution margin per repair job stable at 31%','contribution_margin_pct','31.2%','analytics_ledger','rpc_cm_per_job',true,1.40,'clean','certain','Excludes engineer training amortization (separate line)','GD','locked'),
  ('2026-06-28','unit_economics','Engineer payout share trending toward 62%','payout_share_pct','62.4%','supabase_rpc','rpc_payout_share',true,3.20,'soft_spin','high','Up from 58% Q1 — driven by certification ladder tier mix','GD','reviewed'),
  ('2026-06-28','unit_economics','Take rate held at 11.5%','effective_take_rate','11.5%','analytics_ledger','rpc_take_rate',false,-4.80,'aggressive_spin','certain','Blended; AMC take rate 14%, repair-only 9%. Investor will ask','GD','reviewed'),
  ('2026-06-28','retention','AMC renewal rate 84% at month 12','amc_m12_renewal','84.1%','supabase_rpc','rpc_amc_cohort',true,0.60,'clean','high','Cohort = Jun-2025 hospitals on Tier-2 and above','GD','locked'),
  ('2026-06-28','retention','Engineer 90-day retention 71%','engineer_d90_retention','71.0%','crm','export_2026_06_28_engineers',true,2.00,'clean','medium','Below industry whisper of 78%; framing as "post-vetting cohort"','GD','reviewed'),
  ('2026-06-28','retention','Hospital NPS climbed to 62','nps_weekly','62','manual_spreadsheet','nps_jun_2026.xlsx',false,NULL,'unsupported','high','Sample size n=84; not statistically rigorous yet','GD','draft'),
  ('2026-06-28','ops','SLA breach rate dropped below 4%','sla_breach_pct','3.7%','supabase_rpc','rpc_sla_breaches',true,0.00,'clean','medium','Excludes hospital-cancellation breaches per definition','GD','locked'),
  ('2026-06-28','ops','Mean time to engineer dispatch 47 minutes','mttd_minutes','47','analytics_ledger','rpc_mttd',true,1.10,'clean','low','Tier-1 cities only; Tier-2 still at 92 min','GD','locked'),
  ('2026-06-28','risk','Zero P0 incidents this week','p0_incident_count','0','supabase_rpc','rpc_incidents',true,0.00,'clean','low','Two P1s opened, both closed within SLA','GD','locked'),
  ('2026-06-28','risk','DPDP grievance backlog under 5 tickets','dpdp_backlog','3','supabase_rpc','rpc_dpdp_queue',true,0.00,'clean','medium','Median age 1.2 days; all under 7-day statutory clock','GD','locked'),
  ('2026-06-28','risk','Counterfeit parts intercepts: 12 YTD','counterfeit_intercepts_ytd','12','field_ops','field_log_jun',true,0.00,'clean','high','Bonded provenance program working as designed','GD','locked'),
  ('2026-06-28','team','Headcount at 23 with 4 open roles','total_headcount','23','manual_spreadsheet','people_ops_v8.xlsx',true,0.00,'clean','low','Eng-heavy: 11 of 23 engineering','GD','locked'),
  ('2026-06-28','team','Founder still on tools 60% of time','founder_time_allocation','60%','manual_spreadsheet','calendar_audit',false,NULL,'contradicted','certain','Honest: this is a yellow flag, hiring COO in Q3','GD','draft'),
  ('2026-06-28','outlook','Q3 target: ₹2.5Cr GMV','q3_gmv_target','₹2.5Cr','manual_spreadsheet','forecast_v3.xlsx',false,NULL,'aggressive_spin','certain','Stretch; base case ₹1.9Cr, plan ₹2.5Cr','GD','reviewed'),
  ('2026-06-28','outlook','Series A target close: Dec 2026','series_a_target','Dec 2026','manual_spreadsheet','fundraise_tracker',false,NULL,'soft_spin','high','3 term sheets verbal, none signed','GD','reviewed'),
  ('2026-06-28','growth','International pilot live in Sri Lanka','intl_pilots_count','1','field_ops','pilot_log_lk',false,NULL,'soft_spin','medium','One hospital, one engineer, ₹0 GMV yet','GD','draft');

-- ============================================================================
-- SEED DATA — investor_call_objection_drills_r2889 (16 rows)
-- ============================================================================
INSERT INTO public.investor_call_objection_drills_r2889
  (investor_name, investor_fund, call_scheduled_at, objection_category, objection_text, prepared_response, supporting_metric, weakness_self_score, rehearsed, rehearsal_notes, escalation_required, status)
VALUES
  ('Priya Menon','Lightspeed India', now() + interval '2 days','tam','Indian medical equipment repair TAM is ₹3,000Cr but addressable share is much smaller — what is your real beachhead?','SAM = ₹620Cr (Class A/B + super-specialty across top 18 cities). We have 4.1% share of SAM in our two beachhead cities, scaling that across 18 cities = ₹187Cr revenue runway before product expansion.','sam_share_pct = 4.1%, target_cities=18',2,true,'Rehearsed with mentor; remember to anchor on SAM not TAM',false,'rehearsed'),
  ('Karan Bajaj','Accel India', now() + interval '3 days','unit_economics','Your blended take rate of 11.5% is below benchmarks — how do you defend it?','Blended understates: AMC take rate 14%, repair-only 9%. Mix is shifting toward AMC (62% of new GMV), so blended take rate will trend to 13% by EoY.','amc_gmv_share=62%, amc_take_rate=14%',3,true,'Investor pushed hard on this; have AMC mix chart ready',false,'rehearsed'),
  ('Rohan Shah','Matrix Partners', now() + interval '1 day','moat','What stops a hospital chain from going direct to OEMs and bypassing you?','OEM direct = 8-week SLA, no AMC pooling, no spare-parts bonded inventory. Our pooled model saves chains 23% on annualized maintenance.','chain_savings_pct=23%',2,true,'Strong angle; have Apollo case study one-pager',false,'rehearsed'),
  ('Anjali Iyer','Elevation Capital', now() + interval '4 days','retention','84% AMC renewal sounds high — what is the cohort definition?','Jun-2025 cohort, Tier-2+ AMC tier, contract value above ₹50K. Tier-1 (cheapest) cohort is at 68% — we are deliberately deprioritizing it.','m12_renewal_t2_plus=84%, m12_renewal_t1=68%',3,false,'NOT rehearsed yet — cohort transparency could backfire',false,'pending'),
  ('Vikram Rao','Blume Ventures', now() + interval '2 days','founder_market_fit','You are a software founder going into hardware ops — why does that work?','I spent the first 9 months on the road with 40 engineers; built the certification ladder from job-shadowing. Co-founder gap is hardware-ops COO — open role, 3 finalists.','road_days_yr1=187, coo_finalists=3',4,true,'Honest answer plays best; do not overcompensate',true,'rehearsed'),
  ('Deepak Singh','Stellaris', now() + interval '5 days','regulatory','CDSCO + DPDP + state biomedical waste compliance — how do you not drown?','CDSCO rep letter on file, DPDP grievance auto-routing live (3-day median close), biomedical waste handled by hospital-side per contract.','dpdp_median_close_days=1.2',2,true,'Show DPDP dashboard screenshot',false,'rehearsed'),
  ('Meera Krishnan','Nexus Venture Partners', now() + interval '3 days','competitive','TrakInvest and MedRepair both raised Series B — how do you compete?','TrakInvest is multi-vertical and unfocused; MedRepair is Mumbai-only. We are the only vertically integrated player with bonded parts + AMC pooling. Their LTV/CAC is 1.8, ours is 3.4.','our_ltv_cac=3.4, comp_ltv_cac=1.8',2,true,'Have the comparison matrix one-pager',false,'rehearsed'),
  ('Arjun Pillai','Bessemer India', now() + interval '6 days','burn','Burn looks high for ARR — what is the path to default-alive?','Current monthly burn ₹38L, monthly contribution ₹14L. Default-alive at ₹95L monthly contribution = ~21 months at current growth.','months_to_default_alive=21',3,false,'Need to refine numbers before call',true,'pending'),
  ('Sanjay Gupta','Sequoia Surge', now() + interval '2 days','team_gaps','Only 23 people and 4 open roles — when does ops scale break?','COO + Head of Engineering Ops are the two breakers. 3 COO finalists, offer this month. Eng Ops promoted from within.','open_roles=4, coo_offer_eta_days=14',4,false,'Vulnerable; rehearse with mentor before this call',true,'pending'),
  ('Latha Reddy','Kalaari Capital', now() + interval '4 days','exit_path','What is the realistic exit narrative — IPO or strategic?','Strategic to a global medtech (GE/Siemens) in 5-7 years OR IPO if we cross ₹500Cr ARR. We have inbound from one global; not pursuing.','target_arr_ipo=500cr',3,true,'Mention inbound carefully — do not name names',false,'rehearsed'),
  ('Nikhil Kamath','Gruhas', now() + interval '7 days','tam','You are essentially a B2B services co — software multiples will not apply.','We are a software-orchestrated marketplace. Engineer matching + AMC pricing + parts ledger are all software-native. Software gross margin = 71% on the orchestration layer.','software_layer_gm=71%',3,false,'Pivotal framing — must rehearse',true,'pending'),
  ('Ritesh Agarwal','Peak XV', now() + interval '5 days','unit_economics','Engineer payout share is 62% — does that not cap your gross margin forever?','62% pays for top-tier engineers (cached_highest_tier=tier_3+). Tier-1 jobs at 48% share. Mix shift to AMC (engineer salaried, not commission) drops blended to 54% by EoY.','tier3_share=62%, tier1_share=48%',3,true,'Strong angle; have engineer-tier waterfall',false,'rehearsed'),
  ('Aditi Mehta','Eight Roads', now() + interval '3 days','moat','Bonded parts inventory is capital-intensive — does it not slow you down?','Bonded program is ₹14L AUM, churns 6x/year, holds 23% gross margin on parts. It is a moat, not a drag — counterfeits intercepted: 12 YTD.','bonded_aum_rupees=14L, bonded_gm=23%',2,true,'Confident on this',false,'rehearsed'),
  ('Pankaj Verma','Tiger Global', now() + interval '8 days','competitive','Tiger has looked at this space — what changed?','You looked in 2023 when nobody had cracked AMC pooling. We have. Plus DPDP came in 2024 — moat for compliant operators.','amc_pooled_hospitals=1412',3,false,'Tiger is anchor target — rehearse twice',true,'pending'),
  ('Shilpa Rao','3one4 Capital', now() + interval '2 days','retention','Engineer 90-day retention 71% is below standard — why?','Industry whisper is 78% but they count enrolled, we count "completed ≥3 jobs". Apples-to-apples we are at 81%.','d90_apples_to_apples=81%',2,true,'Be specific about definition',false,'rehearsed'),
  ('Vivek Iyer','Iron Pillar', now() + interval '6 days','exit_path','Medtech M&A activity in India is thin — is the strategic exit real?','GE Healthcare acquired Wipro Biomed in 2024 (₹2,200Cr). Siemens is hunting India services. Strategic IS the path; IPO is upside.','comp_exit_value=2200cr',3,false,'Have the comparable transactions slide ready',true,'pending');

-- ============================================================================
-- RPC 1: weekly_board_pack_summary_r2889 — top-level KPIs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.weekly_board_pack_summary_r2889()
RETURNS TABLE (
  total_claims bigint,
  locked_claims bigint,
  reconciled_claims bigint,
  high_risk_claims bigint,
  unsupported_claims bigint,
  reconciliation_pct numeric,
  avg_variance_pct numeric,
  upcoming_drills bigint,
  unrehearsed_drills bigint,
  escalation_drills bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM board_pack_narrative_claims_r2889),
    (SELECT count(*) FROM board_pack_narrative_claims_r2889 WHERE status='locked'),
    (SELECT count(*) FROM board_pack_narrative_claims_r2889 WHERE reconciled=true),
    (SELECT count(*) FROM board_pack_narrative_claims_r2889 WHERE narrative_risk IN ('aggressive_spin','unsupported','contradicted')),
    (SELECT count(*) FROM board_pack_narrative_claims_r2889 WHERE narrative_risk='unsupported'),
    ROUND( (SELECT count(*) FILTER (WHERE reconciled=true)::numeric / NULLIF(count(*),0) * 100 FROM board_pack_narrative_claims_r2889), 1),
    ROUND( (SELECT avg(abs(variance_pct)) FROM board_pack_narrative_claims_r2889 WHERE variance_pct IS NOT NULL), 2),
    (SELECT count(*) FROM investor_call_objection_drills_r2889 WHERE call_scheduled_at > now()),
    (SELECT count(*) FROM investor_call_objection_drills_r2889 WHERE rehearsed=false AND call_scheduled_at > now()),
    (SELECT count(*) FROM investor_call_objection_drills_r2889 WHERE escalation_required=true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.weekly_board_pack_summary_r2889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_board_pack_summary_r2889() TO authenticated;

-- ============================================================================
-- RPC 2: narrative_audit_redline_r2889 — claims that need rework before lock
-- ============================================================================
CREATE OR REPLACE FUNCTION public.narrative_audit_redline_r2889()
RETURNS TABLE (
  id uuid,
  section text,
  claim_headline text,
  narrative_risk text,
  reconciled boolean,
  variance_pct numeric,
  investor_qna_likelihood text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT c.id, c.section, c.claim_headline, c.narrative_risk, c.reconciled, c.variance_pct, c.investor_qna_likelihood, c.status
  FROM board_pack_narrative_claims_r2889 c
  WHERE c.narrative_risk IN ('aggressive_spin','unsupported','contradicted')
     OR c.reconciled = false
     OR c.status = 'draft'
  ORDER BY
    CASE c.narrative_risk
      WHEN 'contradicted' THEN 1
      WHEN 'unsupported' THEN 2
      WHEN 'aggressive_spin' THEN 3
      WHEN 'soft_spin' THEN 4
      ELSE 5
    END,
    CASE c.investor_qna_likelihood
      WHEN 'certain' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      ELSE 4
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.narrative_audit_redline_r2889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.narrative_audit_redline_r2889() TO authenticated;

-- ============================================================================
-- RPC 3: section_risk_rollup_r2889 — risk concentration by section
-- ============================================================================
CREATE OR REPLACE FUNCTION public.section_risk_rollup_r2889()
RETURNS TABLE (
  section text,
  total_claims bigint,
  high_risk_claims bigint,
  unsupported_claims bigint,
  locked_claims bigint,
  reconciliation_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.section,
    count(*)::bigint AS total_claims,
    count(*) FILTER (WHERE c.narrative_risk IN ('aggressive_spin','unsupported','contradicted'))::bigint AS high_risk_claims,
    count(*) FILTER (WHERE c.narrative_risk = 'unsupported')::bigint AS unsupported_claims,
    count(*) FILTER (WHERE c.status = 'locked')::bigint AS locked_claims,
    ROUND( count(*) FILTER (WHERE c.reconciled=true)::numeric / NULLIF(count(*),0) * 100, 1) AS reconciliation_pct
  FROM board_pack_narrative_claims_r2889 c
  GROUP BY c.section
  ORDER BY high_risk_claims DESC, total_claims DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.section_risk_rollup_r2889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.section_risk_rollup_r2889() TO authenticated;

-- ============================================================================
-- RPC 4: source_system_reconciliation_r2889 — which data sources lag
-- ============================================================================
CREATE OR REPLACE FUNCTION public.source_system_reconciliation_r2889()
RETURNS TABLE (
  source_system text,
  claims_using_source bigint,
  reconciled_count bigint,
  unreconciled_count bigint,
  reconciliation_pct numeric,
  avg_variance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.source_system,
    count(*)::bigint,
    count(*) FILTER (WHERE c.reconciled = true)::bigint,
    count(*) FILTER (WHERE c.reconciled = false)::bigint,
    ROUND( count(*) FILTER (WHERE c.reconciled=true)::numeric / NULLIF(count(*),0) * 100, 1),
    ROUND( avg(abs(c.variance_pct)), 2)
  FROM board_pack_narrative_claims_r2889 c
  GROUP BY c.source_system
  ORDER BY reconciliation_pct ASC NULLS FIRST, claims_using_source DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.source_system_reconciliation_r2889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.source_system_reconciliation_r2889() TO authenticated;

-- ============================================================================
-- RPC 5: investor_call_pipeline_r2889 — chronological upcoming calls
-- ============================================================================
CREATE OR REPLACE FUNCTION public.investor_call_pipeline_r2889()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_fund text,
  call_scheduled_at timestamptz,
  hours_until_call numeric,
  objection_category text,
  weakness_self_score int,
  rehearsed boolean,
  escalation_required boolean,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.investor_name,
    d.investor_fund,
    d.call_scheduled_at,
    ROUND( EXTRACT(EPOCH FROM (d.call_scheduled_at - now())) / 3600.0, 1) AS hours_until_call,
    d.objection_category,
    d.weakness_self_score,
    d.rehearsed,
    d.escalation_required,
    d.status
  FROM investor_call_objection_drills_r2889 d
  WHERE d.call_scheduled_at > now()
  ORDER BY d.call_scheduled_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.investor_call_pipeline_r2889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.investor_call_pipeline_r2889() TO authenticated;

-- ============================================================================
-- RPC 6: weakness_heatmap_r2889 — objection categories ranked by weakness
-- ============================================================================
CREATE OR REPLACE FUNCTION public.weakness_heatmap_r2889()
RETURNS TABLE (
  objection_category text,
  drills_count bigint,
  avg_weakness numeric,
  unrehearsed_count bigint,
  escalation_count bigint,
  highest_weakness int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.objection_category,
    count(*)::bigint,
    ROUND(avg(d.weakness_self_score)::numeric, 2),
    count(*) FILTER (WHERE d.rehearsed = false)::bigint,
    count(*) FILTER (WHERE d.escalation_required = true)::bigint,
    max(d.weakness_self_score)
  FROM investor_call_objection_drills_r2889 d
  GROUP BY d.objection_category
  ORDER BY avg_weakness DESC, unrehearsed_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.weakness_heatmap_r2889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weakness_heatmap_r2889() TO authenticated;

-- ============================================================================
-- RPC 7: founder_prep_priorities_r2889 — what to rehearse next, ranked
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_prep_priorities_r2889()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_fund text,
  call_scheduled_at timestamptz,
  hours_until_call numeric,
  objection_category text,
  objection_text text,
  weakness_self_score int,
  escalation_required boolean,
  priority_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.investor_name,
    d.investor_fund,
    d.call_scheduled_at,
    ROUND( EXTRACT(EPOCH FROM (d.call_scheduled_at - now())) / 3600.0, 1),
    d.objection_category,
    d.objection_text,
    d.weakness_self_score,
    d.escalation_required,
    ROUND(
      (d.weakness_self_score * 10)::numeric
      + CASE WHEN d.escalation_required THEN 15 ELSE 0 END
      + CASE WHEN d.rehearsed = false THEN 12 ELSE 0 END
      - GREATEST(0, LEAST(20, EXTRACT(EPOCH FROM (d.call_scheduled_at - now())) / 3600.0 / 8))
    , 1) AS priority_score
  FROM investor_call_objection_drills_r2889 d
  WHERE d.call_scheduled_at > now()
    AND d.status IN ('pending','rehearsed')
  ORDER BY priority_score DESC
  LIMIT 12;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_prep_priorities_r2889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_prep_priorities_r2889() TO authenticated;

COMMIT;
