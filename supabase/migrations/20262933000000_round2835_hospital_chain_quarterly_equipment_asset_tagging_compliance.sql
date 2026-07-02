BEGIN;

-- ============================================================================
-- Round 2835 — Hospital Chain Quarterly Equipment Asset Tagging Compliance
-- Tracks chain × asset × tag kind × compliance × audit × gap × close action
-- ============================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_asset_tag_compliance_r2835 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  region text NOT NULL,
  hospital_count int NOT NULL,
  asset_total int NOT NULL,
  asset_tagged int NOT NULL,
  tag_kind text NOT NULL CHECK (tag_kind IN ('qr','rfid','barcode','nfc','engraved')),
  quarter text NOT NULL,
  audit_status text NOT NULL CHECK (audit_status IN ('not_started','in_progress','review','passed','failed')),
  compliance_score numeric(5,2) NOT NULL,
  gap_count int NOT NULL DEFAULT 0,
  high_severity_gaps int NOT NULL DEFAULT 0,
  last_audit_date date,
  next_audit_due date,
  auditor_name text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_asset_tag_compliance_r2835 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON hospital_chain_asset_tag_compliance_r2835
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_asset_tag_compliance_r2835
  (chain_code, chain_name, region, hospital_count, asset_total, asset_tagged, tag_kind, quarter, audit_status, compliance_score, gap_count, high_severity_gaps, last_audit_date, next_audit_due, auditor_name, notes)
VALUES
  ('APO','Apollo Hospitals','South',71,18420,17890,'rfid','Q2-2026','passed',97.12,12,1,'2026-05-12'::date,'2026-08-15'::date,'KPMG India','RFID rollout complete, minor labelling gaps in dialysis wing'),
  ('FOR','Fortis Healthcare','North',36,9870,8210,'qr','Q2-2026','review',83.18,47,6,'2026-05-28'::date,'2026-08-28'::date,'Deloitte','QR fade observed on 6 ICU monitors, reprint scheduled'),
  ('MAX','Max Healthcare','North',22,6540,5970,'nfc','Q2-2026','in_progress',91.28,21,2,'2026-06-01'::date,'2026-09-01'::date,'EY India','NFC tags failing on metal surfaces — engraving backup plan'),
  ('MAN','Manipal Hospitals','South',29,7820,7610,'rfid','Q2-2026','passed',97.31,9,0,'2026-04-19'::date,'2026-07-19'::date,'Grant Thornton','Best-in-class, zero high-severity gaps'),
  ('NAR','Narayana Health','South',24,5420,3980,'barcode','Q2-2026','failed',73.43,84,17,'2026-06-10'::date,'2026-07-10'::date,'PwC India','Barcode tech outdated, RFID migration mandated'),
  ('AIIM','AIIMS Network','Central',15,12380,10220,'engraved','Q2-2026','in_progress',82.55,38,4,'2026-05-22'::date,'2026-08-22'::date,'CAG India','Engraving slow, expanding to 3 vendor contracts'),
  ('KIM','KIMS Hospitals','South',18,4210,4090,'qr','Q2-2026','passed',97.15,7,0,'2026-04-30'::date,'2026-07-30'::date,'BDO India','QR + photo-log dual verification working well');

