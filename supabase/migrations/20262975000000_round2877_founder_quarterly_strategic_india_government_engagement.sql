BEGIN;

-- ============================================================================
-- Round 2877: Founder Quarterly Strategic India Government Engagement
-- event × department × topic × ask × commitment × business impact × follow-up
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: gov_engagement_events_r2877
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS gov_engagement_events_r2877 CASCADE;

CREATE TABLE gov_engagement_events_r2877 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_code text UNIQUE NOT NULL,
  event_name text NOT NULL,
  event_date date NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('q1_2026','q2_2026','q3_2026','q4_2026','q1_2027')),
  department text NOT NULL CHECK (department IN ('mohfw','meity','dpiit','niti_aayog','cdsco','startup_india','make_in_india','ayush')),
  ministry_level text NOT NULL CHECK (ministry_level IN ('minister','secretary','joint_secretary','director','deputy_secretary')),
  topic text NOT NULL,
  founder_ask text NOT NULL,
  commitment_received text,
  business_impact_inr_cr numeric(10,2) NOT NULL DEFAULT 0,
  follow_up_status text NOT NULL CHECK (follow_up_status IN ('pending','in_progress','blocked','completed','escalated')),
  next_action_date date,
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE gov_engagement_events_r2877 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON gov_engagement_events_r2877;
CREATE POLICY founder_all ON gov_engagement_events_r2877
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO gov_engagement_events_r2877
  (event_code, event_name, event_date, quarter, department, ministry_level, topic, founder_ask, commitment_received, business_impact_inr_cr, follow_up_status, next_action_date, priority)
VALUES
  ('EVT-2877-001', 'MoHFW Medical Device Roundtable Q1', '2026-02-14'::date, 'q1_2026', 'mohfw', 'secretary', 'medical_device_servicing_certification_standardization', 'national_recognition_for_equipseva_engineer_certification_ladder', 'pilot_with_aiims_delhi_signed_off', 42.50, 'in_progress', '2026-07-15'::date, 'p0'),
  ('EVT-2877-002', 'CDSCO Class A/B Compliance Meeting', '2026-03-22'::date, 'q1_2026', 'cdsco', 'joint_secretary', 'bonded_parts_provenance_track_and_trace_mandate', 'extend_provenance_mandate_to_all_class_b_devices_nationally', 'draft_circular_under_legal_review', 78.20, 'in_progress', '2026-08-01'::date, 'p0'),
  ('EVT-2877-003', 'MeitY Startup India Demo Day Q2', '2026-04-18'::date, 'q2_2026', 'meity', 'minister', 'AI_triage_for_hospital_repair_jobs_DPDP_compliance', 'inclusion_in_BHASHINI_partner_program', 'verbal_yes_pending_MOU', 18.75, 'pending', '2026-07-20'::date, 'p1'),
  ('EVT-2877-004', 'NITI Aayog Healthcare Innovation Council', '2026-05-09'::date, 'q2_2026', 'niti_aayog', 'director', 'unit_economics_data_share_for_rural_hospital_AMC_pricing', 'data_to_inform_PMJAY_reimbursement_for_device_servicing', 'data_submission_window_until_2026_09_30', 125.00, 'in_progress', '2026-09-15'::date, 'p0'),
  ('EVT-2877-005', 'DPIIT Make in India Manufacturing Summit', '2026-06-12'::date, 'q2_2026', 'dpiit', 'secretary', 'bonded_parts_provenance_made_in_india_label_certification', 'fast_track_PLI_scheme_inclusion_for_OEM_partners', 'application_submitted_under_review', 56.40, 'in_progress', '2026-08-10'::date, 'p1'),
  ('EVT-2877-006', 'Startup India BHASHINI Hindi Telugu Integration', '2026-06-25'::date, 'q2_2026', 'startup_india', 'deputy_secretary', 'hindi_telugu_engineer_app_localization_government_subsidy', 'grant_application_invited', 'grant_approved_rs_85_lakh', 8.50, 'completed', '2026-07-30'::date, 'p2'),
  ('EVT-2877-007', 'AYUSH Ministry Equipment Servicing Pilot', '2026-05-28'::date, 'q2_2026', 'ayush', 'joint_secretary', 'panchakarma_clinic_equipment_AMC_pilot_in_5_states', 'commission_pilot_at_state_AYUSH_hospitals', 'pilot_at_kerala_karnataka_andhra_signed', 32.10, 'in_progress', '2026-09-20'::date, 'p1'),
  ('EVT-2877-008', 'CDSCO Counterfeit Parts Crackdown Steering', '2026-06-05'::date, 'q2_2026', 'cdsco', 'director', 'mandatory_repair_engineer_supervisor_liveness_certification', 'add_to_class_b_device_servicing_rules_2027', 'gazette_notification_drafted', 95.80, 'escalated', '2026-08-25'::date, 'p0');

