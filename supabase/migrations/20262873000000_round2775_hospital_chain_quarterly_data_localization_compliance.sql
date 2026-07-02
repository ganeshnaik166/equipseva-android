BEGIN;

CREATE TABLE IF NOT EXISTS hospital_chain_dataloc_audits_r2775 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  policy_framework text NOT NULL CHECK (policy_framework IN ('dpdp_act_2023','rbi_data_loc','meity_advisory','cert_in_directive','hipaa_align')),
  quarter_label text NOT NULL,
  audit_date date NOT NULL,
  data_residency_status text NOT NULL CHECK (data_residency_status IN ('in_country','mirrored','partial_offshore','offshore_unauthorized','unknown')),
  encryption_at_rest_ok boolean NOT NULL DEFAULT false,
  encryption_in_transit_ok boolean NOT NULL DEFAULT false,
  consent_ledger_present boolean NOT NULL DEFAULT false,
  cross_border_log_ok boolean NOT NULL DEFAULT false,
  gap_count int NOT NULL DEFAULT 0,
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  close_action text NOT NULL,
  verification_method text NOT NULL CHECK (verification_method IN ('on_site_review','document_review','penetration_test','log_sampling','vendor_attestation')),
  outcome text NOT NULL CHECK (outcome IN ('passed','passed_with_conditions','remediation_required','escalated','blocked')),
  next_review_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_dataloc_audits_r2775 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_dataloc_audits_r2775;
CREATE POLICY founder_all ON hospital_chain_dataloc_audits_r2775 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_dataloc_remediations_r2775 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES hospital_chain_dataloc_audits_r2775(id) ON DELETE CASCADE,
  gap_title text NOT NULL,
  gap_category text NOT NULL CHECK (gap_category IN ('residency','encryption','consent','logging','vendor','access_control')),
  owner_role text NOT NULL,
  remediation_step text NOT NULL,
  target_close_date date NOT NULL,
  actual_close_date date,
  verification_evidence_url text,
  status text NOT NULL CHECK (status IN ('open','in_progress','blocked','closed','waived')),
  risk_score int NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_dataloc_remediations_r2775 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_dataloc_remediations_r2775;
CREATE POLICY founder_all ON hospital_chain_dataloc_remediations_r2775 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_dataloc_audits_r2775 (chain_name, policy_framework, quarter_label, audit_date, data_residency_status, encryption_at_rest_ok, encryption_in_transit_ok, consent_ledger_present, cross_border_log_ok, gap_count, severity, close_action, verification_method, outcome, next_review_date) VALUES
  ('Apollo Hospitals South', 'dpdp_act_2023', 'Q1-FY26', '2026-04-22'::date, 'in_country', true, true, true, true, 1, 'low', 'Quarterly attestation filed; minor logging tweak', 'on_site_review', 'passed', '2026-07-22'::date),
  ('Yashoda Multi-Specialty', 'cert_in_directive', 'Q1-FY26', '2026-05-03'::date, 'mirrored', true, true, true, false, 3, 'medium', 'Enable cross-border egress audit log', 'log_sampling', 'passed_with_conditions', '2026-08-03'::date),
  ('KIMS Network', 'meity_advisory', 'Q4-FY25', '2026-03-18'::date, 'partial_offshore', true, false, true, false, 5, 'high', 'Migrate offshore radiology PACS to Mumbai region', 'document_review', 'remediation_required', '2026-06-18'::date),
  ('Care Hospitals Group', 'rbi_data_loc', 'Q1-FY26', '2026-05-12'::date, 'in_country', true, true, false, true, 2, 'medium', 'Deploy consent ledger v2 across 12 sites', 'vendor_attestation', 'remediation_required', '2026-08-12'::date),
  ('Continental Hospitals', 'hipaa_align', 'Q1-FY26', '2026-05-21'::date, 'offshore_unauthorized', false, true, false, false, 8, 'critical', 'Halt all PHI sync; switch to in-country tenant by 30d', 'penetration_test', 'escalated', '2026-06-21'::date),
  ('Sunshine Chain', 'dpdp_act_2023', 'Q1-FY26', '2026-05-28'::date, 'in_country', true, true, true, true, 0, 'low', 'No action — clean audit', 'on_site_review', 'passed', '2026-08-28'::date);

