-- Round 3123: NABL/ISO Lab Accreditation Surveillance Readiness Tracker
-- Two round-suffixed tables: clause readiness + non-conformity / CAPA ledger
-- Founder-gated SECURITY DEFINER RPCs returning quarterly rollups.

BEGIN;

CREATE TABLE IF NOT EXISTS nabl_iso_clause_readiness_r3123 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id          uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  lab_name                 text NOT NULL,
  standard_code            text NOT NULL CHECK (standard_code IN ('ISO_15189','ISO_17025')),
  clause_reference         text NOT NULL,
  clause_title             text NOT NULL,
  clause_category          text NOT NULL CHECK (clause_category IN (
    'management','technical','document_control','competency','equipment',
    'measurement_traceability','quality_assurance','reporting','impartiality'
  )),
  readiness_status         text NOT NULL CHECK (readiness_status IN (
    'ready','minor_gap','major_gap','not_started','under_review'
  )),
  document_gap_count       int NOT NULL DEFAULT 0 CHECK (document_gap_count >= 0),
  competency_gap_count     int NOT NULL DEFAULT 0 CHECK (competency_gap_count >= 0),
  surveillance_due_on      date NOT NULL,
  last_internal_audit_on   date,
  responsible_engineer_id  uuid REFERENCES engineers(id) ON DELETE SET NULL,
  responsible_profile_id   uuid REFERENCES profiles(id) ON DELETE SET NULL,
  evidence_url             text,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clause_r3123_org   ON nabl_iso_clause_readiness_r3123(organization_id);
CREATE INDEX IF NOT EXISTS idx_clause_r3123_due   ON nabl_iso_clause_readiness_r3123(surveillance_due_on);
CREATE INDEX IF NOT EXISTS idx_clause_r3123_stat  ON nabl_iso_clause_readiness_r3123(readiness_status);

ALTER TABLE nabl_iso_clause_readiness_r3123 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS nabl_iso_nonconformity_capa_r3123 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clause_id                uuid NOT NULL REFERENCES nabl_iso_clause_readiness_r3123(id) ON DELETE CASCADE,
  nc_reference             text NOT NULL,
  nc_severity              text NOT NULL CHECK (nc_severity IN ('critical','major','minor','observation')),
  nc_summary               text NOT NULL,
  root_cause               text,
  capa_status              text NOT NULL CHECK (capa_status IN (
    'open','in_progress','effectiveness_check','closed','overdue','rejected'
  )),
  raised_on                date NOT NULL,
  target_closure_on        date NOT NULL,
  actual_closure_on        date,
  ageing_days              int NOT NULL DEFAULT 0 CHECK (ageing_days >= 0),
  responsible_engineer_id  uuid REFERENCES engineers(id) ON DELETE SET NULL,
  effectiveness_score      numeric(4,2) CHECK (effectiveness_score IS NULL OR (effectiveness_score >= 0 AND effectiveness_score <= 5)),
  remediation_cost_rupees  int NOT NULL DEFAULT 0 CHECK (remediation_cost_rupees >= 0),
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nc_r3123_clause ON nabl_iso_nonconformity_capa_r3123(clause_id);
CREATE INDEX IF NOT EXISTS idx_nc_r3123_status ON nabl_iso_nonconformity_capa_r3123(capa_status);
CREATE INDEX IF NOT EXISTS idx_nc_r3123_target ON nabl_iso_nonconformity_capa_r3123(target_closure_on);

ALTER TABLE nabl_iso_nonconformity_capa_r3123 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEEDS
-- ============================================================

WITH first_org AS (SELECT id FROM organizations ORDER BY created_at LIMIT 1)
INSERT INTO nabl_iso_clause_readiness_r3123 (
  organization_id, lab_name, standard_code, clause_reference, clause_title,
  clause_category, readiness_status, document_gap_count, competency_gap_count,
  surveillance_due_on, last_internal_audit_on, evidence_url, notes
)
SELECT (SELECT id FROM first_org), q.lab_name, q.standard_code, q.clause_reference, q.clause_title,
       q.clause_category, q.readiness_status, q.document_gap_count, q.competency_gap_count,
       q.surveillance_due_on::date, q.last_internal_audit_on::date, q.evidence_url, q.notes
