-- Round 2917 — Founder Monthly Strategic ESG & Sustainability Investor Letter Audit
-- HEAVY founder ops round: 2 tables + 7 RPCs

BEGIN;

-- ============================================================================
-- TABLE 1: esg_letter_drafts_r2917
-- Monthly ESG investor letter draft tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.esg_letter_drafts_r2917 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  letter_period text NOT NULL,
  draft_version int NOT NULL DEFAULT 1,
  section_name text NOT NULL,
  section_status text NOT NULL CHECK (section_status IN ('draft','reviewed','approved','published','rework')),
  author_role text NOT NULL,
  word_count int NOT NULL DEFAULT 0,
  esg_pillar text NOT NULL CHECK (esg_pillar IN ('environmental','social','governance','overall')),
  carbon_metric_tons_co2 numeric(10,2),
  social_impact_score int CHECK (social_impact_score BETWEEN 0 AND 100),
  governance_score int CHECK (governance_score BETWEEN 0 AND 100),
  citations_count int NOT NULL DEFAULT 0,
  fact_check_status text NOT NULL DEFAULT 'pending' CHECK (fact_check_status IN ('pending','verified','flagged','failed')),
  reviewer_notes text,
  target_send_at timestamptz NOT NULL,
  sent_at timestamptz
);

ALTER TABLE public.esg_letter_drafts_r2917 ENABLE ROW LEVEL SECURITY;

CREATE POLICY esg_letter_drafts_r2917_founder_all ON public.esg_letter_drafts_r2917
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.esg_letter_drafts_r2917
  (letter_period, draft_version, section_name, section_status, author_role, word_count, esg_pillar, carbon_metric_tons_co2, social_impact_score, governance_score, citations_count, fact_check_status, reviewer_notes, target_send_at, sent_at)
VALUES
  ('2026-06', 3, 'Executive Summary', 'approved', 'founder', 412, 'overall', 18.40, 82, 88, 6, 'verified', 'tightened opening hook', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 2, 'Carbon Footprint Report', 'reviewed', 'esg_lead', 680, 'environmental', 18.40, NULL, NULL, 12, 'verified', 'scope 3 estimate needs disclosure', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 2, 'Engineer Livelihood Impact', 'approved', 'social_lead', 540, 'social', NULL, 91, NULL, 8, 'verified', '47 engineers crossed Tier-3', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 1, 'DPDP Compliance Update', 'draft', 'legal_counsel', 320, 'governance', NULL, NULL, 88, 4, 'pending', NULL, '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 2, 'Board Diversity', 'reviewed', 'governance_lead', 280, 'governance', NULL, NULL, 75, 3, 'verified', 'note pending 1 female director add', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 1, 'Spare Parts Circularity', 'rework', 'ops_lead', 410, 'environmental', 4.20, NULL, NULL, 5, 'flagged', 'remanufacture % not sourced', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 3, 'Hospital Customer Stories', 'approved', 'marketing', 620, 'social', NULL, 86, NULL, 7, 'verified', '3 case studies anonymized', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 2, 'Travel Emissions Truck-roll', 'reviewed', 'ops_lead', 380, 'environmental', 11.80, NULL, NULL, 9, 'verified', 'route optimization saved 22%', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 1, 'Whistleblower Hotline Stats', 'draft', 'governance_lead', 220, 'governance', NULL, NULL, 70, 2, 'pending', 'awaiting Q numbers', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 2, 'Tier-progression Equity', 'approved', 'social_lead', 460, 'social', NULL, 89, NULL, 6, 'verified', 'no caste-based disparity', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-05', 4, 'Executive Summary', 'published', 'founder', 405, 'overall', 16.20, 84, 86, 7, 'verified', 'shipped', '2026-06-01 09:00:00+05:30'::timestamptz, '2026-06-01 09:14:00+05:30'::timestamptz),
  ('2026-05', 3, 'Carbon Footprint Report', 'published', 'esg_lead', 645, 'environmental', 16.20, NULL, NULL, 11, 'verified', 'baseline locked', '2026-06-01 09:00:00+05:30'::timestamptz, '2026-06-01 09:14:00+05:30'::timestamptz),
  ('2026-05', 2, 'Engineer Livelihood Impact', 'published', 'social_lead', 510, 'social', NULL, 87, NULL, 8, 'verified', 'shipped', '2026-06-01 09:00:00+05:30'::timestamptz, '2026-06-01 09:14:00+05:30'::timestamptz),
  ('2026-05', 2, 'DPDP Compliance Update', 'published', 'legal_counsel', 300, 'governance', NULL, NULL, 85, 5, 'verified', 'shipped', '2026-06-01 09:00:00+05:30'::timestamptz, '2026-06-01 09:14:00+05:30'::timestamptz),
  ('2026-06', 1, 'Forward Outlook ESG', 'draft', 'founder', 280, 'overall', NULL, 80, 82, 3, 'pending', 'links to v0.5 roadmap', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 2, 'Water & Power at Branches', 'reviewed', 'ops_lead', 240, 'environmental', 2.10, NULL, NULL, 4, 'verified', '3 branches metered', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 1, 'Cybersecurity Posture', 'draft', 'governance_lead', 350, 'governance', NULL, NULL, 78, 5, 'pending', 'pen-test sched', '2026-07-01 09:00:00+05:30'::timestamptz, NULL),
  ('2026-06', 2, 'Patient Safety Incidents', 'approved', 'qa_lead', 420, 'social', NULL, 95, NULL, 6, 'verified', 'zero P0 last 90 days', '2026-07-01 09:00:00+05:30'::timestamptz, NULL);