INSERT INTO hospital_chain_dataloc_remediations_r2775 (audit_id, gap_title, gap_category, owner_role, remediation_step, target_close_date, status, risk_score) 
SELECT id, 'Cross-border egress log missing', 'logging', 'CISO', 'Enable VPC flow logs + SIEM export', '2026-07-15'::date, 'in_progress', 55 FROM hospital_chain_dataloc_audits_r2775 WHERE chain_name = 'Yashoda Multi-Specialty' LIMIT 1;

INSERT INTO hospital_chain_dataloc_remediations_r2775 (audit_id, gap_title, gap_category, owner_role, remediation_step, target_close_date, status, risk_score) 
SELECT id, 'PACS offshore in Singapore', 'residency', 'CTO', 'Migrate to Mumbai AZ; cutover 2026-06-30', '2026-06-30'::date, 'open', 85 FROM hospital_chain_dataloc_audits_r2775 WHERE chain_name = 'KIMS Network' LIMIT 1;

INSERT INTO hospital_chain_dataloc_remediations_r2775 (audit_id, gap_title, gap_category, owner_role, remediation_step, target_close_date, status, risk_score) 
SELECT id, 'Consent ledger v1 stale', 'consent', 'DPO', 'Deploy ledger v2 with hash chain', '2026-07-20'::date, 'in_progress', 60 FROM hospital_chain_dataloc_audits_r2775 WHERE chain_name = 'Care Hospitals Group' LIMIT 1;

INSERT INTO hospital_chain_dataloc_remediations_r2775 (audit_id, gap_title, gap_category, owner_role, remediation_step, target_close_date, status, risk_score) 
SELECT id, 'Unauthorized US tenant sync', 'residency', 'CEO', 'Cease sync; quarantine bucket; legal review', '2026-06-25'::date, 'blocked', 95 FROM hospital_chain_dataloc_audits_r2775 WHERE chain_name = 'Continental Hospitals' LIMIT 1;

INSERT INTO hospital_chain_dataloc_remediations_r2775 (audit_id, gap_title, gap_category, owner_role, remediation_step, target_close_date, actual_close_date, status, risk_score) 
SELECT id, 'Verbose logging tune', 'logging', 'SRE Lead', 'Reduce retention to 90d', '2026-06-10'::date, '2026-06-05'::date, 'closed', 20 FROM hospital_chain_dataloc_audits_r2775 WHERE chain_name = 'Apollo Hospitals South' LIMIT 1;

INSERT INTO hospital_chain_dataloc_remediations_r2775 (audit_id, gap_title, gap_category, owner_role, remediation_step, target_close_date, status, risk_score) 
SELECT id, 'Vendor SOC2 expired', 'vendor', 'Procurement', 'Renew or replace vendor', '2026-07-30'::date, 'open', 40 FROM hospital_chain_dataloc_audits_r2775 WHERE chain_name = 'Continental Hospitals' LIMIT 1;