FROM (VALUES
  ('Apollo Hyd Path Lab','ISO_15189','4.1','Management responsibility & impartiality','management','ready',0,0,'2026-09-15','2026-05-20','s3://docs/apollo/4.1.pdf','Signed by lab director'),
  ('Apollo Hyd Path Lab','ISO_15189','4.3','Document control register','document_control','minor_gap',2,0,'2026-09-15','2026-05-22','s3://docs/apollo/4.3.pdf','Two SOPs pending revision'),
  ('Apollo Hyd Path Lab','ISO_15189','5.5','Examination procedures (haematology)','technical','major_gap',4,1,'2026-09-15','2026-04-10',NULL,'Method validation gaps in CBC analyser'),
  ('Apollo Hyd Path Lab','ISO_15189','5.3','Equipment calibration & traceability','equipment','minor_gap',1,0,'2026-09-15','2026-05-25','s3://docs/apollo/5.3.pdf','Pending NABL traceable cert for centrifuge'),
  ('KIMS Secunderabad Lab','ISO_15189','5.6','Quality assurance EQAS participation','quality_assurance','ready',0,0,'2026-10-02','2026-06-01','s3://docs/kims/5.6.pdf','CMC Vellore EQAS Q1 cleared'),
  ('KIMS Secunderabad Lab','ISO_15189','5.8','Reporting of examination results','reporting','minor_gap',1,0,'2026-10-02','2026-06-05','s3://docs/kims/5.8.pdf','LIMS auto-comment missing for critical values'),
  ('Yashoda Vijayawada Calib Lab','ISO_17025','6.2','Personnel competency records','competency','major_gap',3,2,'2026-08-20','2026-04-28',NULL,'Two technicians overdue for re-certification'),
  ('Yashoda Vijayawada Calib Lab','ISO_17025','6.4','Equipment - dimensional gauges','equipment','minor_gap',1,0,'2026-08-20','2026-05-15','s3://docs/yashoda/6.4.pdf','One micrometer needs ILAC-MRA cert'),
  ('Yashoda Vijayawada Calib Lab','ISO_17025','6.5','Metrological traceability','measurement_traceability','not_started',5,1,'2026-08-20',NULL,NULL,'No documented traceability chain yet'),
  ('Yashoda Vijayawada Calib Lab','ISO_17025','7.8','Reporting of results & uncertainty','reporting','under_review',2,0,'2026-08-20','2026-05-30','s3://docs/yashoda/7.8.pdf','Awaiting QM sign-off'),
  ('Manipal Bengaluru Lab','ISO_15189','4.5','Impartiality risk register','impartiality','ready',0,0,'2026-11-12','2026-06-10','s3://docs/manipal/4.5.pdf','Quarterly impartiality review done'),
  ('Manipal Bengaluru Lab','ISO_15189','5.4','Pre-examination procedures','technical','minor_gap',1,1,'2026-11-12','2026-06-12','s3://docs/manipal/5.4.pdf','Phlebotomy SOP needs Kannada translation'),
  ('St John''s Bengaluru Lab','ISO_15189','5.5','Microbiology examination procedures','technical','major_gap',3,2,'2026-07-30','2026-04-05',NULL,'BSL-2 cabinet validation pending')
) AS q(lab_name, standard_code, clause_reference, clause_title, clause_category,
       readiness_status, document_gap_count, competency_gap_count,
       surveillance_due_on, last_internal_audit_on, evidence_url, notes);

-- NC / CAPA seeds tied to clauses with gaps
INSERT INTO nabl_iso_nonconformity_capa_r3123 (
  clause_id, nc_reference, nc_severity, nc_summary, root_cause, capa_status,
  raised_on, target_closure_on, actual_closure_on, ageing_days,
  effectiveness_score, remediation_cost_rupees
)
SELECT c.id, q.nc_reference, q.nc_severity, q.nc_summary, q.root_cause, q.capa_status,
       q.raised_on::date, q.target_closure_on::date, q.actual_closure_on::date,
       q.ageing_days, q.effectiveness_score, q.remediation_cost_rupees
