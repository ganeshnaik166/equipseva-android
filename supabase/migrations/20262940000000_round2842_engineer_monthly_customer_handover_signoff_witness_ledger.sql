BEGIN;

-- =====================================================================
-- Round r2842 — Engineer Monthly Customer Handover Signoff Witness Ledger
-- =====================================================================

-- ---------- TABLE 1: handover events ----------
CREATE TABLE IF NOT EXISTS engineer_handover_events_r2842 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  hospital_name text NOT NULL,
  equipment_label text NOT NULL,
  handover_date date NOT NULL,
  handover_type text NOT NULL CHECK (handover_type IN ('install','amc_renewal','repair_return','swap_replacement','training_complete')),
  signoff_status text NOT NULL CHECK (signoff_status IN ('signed_clean','signed_with_notes','partial','refused','disputed')),
  witness_count integer NOT NULL DEFAULT 0,
  witness_quality_score numeric(4,2) NOT NULL DEFAULT 0,
  customer_satisfaction integer NOT NULL CHECK (customer_satisfaction BETWEEN 0 AND 10),
  signoff_method text NOT NULL CHECK (signoff_method IN ('paper','digital_app','photo_capture','video_capture','biometric')),
  dispute_risk_score numeric(4,2) NOT NULL DEFAULT 0,
  outcome_label text NOT NULL CHECK (outcome_label IN ('clean','minor_followup','rework_needed','dispute_open','escalated')),
  followup_required boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_events_r2842 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_events_r2842;
CREATE POLICY founder_all ON engineer_handover_events_r2842 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handover_events_r2842 (engineer_code, engineer_name, hospital_name, equipment_label, handover_date, handover_type, signoff_status, witness_count, witness_quality_score, customer_satisfaction, signoff_method, dispute_risk_score, outcome_label, followup_required, notes) VALUES
  ('ENG-A12','Ravi Kumar','Apollo Jubilee','Philips MRI 1.5T','2026-06-02'::date,'install','signed_clean',3,9.20,9,'digital_app',0.80,'clean',false,'Smooth handover, biomed lead present'),
  ('ENG-A12','Ravi Kumar','KIMS Secunderabad','GE CT 64-slice','2026-06-05'::date,'amc_renewal','signed_with_notes',2,7.40,8,'digital_app',2.10,'minor_followup',true,'Customer flagged minor calibration request'),
  ('ENG-B07','Suresh Naidu','Yashoda Somajiguda','Siemens Cath Lab','2026-06-08'::date,'repair_return','partial',1,4.10,6,'paper',5.60,'rework_needed',true,'Single witness only, follow-up required for compliance'),
  ('ENG-B07','Suresh Naidu','Care Banjara','Mindray Ventilator','2026-06-11'::date,'install','signed_clean',2,8.80,9,'photo_capture',1.20,'clean',false,'Photo capture clean'),
  ('ENG-C03','Priya Reddy','Continental Hospitals','Roche Lab Analyzer','2026-06-14'::date,'training_complete','signed_clean',4,9.60,10,'video_capture',0.40,'clean',false,'Full training cohort signed off'),
  ('ENG-C03','Priya Reddy','Sunshine Paradise','Mortara ECG','2026-06-16'::date,'swap_replacement','disputed',0,0.00,4,'paper',8.90,'dispute_open',true,'No witness, customer disputes serial swap'),
  ('ENG-D11','Arjun Sharma','AIG Hospitals','Olympus Endoscope','2026-06-18'::date,'repair_return','signed_with_notes',2,7.10,7,'digital_app',3.40,'minor_followup',true,'Minor part-fitment query'),
  ('ENG-D11','Arjun Sharma','Rainbow Vikrampuri','Drager Anesthesia','2026-06-19'::date,'install','refused',1,2.00,3,'paper',9.40,'escalated',true,'Customer refused signoff pending PO clarity');

-- ---------- TABLE 2: witness ledger ----------
CREATE TABLE IF NOT EXISTS engineer_handover_witnesses_r2842 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handover_id uuid NOT NULL REFERENCES engineer_handover_events_r2842(id) ON DELETE CASCADE,
  witness_name text NOT NULL,
  witness_role text NOT NULL CHECK (witness_role IN ('biomed_head','dept_head','procurement','nurse_incharge','admin_signatory','third_party_auditor')),
  witness_credential_verified boolean NOT NULL DEFAULT false,
  signature_quality text NOT NULL CHECK (signature_quality IN ('clean','partial','illegible','missing')),
  contactable boolean NOT NULL DEFAULT true,
  evidence_url text,
  evidence_kind text NOT NULL CHECK (evidence_kind IN ('digital_sign','wet_sign_photo','video_clip','biometric_hash','none')),
  risk_flag text NOT NULL CHECK (risk_flag IN ('none','low','medium','high','critical')),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_witnesses_r2842 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_witnesses_r2842;
