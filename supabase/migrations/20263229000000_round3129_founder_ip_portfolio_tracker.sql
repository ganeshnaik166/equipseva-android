-- Round 3129: Founder Quarterly Strategic Engineer-Founder Patent + IP Portfolio + Trademark Renewal Calendar Tracker
-- Scope: patent applications x jurisdictions x stages x annuity due x trademark renewals x infringement watch x outside counsel cost

BEGIN;

-- =========================================================================
-- TABLE 1: ip_portfolio_assets_r3129
-- Patents, trademarks, copyrights, design rights with stage + jurisdiction + annuity + counsel cost
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.ip_portfolio_assets_r3129 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  asset_code text NOT NULL UNIQUE,
  asset_title text NOT NULL,
  asset_type text NOT NULL CHECK (asset_type IN ('utility_patent','design_patent','trademark','copyright','trade_secret','industrial_design')),
  jurisdiction text NOT NULL CHECK (jurisdiction IN ('IN','US','EU','JP','CN','SG','AE','PCT','MADRID')),
  filing_authority text NOT NULL CHECK (filing_authority IN ('ipo_india','uspto','epo','jpo','cnipa','ipos','uae_moec','wipo_pct','wipo_madrid')),
  current_stage text NOT NULL CHECK (current_stage IN ('draft','filed','examination','office_action','allowed','granted','annuity_due','lapsed','abandoned','opposition')),
  filed_on date,
  granted_on date,
  next_action_due date,
  annuity_fee_inr numeric(12,2) DEFAULT 0,
  counsel_firm text,
  counsel_cost_ytd_inr numeric(12,2) DEFAULT 0,
  strategic_priority text NOT NULL CHECK (strategic_priority IN ('core_moat','defensive','offensive','brand_protection','optional')),
  technology_area text NOT NULL CHECK (technology_area IN ('repair_workflow','tier_calibration','diagnostic_ai','spare_part_provenance','amc_pricing','engineer_routing','hospital_compliance','founder_console','iot_telemetry','rls_audit_engine')),
  infringement_watch_active boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ip_portfolio_assets_r3129 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE 2: ip_calendar_events_r3129
-- Renewal deadlines, office-action responses, infringement watch hits, counsel invoices
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.ip_calendar_events_r3129 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.ip_portfolio_assets_r3129(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('annuity_renewal','office_action_response','trademark_renewal','opposition_window','infringement_alert','counsel_invoice','jurisdictional_entry','examination_request','statement_of_use','assignment_recordal')),
  event_status text NOT NULL CHECK (event_status IN ('upcoming','in_progress','filed','paid','overdue','resolved','escalated','cancelled')),
  due_date date NOT NULL,
  completed_on date,
  cost_estimate_inr numeric(12,2) DEFAULT 0,
  cost_actual_inr numeric(12,2) DEFAULT 0,
  responsible_party text NOT NULL CHECK (responsible_party IN ('founder','outside_counsel','agent_of_record','paralegal','engineer_lead')),
  urgency text NOT NULL CHECK (urgency IN ('p0_critical','p1_high','p2_medium','p3_low')),
  jurisdiction text NOT NULL CHECK (jurisdiction IN ('IN','US','EU','JP','CN','SG','AE','PCT','MADRID')),
  invoice_ref text,
  external_party text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ip_calendar_events_r3129 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- SEED DATA
-- =========================================================================
DO $seed$
DECLARE
  v_org_id uuid;
  v_a1 uuid; v_a2 uuid; v_a3 uuid; v_a4 uuid; v_a5 uuid; v_a6 uuid; v_a7 uuid;