FROM (VALUES
  ('Apollo Hyd Path Lab','5.5','NC-2026-001','major','CBC analyser method validation incomplete','Vendor delayed validation kit','in_progress','2026-04-15','2026-07-15',NULL::text,67,NULL::numeric,85000),
  ('Apollo Hyd Path Lab','4.3','NC-2026-002','minor','SOP HEMA-014 last revised > 24 months ago','Doc review cycle slipped','closed','2026-05-01','2026-06-01','2026-05-28',27,4.50,12000),
  ('Apollo Hyd Path Lab','5.3','NC-2026-003','minor','Centrifuge traceability cert expired','Calibration vendor change','effectiveness_check','2026-05-10','2026-06-30',NULL::text,42,NULL::numeric,18000),
  ('Yashoda Vijayawada Calib Lab','6.2','NC-2026-004','critical','Two technicians without valid competency cert running calibrations','Re-cert program lapsed during festive leave','overdue','2026-03-20','2026-05-20',NULL::text,93,NULL::numeric,65000),
  ('Yashoda Vijayawada Calib Lab','6.5','NC-2026-005','major','No documented metrological traceability chain','Lab moved from in-house to NPL-linked refs without update','open','2026-05-15','2026-08-15',NULL::text,37,NULL::numeric,150000),
  ('Yashoda Vijayawada Calib Lab','7.8','NC-2026-006','minor','Uncertainty budget missing on 14 calibration reports','New format not rolled to all technicians','in_progress','2026-04-25','2026-06-25',NULL::text,57,NULL::numeric,22000),
  ('KIMS Secunderabad Lab','5.8','NC-2026-007','minor','LIMS critical-value auto-flag not configured','Vendor patch pending','in_progress','2026-05-20','2026-07-10',NULL::text,32,NULL::numeric,40000),
  ('St John''s Bengaluru Lab','5.5','NC-2026-008','critical','BSL-2 cabinet validation overdue 11 months','Facilities deferred during renovation','overdue','2026-02-10','2026-05-10',NULL::text,131,NULL::numeric,210000),
  ('Manipal Bengaluru Lab','5.4','NC-2026-009','observation','Phlebotomy SOP available only in English','Translation queue backlog','open','2026-06-01','2026-09-01',NULL::text,20,NULL::numeric,8000),
  ('Apollo Hyd Path Lab','5.5','NC-2026-010','observation','Linearity check frequency not in HEMA SOP','SOP author oversight','closed','2026-04-01','2026-05-15','2026-05-10',39,3.80,5000),
  ('Yashoda Vijayawada Calib Lab','6.4','NC-2026-011','minor','One ILAC-MRA cert missing for digital micrometer','Vendor delay','rejected','2026-05-05','2026-06-20',NULL::text,46,NULL::numeric,15000),
  ('St John''s Bengaluru Lab','5.5','NC-2026-012','major','Microbiology incubator temperature log gaps','Manual log abandoned, no digital substitute','open','2026-04-18','2026-07-18',NULL::text,64,NULL::numeric,55000)
) AS q(lab_match, clause_ref_match, nc_reference, nc_severity, nc_summary, root_cause, capa_status,
       raised_on, target_closure_on, actual_closure_on, ageing_days, effectiveness_score, remediation_cost_rupees)
JOIN nabl_iso_clause_readiness_r3123 c
  ON c.lab_name = q.lab_match AND c.clause_reference = q.clause_ref_match;

-- ============================================================
-- RPCs (founder-gated, SECURITY DEFINER, plpgsql)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_r3123_clause_readiness_summary()
RETURNS TABLE (
  standard_code text,
  readiness_status text,
  clause_count bigint,
  total_doc_gaps bigint,
  total_competency_gaps bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.standard_code, c.readiness_status,
         COUNT(*)::bigint,
         COALESCE(SUM(c.document_gap_count),0)::bigint,
         COALESCE(SUM(c.competency_gap_count),0)::bigint
  FROM nabl_iso_clause_readiness_r3123 c
  GROUP BY c.standard_code, c.readiness_status
  ORDER BY c.standard_code, c.readiness_status;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_clause_readiness_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_clause_readiness_summary() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3123_surveillance_countdown()
RETURNS TABLE (
  lab_name text,
  standard_code text,
  earliest_due_on date,
  days_remaining int,
  open_clauses bigint,
  gap_clauses bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.lab_name, c.standard_code,
         MIN(c.surveillance_due_on)::date,
         (MIN(c.surveillance_due_on) - CURRENT_DATE)::int,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.readiness_status IN ('minor_gap','major_gap','not_started'))::bigint
  FROM nabl_iso_clause_readiness_r3123 c
  GROUP BY c.lab_name, c.standard_code
  ORDER BY MIN(c.surveillance_due_on);
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_surveillance_countdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_surveillance_countdown() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3123_category_gap_heatmap()
RETURNS TABLE (
  clause_category text,
  total_clauses bigint,
  gap_clauses bigint,
  gap_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.clause_category,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.readiness_status IN ('minor_gap','major_gap','not_started'))::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE c.readiness_status IN ('minor_gap','major_gap','not_started')) / NULLIF(COUNT(*),0), 1)
  FROM nabl_iso_clause_readiness_r3123 c
  GROUP BY c.clause_category
  ORDER BY gap_clauses DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_category_gap_heatmap() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_category_gap_heatmap() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3123_capa_status_rollup()