CREATE POLICY founder_all ON engineer_handover_witnesses_r2842 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag) 
SELECT id, 'Dr. Anand Kulkarni','biomed_head',true,'clean',true,'s3://handover/a12-apollo-1.pdf','digital_sign','none' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-A12' AND hospital_name='Apollo Jubilee' LIMIT 1;

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag)
SELECT id, 'Smt. Lakshmi N','procurement',true,'clean',true,'s3://handover/a12-kims-1.pdf','digital_sign','low' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-A12' AND hospital_name='KIMS Secunderabad' LIMIT 1;

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag)
SELECT id, 'Rohit Verma','dept_head',false,'partial',true,'s3://handover/b07-yashoda-1.jpg','wet_sign_photo','medium' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-B07' AND hospital_name='Yashoda Somajiguda' LIMIT 1;

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag)
SELECT id, 'Nurse Kavitha M','nurse_incharge',true,'clean',true,'s3://handover/b07-care-1.jpg','wet_sign_photo','none' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-B07' AND hospital_name='Care Banjara' LIMIT 1;

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag)
SELECT id, 'Dr. Meera Iyer','third_party_auditor',true,'clean',true,'s3://handover/c03-cont-1.mp4','video_clip','none' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-C03' AND hospital_name='Continental Hospitals' LIMIT 1;

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag)
SELECT id, 'Unknown','admin_signatory',false,'missing',false,NULL,'none','critical' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-C03' AND hospital_name='Sunshine Paradise' LIMIT 1;

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag)
SELECT id, 'Mr. Karthik B','biomed_head',true,'clean',true,'s3://handover/d11-aig-1.pdf','digital_sign','low' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-D11' AND hospital_name='AIG Hospitals' LIMIT 1;

INSERT INTO engineer_handover_witnesses_r2842 (handover_id, witness_name, witness_role, witness_credential_verified, signature_quality, contactable, evidence_url, evidence_kind, risk_flag)
SELECT id, 'Admin Counter','admin_signatory',false,'illegible',false,'s3://handover/d11-rainbow-1.jpg','wet_sign_photo','high' FROM engineer_handover_events_r2842 WHERE engineer_code='ENG-D11' AND hospital_name='Rainbow Vikrampuri' LIMIT 1;

-- =====================================================================
-- RPCs
-- =====================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_r2842_handover_kpis();
CREATE OR REPLACE FUNCTION founder_r2842_handover_kpis()
RETURNS TABLE (
  total_handovers integer,
  clean_signoffs integer,
  disputed_count integer,
  avg_witness_quality numeric,
  avg_dispute_risk numeric,
  avg_csat numeric,
  followups_open integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE signoff_status='signed_clean')::int,
         COUNT(*) FILTER (WHERE outcome_label IN ('dispute_open','escalated'))::int,
         ROUND(AVG(witness_quality_score),2),
         ROUND(AVG(dispute_risk_score),2),
         ROUND(AVG(customer_satisfaction),2),
         COUNT(*) FILTER (WHERE followup_required)::int
  FROM engineer_handover_events_r2842;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_handover_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_handover_kpis() TO authenticated;