-- ============================================================================
-- TABLE 2: esg_letter_audit_findings_r2917
-- Audit findings per section / per investor recipient
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.esg_letter_audit_findings_r2917 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  letter_period text NOT NULL,
  finding_category text NOT NULL CHECK (finding_category IN ('factual','tone','disclosure','greenwashing','citation','metric_drift','tcfd_alignment','sasb_alignment','redundancy')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  section_name text NOT NULL,
  finding_summary text NOT NULL,
  remediation_action text NOT NULL,
  owner_role text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','resolved','wont_fix','accepted_risk')),
  detected_at timestamptz NOT NULL,
  resolved_at timestamptz,
  investor_facing boolean NOT NULL DEFAULT true,
  cited_framework text,
  confidence_score int CHECK (confidence_score BETWEEN 0 AND 100)
);

ALTER TABLE public.esg_letter_audit_findings_r2917 ENABLE ROW LEVEL SECURITY;

CREATE POLICY esg_letter_audit_findings_r2917_founder_all ON public.esg_letter_audit_findings_r2917
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.esg_letter_audit_findings_r2917
  (letter_period, finding_category, severity, section_name, finding_summary, remediation_action, owner_role, status, detected_at, resolved_at, investor_facing, cited_framework, confidence_score)
VALUES
  ('2026-06', 'greenwashing', 'p1', 'Spare Parts Circularity', 'remanufacture % stated without source', 'add citation or restate as estimate', 'ops_lead', 'open', '2026-06-18 11:00:00+05:30'::timestamptz, NULL, true, 'GRI 301', 92),
  ('2026-06', 'metric_drift', 'p2', 'Carbon Footprint Report', 'scope 3 jumped 28% MoM with no narrative', 'add commentary on truck-roll growth', 'esg_lead', 'in_progress', '2026-06-19 09:30:00+05:30'::timestamptz, NULL, true, 'GHG Protocol', 88),
  ('2026-06', 'factual', 'p0', 'Engineer Livelihood Impact', 'claimed 50 engineers Tier-3, actual 47', 'correct to 47, add YoY delta', 'social_lead', 'resolved', '2026-06-17 14:20:00+05:30'::timestamptz, '2026-06-17 18:00:00+05:30'::timestamptz, true, 'SASB SV-PS', 99),
  ('2026-06', 'disclosure', 'p1', 'Board Diversity', 'female director seat vacant since Mar', 'disclose timeline to fill', 'governance_lead', 'open', '2026-06-19 10:00:00+05:30'::timestamptz, NULL, true, 'TCFD Governance', 85),
  ('2026-06', 'citation', 'p2', 'DPDP Compliance Update', '3 of 4 citations broken or paywalled', 'replace with primary sources', 'legal_counsel', 'in_progress', '2026-06-20 08:45:00+05:30'::timestamptz, NULL, true, NULL, 90),
  ('2026-06', 'tone', 'p3', 'Executive Summary', 'tone slightly defensive on Q1 outage', 'soften, lead with learning', 'founder', 'resolved', '2026-06-19 16:10:00+05:30'::timestamptz, '2026-06-20 09:00:00+05:30'::timestamptz, true, NULL, 70),
  ('2026-06', 'tcfd_alignment', 'p1', 'Forward Outlook ESG', 'no physical climate risk para', 'add monsoon flood exposure note', 'esg_lead', 'open', '2026-06-20 11:30:00+05:30'::timestamptz, NULL, true, 'TCFD Risk', 87),
  ('2026-06', 'sasb_alignment', 'p2', 'Patient Safety Incidents', 'SASB HC-MS metric not labeled', 'tag metrics with SASB code', 'qa_lead', 'open', '2026-06-20 13:00:00+05:30'::timestamptz, NULL, true, 'SASB HC-MS', 82),
  ('2026-06', 'redundancy', 'p3', 'Hospital Customer Stories', 'story 2 overlaps with May letter', 'replace or cross-reference', 'marketing', 'in_progress', '2026-06-19 17:00:00+05:30'::timestamptz, NULL, true, NULL, 75),
  ('2026-06', 'greenwashing', 'p2', 'Travel Emissions Truck-roll', 'phrase "carbon-neutral routes" unsupported', 'restate as "optimized routes"', 'ops_lead', 'resolved', '2026-06-18 12:15:00+05:30'::timestamptz, '2026-06-19 10:00:00+05:30'::timestamptz, true, 'GHG Protocol', 94),
  ('2026-06', 'factual', 'p1', 'Whistleblower Hotline Stats', 'figures conflict with internal dashboard', 'reconcile with governance dash', 'governance_lead', 'open', '2026-06-20 09:00:00+05:30'::timestamptz, NULL, true, NULL, 91),
  ('2026-06', 'disclosure', 'p2', 'Cybersecurity Posture', 'pen-test date not committed', 'add concrete Q3 target date', 'governance_lead', 'open', '2026-06-20 11:00:00+05:30'::timestamptz, NULL, true, 'ISO 27001', 80),
  ('2026-05', 'factual', 'p1', 'Carbon Footprint Report', 'scope 2 mis-stated by 1.4 tons', 'corrected in v4', 'esg_lead', 'resolved', '2026-05-29 14:00:00+05:30'::timestamptz, '2026-05-31 10:00:00+05:30'::timestamptz, true, 'GHG Protocol', 96),
  ('2026-05', 'tone', 'p3', 'Executive Summary', 'opening too promotional', 'rewrite hook', 'founder', 'resolved', '2026-05-28 11:00:00+05:30'::timestamptz, '2026-05-29 09:00:00+05:30'::timestamptz, true, NULL, 68),
  ('2026-06', 'metric_drift', 'p1', 'Tier-progression Equity', 'parity index dipped 6pts with no flag', 'add explanation paragraph', 'social_lead', 'in_progress', '2026-06-20 15:00:00+05:30'::timestamptz, NULL, true, 'SASB SV-PS', 86),
  ('2026-06', 'tcfd_alignment', 'p2', 'Water & Power at Branches', 'no scenario analysis attempted', 'flag as deferred to FY27', 'ops_lead', 'accepted_risk', '2026-06-20 16:00:00+05:30'::timestamptz, '2026-06-20 16:30:00+05:30'::timestamptz, true, 'TCFD Strategy', 78);