BEGIN
  SELECT id INTO v_org_id FROM public.organizations ORDER BY created_at ASC LIMIT 1;
  IF v_org_id IS NULL THEN
    RAISE NOTICE 'No organizations row; skipping r3129 seed';
    RETURN;
  END IF;

  INSERT INTO public.ip_portfolio_assets_r3129
    (organization_id, asset_code, asset_title, asset_type, jurisdiction, filing_authority, current_stage,
     filed_on, granted_on, next_action_due, annuity_fee_inr, counsel_firm, counsel_cost_ytd_inr,
     strategic_priority, technology_area, infringement_watch_active, notes)
  VALUES
    (v_org_id, 'EQS-PAT-IN-001', 'Tier Calibration Engine for Biomedical Engineers',
     'utility_patent', 'IN', 'ipo_india', 'examination',
     '2025-03-14', NULL, '2026-09-14', 24000, 'K&S Partners Hyderabad', 185000,
     'core_moat', 'tier_calibration', true,
     'Examination report received; response window 6 months'),
    (v_org_id, 'EQS-PAT-PCT-002', 'Spare Part Provenance via Blockchain Bonded Tokens',
     'utility_patent', 'PCT', 'wipo_pct', 'filed',
     '2026-01-22', NULL, '2026-07-22', 0, 'Anand and Anand', 420000,
     'core_moat', 'spare_part_provenance', true,
     'PCT national phase deadline 30 months from priority'),
    (v_org_id, 'EQS-TM-IN-003', 'equipseva wordmark Class 37 + Class 42',
     'trademark', 'IN', 'ipo_india', 'granted',
     '2024-08-10', '2025-12-05', '2034-08-10', 9000, 'LexOrbis', 45000,
     'brand_protection', 'founder_console', true,
     'Renewal due 10 years from filing; opposition period closed'),
    (v_org_id, 'EQS-PAT-US-004', 'AI Diagnostic Routing for Class B Equipment',
     'utility_patent', 'US', 'uspto', 'office_action',
     '2025-06-30', NULL, '2026-08-15', 0, 'Fish and Richardson', 980000,
     'offensive', 'diagnostic_ai', true,
     'Non-final OA; claim narrowing strategy locked'),
    (v_org_id, 'EQS-TM-MAD-005', 'equipseva logo international Madrid filing',
     'trademark', 'MADRID', 'wipo_madrid', 'examination',
     '2026-02-18', NULL, '2026-12-18', 0, 'LexOrbis', 220000,
     'brand_protection', 'founder_console', false,
     'Madrid Protocol filing covering 8 designated countries'),
    (v_org_id, 'EQS-DES-IN-006', 'Engineer App Tier Badge Industrial Design',
     'industrial_design', 'IN', 'ipo_india', 'granted',
     '2025-09-12', '2026-04-22', '2031-09-12', 15000, 'K&S Partners Hyderabad', 38000,
     'defensive', 'engineer_routing', false,
     'Registered design valid 10 years; first renewal in 5'),
    (v_org_id, 'EQS-PAT-EU-007', 'RLS Audit Engine for Multi-Tenant Hospital Data',
     'utility_patent', 'EU', 'epo', 'allowed',
     '2025-01-08', NULL, '2026-07-30', 145000, 'Hoffmann Eitle', 1250000,
     'core_moat', 'rls_audit_engine', true,
     'Grant fee due; validation in 4 EPC states planned'),
    (v_org_id, 'EQS-TS-IN-008', 'AMC Dynamic Pricing Algorithm trade secret',
     'trade_secret', 'IN', 'ipo_india', 'draft',
     NULL, NULL, NULL, 0, 'In-house counsel', 0,
     'core_moat', 'amc_pricing', false,
     'Maintained as trade secret; NDA register active'),
    (v_org_id, 'EQS-PAT-JP-009', 'IoT Telemetry for Predictive Hospital Maintenance',
     'utility_patent', 'JP', 'jpo', 'filed',
     '2026-03-05', NULL, '2029-03-05', 0, 'Shusaku Yamamoto', 340000,
     'defensive', 'iot_telemetry', false,
     'Examination request due within 3 years of filing'),
    (v_org_id, 'EQS-TM-AE-010', 'equipseva Arabic transliteration MENA filing',
     'trademark', 'AE', 'uae_moec', 'opposition',
     '2026-04-19', NULL, '2026-08-19', 18000, 'Al Tamimi and Co', 95000,
     'brand_protection', 'founder_console', true,
     'Opposition by local competitor; defending'),
    (v_org_id, 'EQS-PAT-IN-011', 'Engineer Routing with Tier-Weighted Cost Function',
     'utility_patent', 'IN', 'ipo_india', 'annuity_due',
     '2023-11-04', '2025-08-20', '2026-11-04', 12000, 'K&S Partners Hyderabad', 24000,
     'core_moat', 'engineer_routing', true,
     '3rd annuity due; pay within 6 months grace'),
    (v_org_id, 'EQS-CPY-IN-012', 'Founder Console UI Compose Source Code',
     'copyright', 'IN', 'ipo_india', 'granted',
     '2025-07-14', '2025-11-30', NULL, 0, 'In-house counsel', 8500,
     'defensive', 'founder_console', false,
     'Software copyright registered; lifetime + 60 years');

  SELECT id INTO v_a1 FROM public.ip_portfolio_assets_r3129 WHERE asset_code = 'EQS-PAT-IN-001' LIMIT 1;
  SELECT id INTO v_a2 FROM public.ip_portfolio_assets_r3129 WHERE asset_code = 'EQS-PAT-PCT-002' LIMIT 1;
  SELECT id INTO v_a3 FROM public.ip_portfolio_assets_r3129 WHERE asset_code = 'EQS-TM-IN-003' LIMIT 1;
  SELECT id INTO v_a4 FROM public.ip_portfolio_assets_r3129 WHERE asset_code = 'EQS-PAT-US-004' LIMIT 1;
  SELECT id INTO v_a5 FROM public.ip_portfolio_assets_r3129 WHERE asset_code = 'EQS-PAT-EU-007' LIMIT 1;
  SELECT id INTO v_a6 FROM public.ip_portfolio_assets_r3129 WHERE asset_code = 'EQS-TM-AE-010' LIMIT 1;
  SELECT id INTO v_a7 FROM public.ip_portfolio_assets_r3129 WHERE asset_code = 'EQS-PAT-IN-011' LIMIT 1;

  INSERT INTO public.ip_calendar_events_r3129
    (asset_id, event_type, event_status, due_date, completed_on, cost_estimate_inr, cost_actual_inr,
     responsible_party, urgency, jurisdiction, invoice_ref, external_party, notes)
  VALUES
    (v_a1, 'office_action_response', 'in_progress', '2026-09-14', NULL, 85000, 0,
     'outside_counsel', 'p1_high', 'IN', 'KSP-INV-2026-441', 'K&S Partners Hyderabad',
     'First examination response with claim amendments'),
    (v_a2, 'jurisdictional_entry', 'upcoming', '2027-07-22', NULL, 1800000, 0,
     'founder', 'p2_medium', 'PCT', NULL, 'Anand and Anand',
     'National phase entry decision US/EU/IN/JP'),
    (v_a3, 'trademark_renewal', 'upcoming', '2034-08-10', NULL, 9000, 0,
     'paralegal', 'p3_low', 'IN', NULL, 'LexOrbis',
     '10-year renewal; auto-reminder 18 months prior'),
    (v_a4, 'office_action_response', 'in_progress', '2026-08-15', NULL, 320000, 95000,
     'outside_counsel', 'p0_critical', 'US', 'FR-INV-2026-1188', 'Fish and Richardson',
     'Non-final OA; narrow claim 1 to AI-assisted dispatch'),
    (v_a4, 'counsel_invoice', 'paid', '2026-06-01', '2026-06-04', 280000, 285000,
     'founder', 'p2_medium', 'US', 'FR-INV-2026-1102', 'Fish and Richardson',
     'Prior art search + draft response'),
    (v_a5, 'annuity_renewal', 'upcoming', '2026-07-30', NULL, 145000, 0,
     'outside_counsel', 'p0_critical', 'EU', NULL, 'Hoffmann Eitle',
     'Grant fee + validation in DE/FR/GB/IT'),
    (v_a6, 'opposition_window', 'escalated', '2026-08-19', NULL, 220000, 78000,
     'outside_counsel', 'p0_critical', 'AE', 'TAMIMI-INV-2026-77', 'Al Tamimi and Co',
     'Local competitor opposition; defending Class 37'),
    (v_a7, 'annuity_renewal', 'overdue', '2026-11-04', NULL, 12000, 0,
     'paralegal', 'p1_high', 'IN', NULL, 'K&S Partners Hyderabad',
     '3rd annuity; pay within 6-month grace with surcharge'),
    (v_a1, 'infringement_alert', 'upcoming', '2026-07-15', NULL, 50000, 0,
     'engineer_lead', 'p2_medium', 'IN', NULL, 'Internal IP watch',
     'Competitor app shows similar tier-calibration UX; assess'),
    (v_a3, 'infringement_alert', 'resolved', '2026-05-10', '2026-05-28', 35000, 28000,
     'outside_counsel', 'p2_medium', 'IN', 'LO-INV-2026-512', 'LexOrbis',
     'Cease-and-desist sent; competitor withdrew brand usage'),
    (v_a2, 'counsel_invoice', 'paid', '2026-04-15', '2026-04-18', 420000, 418000,
     'founder', 'p2_medium', 'PCT', 'AA-INV-2026-2201', 'Anand and Anand',
     'PCT filing + international search'),
    (v_a5, 'examination_request', 'filed', '2026-05-20', '2026-05-22', 75000, 72500,
     'outside_counsel', 'p1_high', 'EU', 'HE-INV-2026-908', 'Hoffmann Eitle',
     'Request for grant after Rule 71(3) communication'),
    (v_a4, 'jurisdictional_entry', 'upcoming', '2026-12-01', NULL, 95000, 0,
     'founder', 'p2_medium', 'US', NULL, 'Fish and Richardson',
     'Continuation application strategy review');