-- RPC 2: engineer rollup
DROP FUNCTION IF EXISTS founder_r2842_engineer_rollup();
CREATE OR REPLACE FUNCTION founder_r2842_engineer_rollup()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  handovers integer,
  clean integer,
  disputed integer,
  avg_csat numeric,
  avg_risk numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.engineer_code,
         MAX(h.engineer_name),
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE h.signoff_status='signed_clean')::int,
         COUNT(*) FILTER (WHERE h.outcome_label IN ('dispute_open','escalated'))::int,
         ROUND(AVG(h.customer_satisfaction),2),
         ROUND(AVG(h.dispute_risk_score),2)
  FROM engineer_handover_events_r2842 h
  GROUP BY h.engineer_code
  ORDER BY AVG(h.dispute_risk_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_engineer_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_engineer_rollup() TO authenticated;

-- RPC 3: handover list
DROP FUNCTION IF EXISTS founder_r2842_handover_list();
CREATE OR REPLACE FUNCTION founder_r2842_handover_list()
RETURNS TABLE (
  id uuid,
  engineer_code text,
  engineer_name text,
  hospital_name text,
  equipment_label text,
  handover_date date,
  handover_type text,
  signoff_status text,
  outcome_label text,
  csat integer,
  risk numeric,
  witnesses integer,
  method text,
  followup boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.engineer_code, h.engineer_name, h.hospital_name, h.equipment_label,
         h.handover_date, h.handover_type, h.signoff_status, h.outcome_label,
         h.customer_satisfaction, h.dispute_risk_score, h.witness_count,
         h.signoff_method, h.followup_required
  FROM engineer_handover_events_r2842 h
  ORDER BY h.handover_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_handover_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_handover_list() TO authenticated;

-- RPC 4: witness ledger
DROP FUNCTION IF EXISTS founder_r2842_witness_ledger();
CREATE OR REPLACE FUNCTION founder_r2842_witness_ledger()
RETURNS TABLE (
  witness_name text,
  witness_role text,
  hospital_name text,
  engineer_code text,
  credential_verified boolean,
  signature_quality text,
  evidence_kind text,
  risk_flag text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.witness_name, w.witness_role, h.hospital_name, h.engineer_code,
         w.witness_credential_verified, w.signature_quality, w.evidence_kind, w.risk_flag
  FROM engineer_handover_witnesses_r2842 w
  JOIN engineer_handover_events_r2842 h ON h.id = w.handover_id
  ORDER BY CASE w.risk_flag WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_witness_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_witness_ledger() TO authenticated;

-- RPC 5: dispute risk by outcome
DROP FUNCTION IF EXISTS founder_r2842_outcome_mix();
CREATE OR REPLACE FUNCTION founder_r2842_outcome_mix()
RETURNS TABLE (
  outcome_label text,
  events integer,
  avg_risk numeric,
  avg_csat numeric,
  followups integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.outcome_label,
         COUNT(*)::int,
         ROUND(AVG(h.dispute_risk_score),2),
         ROUND(AVG(h.customer_satisfaction),2),
         COUNT(*) FILTER (WHERE h.followup_required)::int
  FROM engineer_handover_events_r2842 h
  GROUP BY h.outcome_label
  ORDER BY AVG(h.dispute_risk_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_outcome_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_outcome_mix() TO authenticated;

-- RPC 6: method effectiveness
DROP FUNCTION IF EXISTS founder_r2842_method_effectiveness();
CREATE OR REPLACE FUNCTION founder_r2842_method_effectiveness()
RETURNS TABLE (
  signoff_method text,
  events integer,
  clean_rate numeric,
  avg_risk numeric,
  avg_witness_quality numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.signoff_method,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE h.signoff_status='signed_clean') / NULLIF(COUNT(*),0), 2),
         ROUND(AVG(h.dispute_risk_score),2),
         ROUND(AVG(h.witness_quality_score),2)
  FROM engineer_handover_events_r2842 h
  GROUP BY h.signoff_method
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_method_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_method_effectiveness() TO authenticated;

-- RPC 7: high-risk handovers needing review
DROP FUNCTION IF EXISTS founder_r2842_high_risk();
CREATE OR REPLACE FUNCTION founder_r2842_high_risk()
RETURNS TABLE (
  engineer_code text,
  hospital_name text,
  equipment_label text,
  handover_date date,
  signoff_status text,
  dispute_risk numeric,
  witness_count integer,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.engineer_code, h.hospital_name, h.equipment_label, h.handover_date,
         h.signoff_status, h.dispute_risk_score, h.witness_count, h.outcome_label
  FROM engineer_handover_events_r2842 h
  WHERE h.dispute_risk_score >= 3.0 OR h.outcome_label IN ('dispute_open','escalated','rework_needed')
  ORDER BY h.dispute_risk_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_high_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_high_risk() TO authenticated;

-- RPC 8: witness role coverage
DROP FUNCTION IF EXISTS founder_r2842_witness_role_coverage();
CREATE OR REPLACE FUNCTION founder_r2842_witness_role_coverage()
RETURNS TABLE (
  witness_role text,
  total integer,
  verified integer,
  clean_signatures integer,
  high_risk integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.witness_role,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE w.witness_credential_verified)::int,
         COUNT(*) FILTER (WHERE w.signature_quality='clean')::int,
         COUNT(*) FILTER (WHERE w.risk_flag IN ('high','critical'))::int
  FROM engineer_handover_witnesses_r2842 w
  GROUP BY w.witness_role
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2842_witness_role_coverage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2842_witness_role_coverage() TO authenticated;

COMMIT;