-- ----------------------------------------------------------------------------
-- Table 2: gov_engagement_followups_r2877
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS gov_engagement_followups_r2877 CASCADE;

CREATE TABLE gov_engagement_followups_r2877 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_code text NOT NULL REFERENCES gov_engagement_events_r2877(event_code) ON DELETE CASCADE,
  followup_date date NOT NULL,
  channel text NOT NULL CHECK (channel IN ('email','letter','meeting','phone_call','site_visit','submission_portal')),
  contact_person text NOT NULL,
  contact_designation text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','blocked','needs_escalation','closed_won','closed_lost')),
  notes text NOT NULL,
  hours_invested numeric(5,2) NOT NULL DEFAULT 0,
  next_step text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE gov_engagement_followups_r2877 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON gov_engagement_followups_r2877;
CREATE POLICY founder_all ON gov_engagement_followups_r2877
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO gov_engagement_followups_r2877
  (event_code, followup_date, channel, contact_person, contact_designation, outcome, notes, hours_invested, next_step)
VALUES
  ('EVT-2877-001', '2026-04-10'::date, 'meeting', 'dr_rajesh_kumar', 'secretary_mohfw', 'positive', 'AIIMS Delhi pilot MOU draft circulated; needs CEO countersign before 2026-07-15', 6.50, 'send_signed_MOU_to_mohfw_undersecretary_by_2026_07_10'),
  ('EVT-2877-002', '2026-05-02'::date, 'submission_portal', 'shri_ananth_reddy', 'joint_secretary_cdsco', 'positive', 'Bonded provenance technical annexure accepted; legal review at solicitor general level', 4.25, 'await_gazette_notification_draft_response_by_2026_08_01'),
  ('EVT-2877-003', '2026-06-01'::date, 'email', 'smt_priya_iyer', 'director_meity', 'needs_escalation', 'BHASHINI MOU stuck at legal vetting since 2026-04-22; founder note sent to minister office', 1.75, 'request_personal_meeting_with_minister_PA_during_quarterly_visit'),
  ('EVT-2877-004', '2026-06-18'::date, 'meeting', 'dr_amitabh_kant', 'director_niti_aayog', 'positive', 'Unit economics dataset format finalized; AMC tier-1 + tier-2 + tier-3 data needed for 18 months', 8.00, 'data_engineering_team_to_export_anonymized_dataset_by_2026_09_01'),
  ('EVT-2877-005', '2026-06-20'::date, 'site_visit', 'shri_vikram_doraiswami', 'secretary_dpiit', 'positive', 'PLI scheme application reviewed favorably; OEM partner letters of intent attached', 12.00, 'submit_revised_business_plan_with_5_year_revenue_projection_by_2026_07_25'),
  ('EVT-2877-006', '2026-07-05'::date, 'submission_portal', 'shri_chandra_mohan', 'deputy_secretary_startup_india', 'closed_won', 'BHASHINI grant rs 85 lakh disbursed to escrow; first tranche received', 3.50, 'submit_q1_progress_report_with_user_metrics_by_2026_10_15'),
  ('EVT-2877-007', '2026-06-30'::date, 'meeting', 'dr_pratap_chauhan', 'joint_secretary_ayush', 'positive', 'Kerala AYUSH hospital pilot started; karnataka onboarding next week', 5.25, 'site_visit_to_bangalore_AYUSH_hospital_by_2026_08_05'),
  ('EVT-2877-008', '2026-07-02'::date, 'letter', 'dr_renu_swarup', 'director_cdsco', 'blocked', 'Gazette notification on supervisor liveness held up over privacy concerns by DPDP authority', 2.00, 'co_sign_with_DPDP_authority_letter_addressing_consent_flow_by_2026_08_15');