-- ============================================================================
-- RPC 1: section_status_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2917_section_status_summary()
RETURNS TABLE(section_status text, sections int, total_words bigint, avg_citations numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.section_status, COUNT(*)::int, SUM(d.word_count)::bigint, ROUND(AVG(d.citations_count)::numeric, 2)
  FROM public.esg_letter_drafts_r2917 d
  WHERE d.letter_period = '2026-06'
  GROUP BY d.section_status
  ORDER BY COUNT(*) DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION public.r2917_section_status_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2917_section_status_summary() TO authenticated;

-- ============================================================================
-- RPC 2: pillar_metric_rollup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2917_pillar_metric_rollup()
RETURNS TABLE(esg_pillar text, sections int, total_co2 numeric, avg_social_score numeric, avg_governance_score numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.esg_pillar,
         COUNT(*)::int,
         COALESCE(SUM(d.carbon_metric_tons_co2),0)::numeric,
         ROUND(AVG(d.social_impact_score)::numeric, 2),
         ROUND(AVG(d.governance_score)::numeric, 2)
  FROM public.esg_letter_drafts_r2917 d
  WHERE d.letter_period = '2026-06'
  GROUP BY d.esg_pillar
  ORDER BY d.esg_pillar;
END; $$;

REVOKE EXECUTE ON FUNCTION public.r2917_pillar_metric_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2917_pillar_metric_rollup() TO authenticated;

-- ============================================================================
-- RPC 3: open_findings_by_severity
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2917_open_findings_by_severity()
RETURNS TABLE(severity text, open_count int, p0_p1_share numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.esg_letter_audit_findings_r2917
   WHERE letter_period='2026-06' AND status IN ('open','in_progress');
  RETURN QUERY
  SELECT f.severity, COUNT(*)::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE f.severity IN ('p0','p1')) / NULLIF(v_total,0), 2)
  FROM public.esg_letter_audit_findings_r2917 f
  WHERE f.letter_period = '2026-06' AND f.status IN ('open','in_progress')
  GROUP BY f.severity
  ORDER BY f.severity;
END; $$;

REVOKE EXECUTE ON FUNCTION public.r2917_open_findings_by_severity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2917_open_findings_by_severity() TO authenticated;

-- ============================================================================
-- RPC 4: greenwashing_radar
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2917_greenwashing_radar()
RETURNS TABLE(section_name text, finding_summary text, severity text, status text, confidence_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.section_name, f.finding_summary, f.severity, f.status, f.confidence_score
  FROM public.esg_letter_audit_findings_r2917 f
  WHERE f.finding_category = 'greenwashing'
    AND f.letter_period = '2026-06'
  ORDER BY f.severity, f.confidence_score DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION public.r2917_greenwashing_radar() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2917_greenwashing_radar() TO authenticated;

-- ============================================================================
-- RPC 5: framework_alignment_coverage
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2917_framework_alignment_coverage()
RETURNS TABLE(framework text, findings_referencing int, open_count int, resolved_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(f.cited_framework, 'unspecified') AS framework,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE f.status IN ('open','in_progress'))::int,
         COUNT(*) FILTER (WHERE f.status = 'resolved')::int
  FROM public.esg_letter_audit_findings_r2917 f
  GROUP BY COALESCE(f.cited_framework, 'unspecified')
  ORDER BY COUNT(*) DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION public.r2917_framework_alignment_coverage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2917_framework_alignment_coverage() TO authenticated;

-- ============================================================================
-- RPC 6: send_readiness_checklist
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2917_send_readiness_checklist()
RETURNS TABLE(section_name text, section_status text, fact_check_status text, blocking_findings int, ready boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.section_name,
         d.section_status,
         d.fact_check_status,
         COALESCE((SELECT COUNT(*)::int FROM public.esg_letter_audit_findings_r2917 f
                    WHERE f.letter_period='2026-06'
                      AND f.section_name = d.section_name
                      AND f.status IN ('open','in_progress')
                      AND f.severity IN ('p0','p1')), 0) AS blocking_findings,
         (d.section_status IN ('approved','published')
            AND d.fact_check_status = 'verified'
            AND COALESCE((SELECT COUNT(*) FROM public.esg_letter_audit_findings_r2917 f
                    WHERE f.letter_period='2026-06'
                      AND f.section_name = d.section_name
                      AND f.status IN ('open','in_progress')
                      AND f.severity IN ('p0','p1')), 0) = 0) AS ready
  FROM public.esg_letter_drafts_r2917 d
  WHERE d.letter_period = '2026-06'
  ORDER BY ready ASC, d.section_name;
END; $$;

REVOKE EXECUTE ON FUNCTION public.r2917_send_readiness_checklist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2917_send_readiness_checklist() TO authenticated;

-- ============================================================================
-- RPC 7: month_over_month_progress
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2917_month_over_month_progress()
RETURNS TABLE(letter_period text, total_sections int, published int, total_findings int, p0_p1_findings int, resolved_findings int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.letter_period,
         COUNT(DISTINCT d.section_name)::int,
         COUNT(*) FILTER (WHERE d.section_status = 'published')::int,
         COALESCE((SELECT COUNT(*)::int FROM public.esg_letter_audit_findings_r2917 f WHERE f.letter_period = d.letter_period), 0),
         COALESCE((SELECT COUNT(*)::int FROM public.esg_letter_audit_findings_r2917 f WHERE f.letter_period = d.letter_period AND f.severity IN ('p0','p1')), 0),
         COALESCE((SELECT COUNT(*)::int FROM public.esg_letter_audit_findings_r2917 f WHERE f.letter_period = d.letter_period AND f.status = 'resolved'), 0)
  FROM public.esg_letter_drafts_r2917 d
  GROUP BY d.letter_period
  ORDER BY d.letter_period DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION public.r2917_month_over_month_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2917_month_over_month_progress() TO authenticated;

COMMIT;