END
$seed$;

-- =========================================================================
-- RPCs (founder-gated SECURITY DEFINER plpgsql)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.r3129_portfolio_summary()
RETURNS TABLE (
  asset_type text,
  asset_count bigint,
  active_jurisdictions bigint,
  total_counsel_cost_inr numeric,
  total_annuity_inr numeric,
  watch_active_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.asset_type,
    count(*)::bigint,
    count(DISTINCT a.jurisdiction)::bigint,
    coalesce(sum(a.counsel_cost_ytd_inr),0)::numeric,
    coalesce(sum(a.annuity_fee_inr),0)::numeric,
    count(*) FILTER (WHERE a.infringement_watch_active)::bigint
  FROM public.ip_portfolio_assets_r3129 a
  GROUP BY a.asset_type
  ORDER BY count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_jurisdiction_rollup()
RETURNS TABLE (
  jurisdiction text,
  asset_count bigint,
  granted_count bigint,
  pending_count bigint,
  counsel_spend_inr numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.jurisdiction,
    count(*)::bigint,
    count(*) FILTER (WHERE a.current_stage = 'granted')::bigint,
    count(*) FILTER (WHERE a.current_stage IN ('draft','filed','examination','office_action','allowed','opposition'))::bigint,
    coalesce(sum(a.counsel_cost_ytd_inr),0)::numeric
  FROM public.ip_portfolio_assets_r3129 a
  GROUP BY a.jurisdiction
  ORDER BY count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_upcoming_deadlines(p_days int DEFAULT 180)
RETURNS TABLE (
  asset_code text,
  asset_title text,
  event_type text,
  due_date date,
  days_to_due int,
  urgency text,
  jurisdiction text,
  cost_estimate_inr numeric,
  responsible_party text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.asset_code,
    a.asset_title,
    e.event_type,
    e.due_date,
    (e.due_date - current_date)::int,
    e.urgency,
    e.jurisdiction,
    e.cost_estimate_inr,
    e.responsible_party
  FROM public.ip_calendar_events_r3129 e
  JOIN public.ip_portfolio_assets_r3129 a ON a.id = e.asset_id
  WHERE e.event_status IN ('upcoming','in_progress','overdue','escalated')
    AND e.due_date <= current_date + p_days
  ORDER BY e.due_date ASC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_counsel_spend_by_firm()
RETURNS TABLE (
  counsel_firm text,
  asset_count bigint,
  ytd_spend_inr numeric,
  event_invoiced_inr numeric,
  total_inr numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    coalesce(a.counsel_firm, 'unassigned'),
    count(DISTINCT a.id)::bigint,
    coalesce(sum(a.counsel_cost_ytd_inr),0)::numeric,
    coalesce((SELECT sum(e.cost_actual_inr) FROM public.ip_calendar_events_r3129 e
              JOIN public.ip_portfolio_assets_r3129 a2 ON a2.id = e.asset_id
              WHERE a2.counsel_firm = a.counsel_firm
                AND e.event_type = 'counsel_invoice'
                AND e.event_status = 'paid'),0)::numeric,
    (coalesce(sum(a.counsel_cost_ytd_inr),0) +
      coalesce((SELECT sum(e.cost_actual_inr) FROM public.ip_calendar_events_r3129 e
                JOIN public.ip_portfolio_assets_r3129 a2 ON a2.id = e.asset_id
                WHERE a2.counsel_firm = a.counsel_firm
                  AND e.event_type = 'counsel_invoice'
                  AND e.event_status = 'paid'),0)
    )::numeric
  FROM public.ip_portfolio_assets_r3129 a
  GROUP BY a.counsel_firm
  ORDER BY 5 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_stage_pipeline()
RETURNS TABLE (
  current_stage text,
  asset_count bigint,
  total_annuity_inr numeric,
  next_30d_events bigint,
  next_90d_events bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.current_stage,
    count(*)::bigint,
    coalesce(sum(a.annuity_fee_inr),0)::numeric,
    (SELECT count(*) FROM public.ip_calendar_events_r3129 e
     WHERE e.asset_id IN (SELECT id FROM public.ip_portfolio_assets_r3129 WHERE current_stage = a.current_stage)
       AND e.due_date BETWEEN current_date AND current_date + 30
       AND e.event_status IN ('upcoming','in_progress','overdue'))::bigint,
    (SELECT count(*) FROM public.ip_calendar_events_r3129 e
     WHERE e.asset_id IN (SELECT id FROM public.ip_portfolio_assets_r3129 WHERE current_stage = a.current_stage)
       AND e.due_date BETWEEN current_date AND current_date + 90
       AND e.event_status IN ('upcoming','in_progress','overdue'))::bigint
  FROM public.ip_portfolio_assets_r3129 a
  GROUP BY a.current_stage
  ORDER BY count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_infringement_watch()
RETURNS TABLE (
  asset_code text,
  asset_title text,
  technology_area text,
  jurisdiction text,
  open_alerts bigint,
  resolved_alerts bigint,
  total_response_inr numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.asset_code,
    a.asset_title,
    a.technology_area,
    a.jurisdiction,
    count(*) FILTER (WHERE e.event_status IN ('upcoming','in_progress','escalated'))::bigint,
    count(*) FILTER (WHERE e.event_status = 'resolved')::bigint,
    coalesce(sum(e.cost_actual_inr),0)::numeric
  FROM public.ip_portfolio_assets_r3129 a
  LEFT JOIN public.ip_calendar_events_r3129 e
    ON e.asset_id = a.id AND e.event_type = 'infringement_alert'
  WHERE a.infringement_watch_active
  GROUP BY a.id, a.asset_code, a.asset_title, a.technology_area, a.jurisdiction
  ORDER BY 5 DESC, a.asset_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_priority_strategic_map()
RETURNS TABLE (
  strategic_priority text,
  technology_area text,
  asset_count bigint,
  granted_count bigint,
  counsel_spend_inr numeric,
  watch_active_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.strategic_priority,
    a.technology_area,
    count(*)::bigint,
    count(*) FILTER (WHERE a.current_stage = 'granted')::bigint,
    coalesce(sum(a.counsel_cost_ytd_inr),0)::numeric,
    count(*) FILTER (WHERE a.infringement_watch_active)::bigint
  FROM public.ip_portfolio_assets_r3129 a
  GROUP BY a.strategic_priority, a.technology_area
  ORDER BY a.strategic_priority, count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_overdue_actions()
RETURNS TABLE (
  asset_code text,
  event_type text,
  jurisdiction text,
  due_date date,
  days_overdue int,
  urgency text,
  cost_estimate_inr numeric,
  responsible_party text,
  external_party text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.asset_code,
    e.event_type,
    e.jurisdiction,
    e.due_date,
    GREATEST(0,(current_date - e.due_date))::int,
    e.urgency,
    e.cost_estimate_inr,
    e.responsible_party,
    e.external_party
  FROM public.ip_calendar_events_r3129 e
  JOIN public.ip_portfolio_assets_r3129 a ON a.id = e.asset_id
  WHERE e.event_status IN ('overdue','escalated')
     OR (e.event_status IN ('upcoming','in_progress') AND e.due_date < current_date)
  ORDER BY e.due_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r3129_quarterly_burn()
RETURNS TABLE (
  fiscal_quarter text,
  events_paid bigint,
  events_upcoming bigint,
  paid_inr numeric,
  upcoming_estimate_inr numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(coalesce(e.completed_on, e.due_date), '"FY"YYYY"-Q"Q'),
    count(*) FILTER (WHERE e.event_status = 'paid')::bigint,
    count(*) FILTER (WHERE e.event_status IN ('upcoming','in_progress','overdue'))::bigint,
    coalesce(sum(e.cost_actual_inr) FILTER (WHERE e.event_status = 'paid'),0)::numeric,
    coalesce(sum(e.cost_estimate_inr) FILTER (WHERE e.event_status IN ('upcoming','in_progress','overdue')),0)::numeric
  FROM public.ip_calendar_events_r3129 e
  GROUP BY to_char(coalesce(e.completed_on, e.due_date), '"FY"YYYY"-Q"Q')
  ORDER BY 1;
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.r3129_portfolio_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_jurisdiction_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_upcoming_deadlines(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_counsel_spend_by_firm() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_stage_pipeline() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_infringement_watch() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_priority_strategic_map() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_overdue_actions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r3129_quarterly_burn() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r3129_portfolio_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_jurisdiction_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_upcoming_deadlines(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_counsel_spend_by_firm() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_stage_pipeline() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_infringement_watch() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_priority_strategic_map() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_overdue_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r3129_quarterly_burn() TO authenticated;

COMMIT;