-- ============================================================================
-- RPC 1: List engagement events for current quarter
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_events_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_events_r2877()
RETURNS TABLE (
  id uuid,
  event_code text,
  event_name text,
  event_date date,
  quarter text,
  department text,
  ministry_level text,
  topic text,
  founder_ask text,
  commitment_received text,
  business_impact_inr_cr numeric,
  follow_up_status text,
  priority text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT e.id, e.event_code, e.event_name, e.event_date, e.quarter, e.department, e.ministry_level,
         e.topic, e.founder_ask, e.commitment_received, e.business_impact_inr_cr, e.follow_up_status, e.priority
  FROM gov_engagement_events_r2877 e
  ORDER BY e.event_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_events_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_events_r2877() TO authenticated;

-- ============================================================================
-- RPC 2: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_kpis_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_kpis_r2877()
RETURNS TABLE (
  total_events int,
  total_business_impact_cr numeric,
  active_engagements int,
  p0_priority_count int,
  completed_count int,
  escalated_count int,
  total_hours_invested numeric,
  departments_engaged int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM gov_engagement_events_r2877),
    (SELECT COALESCE(SUM(business_impact_inr_cr), 0) FROM gov_engagement_events_r2877),
    (SELECT COUNT(*)::int FROM gov_engagement_events_r2877 WHERE follow_up_status IN ('pending','in_progress')),
    (SELECT COUNT(*)::int FROM gov_engagement_events_r2877 WHERE priority = 'p0'),
    (SELECT COUNT(*)::int FROM gov_engagement_events_r2877 WHERE follow_up_status = 'completed'),
    (SELECT COUNT(*)::int FROM gov_engagement_events_r2877 WHERE follow_up_status = 'escalated'),
    (SELECT COALESCE(SUM(hours_invested), 0) FROM gov_engagement_followups_r2877),
    (SELECT COUNT(DISTINCT department)::int FROM gov_engagement_events_r2877);
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_kpis_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_kpis_r2877() TO authenticated;

-- ============================================================================
-- RPC 3: Department breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_by_department_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_by_department_r2877()
RETURNS TABLE (
  department text,
  event_count int,
  total_impact_cr numeric,
  p0_count int,
  active_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.department,
    COUNT(*)::int,
    COALESCE(SUM(e.business_impact_inr_cr), 0),
    COUNT(*) FILTER (WHERE e.priority = 'p0')::int,
    COUNT(*) FILTER (WHERE e.follow_up_status IN ('pending','in_progress'))::int
  FROM gov_engagement_events_r2877 e
  GROUP BY e.department
  ORDER BY COALESCE(SUM(e.business_impact_inr_cr), 0) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_by_department_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_by_department_r2877() TO authenticated;

-- ============================================================================
-- RPC 4: Follow-up activity log
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_followups_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_followups_r2877()
RETURNS TABLE (
  id uuid,
  event_code text,
  followup_date date,
  channel text,
  contact_person text,
  contact_designation text,
  outcome text,
  notes text,
  hours_invested numeric,
  next_step text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT f.id, f.event_code, f.followup_date, f.channel, f.contact_person, f.contact_designation,
         f.outcome, f.notes, f.hours_invested, f.next_step
  FROM gov_engagement_followups_r2877 f
  ORDER BY f.followup_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_followups_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_followups_r2877() TO authenticated;

-- ============================================================================
-- RPC 5: Priority p0 events needing action
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_p0_events_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_p0_events_r2877()
RETURNS TABLE (
  event_code text,
  event_name text,
  department text,
  business_impact_inr_cr numeric,
  follow_up_status text,
  next_action_date date,
  days_until_next_action int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.event_code, e.event_name, e.department, e.business_impact_inr_cr, e.follow_up_status, e.next_action_date,
    (e.next_action_date - CURRENT_DATE)::int
  FROM gov_engagement_events_r2877 e
  WHERE e.priority = 'p0'
  ORDER BY e.next_action_date ASC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_p0_events_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_p0_events_r2877() TO authenticated;

-- ============================================================================
-- RPC 6: Quarter summary
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_by_quarter_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_by_quarter_r2877()
RETURNS TABLE (
  quarter text,
  event_count int,
  total_impact_cr numeric,
  completed_count int,
  active_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.quarter,
    COUNT(*)::int,
    COALESCE(SUM(e.business_impact_inr_cr), 0),
    COUNT(*) FILTER (WHERE e.follow_up_status = 'completed')::int,
    COUNT(*) FILTER (WHERE e.follow_up_status IN ('pending','in_progress'))::int
  FROM gov_engagement_events_r2877 e
  GROUP BY e.quarter
  ORDER BY e.quarter ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_by_quarter_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_by_quarter_r2877() TO authenticated;

-- ============================================================================
-- RPC 7: Outcome funnel from follow-ups
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_outcome_funnel_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_outcome_funnel_r2877()
RETURNS TABLE (
  outcome text,
  followup_count int,
  total_hours numeric,
  distinct_events int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    f.outcome,
    COUNT(*)::int,
    COALESCE(SUM(f.hours_invested), 0),
    COUNT(DISTINCT f.event_code)::int
  FROM gov_engagement_followups_r2877 f
  GROUP BY f.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_outcome_funnel_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_outcome_funnel_r2877() TO authenticated;

-- ============================================================================
-- RPC 8: Ministry level engagement spread
-- ============================================================================
DROP FUNCTION IF EXISTS get_gov_engagement_by_ministry_level_r2877();

CREATE OR REPLACE FUNCTION get_gov_engagement_by_ministry_level_r2877()
RETURNS TABLE (
  ministry_level text,
  event_count int,
  total_impact_cr numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.ministry_level,
    COUNT(*)::int,
    COALESCE(SUM(e.business_impact_inr_cr), 0)
  FROM gov_engagement_events_r2877 e
  GROUP BY e.ministry_level
  ORDER BY COALESCE(SUM(e.business_impact_inr_cr), 0) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_gov_engagement_by_ministry_level_r2877() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_gov_engagement_by_ministry_level_r2877() TO authenticated;

COMMIT;