CREATE TABLE IF NOT EXISTS asset_tag_compliance_gap_actions_r2835 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compliance_id uuid NOT NULL REFERENCES hospital_chain_asset_tag_compliance_r2835(id) ON DELETE CASCADE,
  gap_category text NOT NULL CHECK (gap_category IN ('missing_tag','damaged_tag','wrong_kind','duplicate','orphan_asset','location_mismatch','expired_tag')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  affected_assets int NOT NULL,
  close_action text NOT NULL,
  owner_role text NOT NULL CHECK (owner_role IN ('biomedical_lead','facility_manager','it_admin','founder','chain_compliance_officer')),
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','blocked','closed','escalated')),
  cost_estimate_rupees int NOT NULL DEFAULT 0,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE asset_tag_compliance_gap_actions_r2835 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON asset_tag_compliance_gap_actions_r2835
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO asset_tag_compliance_gap_actions_r2835
  (compliance_id, gap_category, severity, affected_assets, close_action, owner_role, due_date, status, cost_estimate_rupees)
SELECT id, 'damaged_tag', 'high', 47, 'Reprint QR labels on industrial polyester for 6 ICU monitors', 'biomedical_lead', '2026-07-15'::date, 'in_progress', 84000 FROM hospital_chain_asset_tag_compliance_r2835 WHERE chain_code='FOR'
UNION ALL
SELECT id, 'wrong_kind', 'critical', 1440, 'Migrate from 1D barcode to RFID across 24 hospitals', 'chain_compliance_officer', '2026-09-30'::date, 'escalated', 1820000 FROM hospital_chain_asset_tag_compliance_r2835 WHERE chain_code='NAR'
UNION ALL
SELECT id, 'missing_tag', 'medium', 530, 'Apollo dialysis wing tagging sweep', 'facility_manager', '2026-07-01'::date, 'open', 72000 FROM hospital_chain_asset_tag_compliance_r2835 WHERE chain_code='APO'
UNION ALL
SELECT id, 'location_mismatch', 'medium', 210, 'Reconcile asset location vs floor plan in CMMS', 'it_admin', '2026-08-10'::date, 'open', 45000 FROM hospital_chain_asset_tag_compliance_r2835 WHERE chain_code='MAX'
UNION ALL
SELECT id, 'orphan_asset', 'high', 2160, 'AIIMS engraving expansion — 3rd vendor contract sign-off', 'founder', '2026-08-20'::date, 'in_progress', 540000 FROM hospital_chain_asset_tag_compliance_r2835 WHERE chain_code='AIIM'
UNION ALL
SELECT id, 'expired_tag', 'low', 120, 'Refresh QR + photo log batch for KIMS', 'biomedical_lead', '2026-07-25'::date, 'closed', 24000 FROM hospital_chain_asset_tag_compliance_r2835 WHERE chain_code='KIM'
UNION ALL
SELECT id, 'duplicate', 'medium', 9, 'Deduplicate RFID UID collisions in Manipal mother registry', 'it_admin', '2026-07-12'::date, 'closed', 12000 FROM hospital_chain_asset_tag_compliance_r2835 WHERE chain_code='MAN';

-- ============================================================================
-- RPC 1 — Chain compliance overview
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_chain_overview();
CREATE FUNCTION rpc_r2835_chain_overview()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  region text,
  hospital_count int,
  asset_total int,
  asset_tagged int,
  tag_coverage_pct numeric,
  tag_kind text,
  audit_status text,
  compliance_score numeric,
  gap_count int,
  high_severity_gaps int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_code, c.chain_name, c.region, c.hospital_count, c.asset_total, c.asset_tagged,
           ROUND((c.asset_tagged::numeric / NULLIF(c.asset_total,0)) * 100, 2),
           c.tag_kind, c.audit_status, c.compliance_score, c.gap_count, c.high_severity_gaps
    FROM hospital_chain_asset_tag_compliance_r2835 c
    ORDER BY c.compliance_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_chain_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_chain_overview() TO authenticated;

-- ============================================================================
-- RPC 2 — KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_kpi_summary();
CREATE FUNCTION rpc_r2835_kpi_summary()
RETURNS TABLE (
  total_chains int,
  total_hospitals int,
  total_assets int,
  total_tagged int,
  overall_coverage_pct numeric,
  avg_compliance numeric,
  passed_chains int,
  failed_chains int,
  open_gap_actions int,
  high_severity_gaps_total int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM hospital_chain_asset_tag_compliance_r2835),
      (SELECT COALESCE(SUM(hospital_count),0)::int FROM hospital_chain_asset_tag_compliance_r2835),
      (SELECT COALESCE(SUM(asset_total),0)::int FROM hospital_chain_asset_tag_compliance_r2835),
      (SELECT COALESCE(SUM(asset_tagged),0)::int FROM hospital_chain_asset_tag_compliance_r2835),
      (SELECT ROUND((SUM(asset_tagged)::numeric / NULLIF(SUM(asset_total),0)) * 100, 2) FROM hospital_chain_asset_tag_compliance_r2835),
      (SELECT ROUND(AVG(compliance_score),2) FROM hospital_chain_asset_tag_compliance_r2835),
      (SELECT COUNT(*)::int FROM hospital_chain_asset_tag_compliance_r2835 WHERE audit_status='passed'),
      (SELECT COUNT(*)::int FROM hospital_chain_asset_tag_compliance_r2835 WHERE audit_status='failed'),
      (SELECT COUNT(*)::int FROM asset_tag_compliance_gap_actions_r2835 WHERE status IN ('open','in_progress','escalated','blocked')),
      (SELECT COALESCE(SUM(high_severity_gaps),0)::int FROM hospital_chain_asset_tag_compliance_r2835);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_kpi_summary() TO authenticated;

-- ============================================================================
-- RPC 3 — Tag kind breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_tag_kind_breakdown();
CREATE FUNCTION rpc_r2835_tag_kind_breakdown()
RETURNS TABLE (
  tag_kind text,
  chain_count int,
  asset_total int,
  asset_tagged int,
  coverage_pct numeric,
  avg_compliance numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.tag_kind,
           COUNT(*)::int,
           COALESCE(SUM(c.asset_total),0)::int,
           COALESCE(SUM(c.asset_tagged),0)::int,
           ROUND((SUM(c.asset_tagged)::numeric / NULLIF(SUM(c.asset_total),0)) * 100, 2),
           ROUND(AVG(c.compliance_score),2)
    FROM hospital_chain_asset_tag_compliance_r2835 c
    GROUP BY c.tag_kind
    ORDER BY ROUND(AVG(c.compliance_score),2) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_tag_kind_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_tag_kind_breakdown() TO authenticated;

-- ============================================================================
-- RPC 4 — Audit status pipeline
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_audit_pipeline();
CREATE FUNCTION rpc_r2835_audit_pipeline()
RETURNS TABLE (
  audit_status text,
  chain_count int,
  hospital_count int,
  asset_total int,
  avg_compliance numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.audit_status,
           COUNT(*)::int,
           COALESCE(SUM(c.hospital_count),0)::int,
           COALESCE(SUM(c.asset_total),0)::int,
           ROUND(AVG(c.compliance_score),2)
    FROM hospital_chain_asset_tag_compliance_r2835 c
    GROUP BY c.audit_status
    ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_audit_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_audit_pipeline() TO authenticated;

-- ============================================================================
-- RPC 5 — Open gap actions
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_open_gap_actions();
CREATE FUNCTION rpc_r2835_open_gap_actions()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  gap_category text,
  severity text,
  affected_assets int,
  close_action text,
  owner_role text,
  due_date date,
  status text,
  cost_estimate_rupees int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_code, c.chain_name, g.gap_category, g.severity, g.affected_assets,
           g.close_action, g.owner_role, g.due_date, g.status, g.cost_estimate_rupees
    FROM asset_tag_compliance_gap_actions_r2835 g
    JOIN hospital_chain_asset_tag_compliance_r2835 c ON c.id = g.compliance_id
    WHERE g.status IN ('open','in_progress','escalated','blocked')
    ORDER BY
      CASE g.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
      g.due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_open_gap_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_open_gap_actions() TO authenticated;

-- ============================================================================
-- RPC 6 — Region rollup
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_region_rollup();
CREATE FUNCTION rpc_r2835_region_rollup()
RETURNS TABLE (
  region text,
  chain_count int,
  hospital_count int,
  asset_total int,
  asset_tagged int,
  coverage_pct numeric,
  avg_compliance numeric,
  total_gaps int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.region,
           COUNT(*)::int,
           COALESCE(SUM(c.hospital_count),0)::int,
           COALESCE(SUM(c.asset_total),0)::int,
           COALESCE(SUM(c.asset_tagged),0)::int,
           ROUND((SUM(c.asset_tagged)::numeric / NULLIF(SUM(c.asset_total),0)) * 100, 2),
           ROUND(AVG(c.compliance_score),2),
           COALESCE(SUM(c.gap_count),0)::int
    FROM hospital_chain_asset_tag_compliance_r2835 c
    GROUP BY c.region
    ORDER BY ROUND(AVG(c.compliance_score),2) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_region_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_region_rollup() TO authenticated;

-- ============================================================================
-- RPC 7 — Owner workload
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_owner_workload();
CREATE FUNCTION rpc_r2835_owner_workload()
RETURNS TABLE (
  owner_role text,
  open_count int,
  total_count int,
  total_assets_affected int,
  total_cost_rupees bigint,
  critical_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.owner_role,
           COUNT(*) FILTER (WHERE g.status IN ('open','in_progress','escalated','blocked'))::int,
           COUNT(*)::int,
           COALESCE(SUM(g.affected_assets),0)::int,
           COALESCE(SUM(g.cost_estimate_rupees),0)::bigint,
           COUNT(*) FILTER (WHERE g.severity='critical')::int
    FROM asset_tag_compliance_gap_actions_r2835 g
    GROUP BY g.owner_role
    ORDER BY COUNT(*) FILTER (WHERE g.status IN ('open','in_progress','escalated','blocked')) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_owner_workload() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_owner_workload() TO authenticated;

-- ============================================================================
-- RPC 8 — Upcoming audits
-- ============================================================================
DROP FUNCTION IF EXISTS rpc_r2835_upcoming_audits();
CREATE FUNCTION rpc_r2835_upcoming_audits()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  region text,
  next_audit_due date,
  days_until int,
  current_status text,
  auditor_name text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_code, c.chain_name, c.region, c.next_audit_due,
           (c.next_audit_due - CURRENT_DATE)::int,
           c.audit_status, c.auditor_name
    FROM hospital_chain_asset_tag_compliance_r2835 c
    WHERE c.next_audit_due IS NOT NULL
    ORDER BY c.next_audit_due ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2835_upcoming_audits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2835_upcoming_audits() TO authenticated;

COMMIT;