RETURNS TABLE (
  capa_status text,
  nc_count bigint,
  avg_ageing_days numeric,
  total_remediation_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.capa_status,
         COUNT(*)::bigint,
         ROUND(AVG(n.ageing_days)::numeric, 1),
         COALESCE(SUM(n.remediation_cost_rupees),0)::bigint
  FROM nabl_iso_nonconformity_capa_r3123 n
  GROUP BY n.capa_status
  ORDER BY COUNT(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_capa_status_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_capa_status_rollup() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3123_severity_ageing_bands()
RETURNS TABLE (
  nc_severity text,
  band text,
  nc_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.nc_severity,
         CASE
           WHEN n.ageing_days <= 30  THEN '0_30'
           WHEN n.ageing_days <= 60  THEN '31_60'
           WHEN n.ageing_days <= 90  THEN '61_90'
           ELSE 'gt_90'
         END,
         COUNT(*)::bigint
  FROM nabl_iso_nonconformity_capa_r3123 n
  GROUP BY n.nc_severity,
           CASE
             WHEN n.ageing_days <= 30  THEN '0_30'
             WHEN n.ageing_days <= 60  THEN '31_60'
             WHEN n.ageing_days <= 90  THEN '61_90'
             ELSE 'gt_90'
           END
  ORDER BY n.nc_severity;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_severity_ageing_bands() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_severity_ageing_bands() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3123_overdue_capa_watchlist()
RETURNS TABLE (
  nc_reference text,
  nc_severity text,
  lab_name text,
  clause_reference text,
  target_closure_on date,
  days_overdue int,
  capa_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.nc_reference, n.nc_severity, c.lab_name, c.clause_reference,
         n.target_closure_on,
         (CURRENT_DATE - n.target_closure_on)::int,
         n.capa_status
  FROM nabl_iso_nonconformity_capa_r3123 n
  JOIN nabl_iso_clause_readiness_r3123 c ON c.id = n.clause_id
  WHERE n.capa_status NOT IN ('closed')
    AND n.target_closure_on < CURRENT_DATE
  ORDER BY (CURRENT_DATE - n.target_closure_on) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_overdue_capa_watchlist() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_overdue_capa_watchlist() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3123_lab_readiness_scorecard()
RETURNS TABLE (
  lab_name text,
  standard_code text,
  total_clauses bigint,
  ready_clauses bigint,
  readiness_pct numeric,
  open_ncs bigint,
  total_remediation_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.lab_name, c.standard_code,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.readiness_status = 'ready')::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE c.readiness_status = 'ready') / NULLIF(COUNT(*),0), 1),
         COALESCE(SUM(CASE WHEN n.capa_status NOT IN ('closed') THEN 1 ELSE 0 END),0)::bigint,
         COALESCE(SUM(n.remediation_cost_rupees),0)::bigint
  FROM nabl_iso_clause_readiness_r3123 c
  LEFT JOIN nabl_iso_nonconformity_capa_r3123 n ON n.clause_id = c.id
  GROUP BY c.lab_name, c.standard_code
  ORDER BY readiness_pct ASC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_lab_readiness_scorecard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_lab_readiness_scorecard() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3123_effectiveness_review()
RETURNS TABLE (
  nc_reference text,
  lab_name text,
  capa_status text,
  effectiveness_score numeric,
  actual_closure_on date,
  remediation_cost_rupees int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.nc_reference, c.lab_name, n.capa_status, n.effectiveness_score,
         n.actual_closure_on, n.remediation_cost_rupees
  FROM nabl_iso_nonconformity_capa_r3123 n
  JOIN nabl_iso_clause_readiness_r3123 c ON c.id = n.clause_id
  WHERE n.capa_status IN ('closed','effectiveness_check')
  ORDER BY n.actual_closure_on DESC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r3123_effectiveness_review() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3123_effectiveness_review() TO authenticated;

COMMIT;