DROP FUNCTION IF EXISTS founder_chain_dataloc_overview_r2775();
CREATE FUNCTION founder_chain_dataloc_overview_r2775()
RETURNS TABLE(total_audits bigint, critical_count bigint, high_count bigint, open_gaps bigint, avg_risk numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM hospital_chain_dataloc_audits_r2775),
    (SELECT count(*) FROM hospital_chain_dataloc_audits_r2775 WHERE severity = 'critical'),
    (SELECT count(*) FROM hospital_chain_dataloc_audits_r2775 WHERE severity = 'high'),
    (SELECT count(*) FROM hospital_chain_dataloc_remediations_r2775 WHERE status IN ('open','in_progress','blocked')),
    COALESCE((SELECT round(avg(risk_score)::numeric, 1) FROM hospital_chain_dataloc_remediations_r2775 WHERE status IN ('open','in_progress','blocked')), 0);
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_overview_r2775() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_overview_r2775() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_dataloc_recent_audits_r2775(int);
CREATE FUNCTION founder_chain_dataloc_recent_audits_r2775(p_limit int DEFAULT 20)
RETURNS TABLE(id uuid, chain_name text, policy_framework text, quarter_label text, audit_date date, severity text, outcome text, gap_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.policy_framework, a.quarter_label, a.audit_date, a.severity, a.outcome, a.gap_count
  FROM hospital_chain_dataloc_audits_r2775 a
  ORDER BY a.audit_date DESC
  LIMIT p_limit;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_recent_audits_r2775(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_recent_audits_r2775(int) TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_dataloc_open_gaps_r2775();
CREATE FUNCTION founder_chain_dataloc_open_gaps_r2775()
RETURNS TABLE(remediation_id uuid, chain_name text, gap_title text, gap_category text, owner_role text, target_close_date date, status text, risk_score int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, a.chain_name, r.gap_title, r.gap_category, r.owner_role, r.target_close_date, r.status, r.risk_score
  FROM hospital_chain_dataloc_remediations_r2775 r
  JOIN hospital_chain_dataloc_audits_r2775 a ON a.id = r.audit_id
  WHERE r.status IN ('open','in_progress','blocked')
  ORDER BY r.risk_score DESC, r.target_close_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_open_gaps_r2775() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_open_gaps_r2775() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_dataloc_by_framework_r2775();
CREATE FUNCTION founder_chain_dataloc_by_framework_r2775()
RETURNS TABLE(policy_framework text, audit_count bigint, avg_gaps numeric, passed_rate numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.policy_framework,
    count(*),
    round(avg(a.gap_count)::numeric, 2),
    round((100.0 * sum(CASE WHEN a.outcome IN ('passed','passed_with_conditions') THEN 1 ELSE 0 END) / NULLIF(count(*),0))::numeric, 1)
  FROM hospital_chain_dataloc_audits_r2775 a
  GROUP BY a.policy_framework
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_by_framework_r2775() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_by_framework_r2775() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_dataloc_residency_breakdown_r2775();
CREATE FUNCTION founder_chain_dataloc_residency_breakdown_r2775()
RETURNS TABLE(data_residency_status text, n bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.data_residency_status, count(*)
  FROM hospital_chain_dataloc_audits_r2775 a
  GROUP BY a.data_residency_status
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_residency_breakdown_r2775() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_residency_breakdown_r2775() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_dataloc_escalations_r2775();
CREATE FUNCTION founder_chain_dataloc_escalations_r2775()
RETURNS TABLE(chain_name text, severity text, outcome text, close_action text, next_review_date date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name, a.severity, a.outcome, a.close_action, a.next_review_date
  FROM hospital_chain_dataloc_audits_r2775 a
  WHERE a.outcome IN ('escalated','blocked') OR a.severity IN ('critical','high')
  ORDER BY CASE a.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END, a.audit_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_escalations_r2775() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_escalations_r2775() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_dataloc_close_action_r2775(uuid, date);
CREATE FUNCTION founder_chain_dataloc_close_action_r2775(p_remediation_id uuid, p_close_date date)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_chain_dataloc_remediations_r2775
    SET status = 'closed', actual_close_date = p_close_date
  WHERE id = p_remediation_id
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_close_action_r2775(uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_close_action_r2775(uuid, date) TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_dataloc_quarter_trend_r2775();
CREATE FUNCTION founder_chain_dataloc_quarter_trend_r2775()
RETURNS TABLE(quarter_label text, audits bigint, total_gaps bigint, critical_high bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.quarter_label, count(*), COALESCE(sum(a.gap_count)::bigint, 0::bigint),
    sum(CASE WHEN a.severity IN ('critical','high') THEN 1 ELSE 0 END)::bigint
  FROM hospital_chain_dataloc_audits_r2775 a
  GROUP BY a.quarter_label
  ORDER BY a.quarter_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_dataloc_quarter_trend_r2775() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_dataloc_quarter_trend_r2775() TO authenticated;

COMMIT;