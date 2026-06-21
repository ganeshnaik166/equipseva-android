BEGIN;

-- r1660: Hospital warranty claim queue against OEM
-- Hospital files warranty claim against OEM (different from r1468 OEM-side warranty)
-- Founder reviews + reimburses hospital pending OEM resolution

CREATE TABLE IF NOT EXISTS hospital_oem_warranty_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES organizations(id),
  repair_job_id uuid REFERENCES repair_jobs(id),
  oem_name text NOT NULL,
  equipment_model text NOT NULL,
  failure_summary text NOT NULL,
  claim_amount_rupees numeric(12,2) NOT NULL CHECK (claim_amount_rupees > 0),
  approved_amount_rupees numeric(12,2),
  reimbursed_amount_rupees numeric(12,2),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','under_review','approved','reimbursed','rejected','oem_disputed')),
  oem_response text,
  founder_note text,
  filed_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  reimbursed_at timestamptz
);

ALTER TABLE hospital_oem_warranty_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hospital_oem_warranty_claims_founder_only ON hospital_oem_warranty_claims;
CREATE POLICY hospital_oem_warranty_claims_founder_only ON hospital_oem_warranty_claims
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_hospital_oem_warranty_claims_status ON hospital_oem_warranty_claims(status);
CREATE INDEX IF NOT EXISTS idx_hospital_oem_warranty_claims_filed_at ON hospital_oem_warranty_claims(filed_at DESC);
CREATE INDEX IF NOT EXISTS idx_hospital_oem_warranty_claims_hospital ON hospital_oem_warranty_claims(hospital_org_id);

-- log helper
CREATE OR REPLACE FUNCTION log_founder_hospital_oem_warranty_action(
  p_op_name text,
  p_after jsonb
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op_name, p_after, now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_hospital_oem_warranty_action(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hospital_oem_warranty_action(text, jsonb) TO authenticated;

-- RPC 1: queue summary
CREATE OR REPLACE FUNCTION founder_hospital_oem_warranty_summary()
RETURNS TABLE(
  total_claims int,
  submitted_count int,
  under_review_count int,
  approved_count int,
  reimbursed_count int,
  rejected_count int,
  oem_disputed_count int,
  total_claim_value_rupees numeric,
  total_reimbursed_rupees numeric,
  pending_reimbursement_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE status='submitted'))::int,
    (COUNT(*) FILTER (WHERE status='under_review'))::int,
    (COUNT(*) FILTER (WHERE status='approved'))::int,
    (COUNT(*) FILTER (WHERE status='reimbursed'))::int,
    (COUNT(*) FILTER (WHERE status='rejected'))::int,
    (COUNT(*) FILTER (WHERE status='oem_disputed'))::int,
    COALESCE(SUM(claim_amount_rupees),0)::numeric,
    COALESCE(SUM(reimbursed_amount_rupees) FILTER (WHERE status='reimbursed'),0)::numeric,
    COALESCE(SUM(approved_amount_rupees) FILTER (WHERE status='approved'),0)::numeric
  FROM hospital_oem_warranty_claims;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_oem_warranty_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_oem_warranty_summary() TO authenticated;

-- RPC 2: pending review queue
CREATE OR REPLACE FUNCTION founder_hospital_oem_warranty_pending_review()
RETURNS TABLE(
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  oem_name text,
  equipment_model text,
  claim_amount_rupees numeric,
  status text,
  filed_at timestamptz,
  age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_org_id, o.name, c.oem_name, c.equipment_model,
         c.claim_amount_rupees, c.status, c.filed_at,
         EXTRACT(DAY FROM (now() - c.filed_at))::int
  FROM hospital_oem_warranty_claims c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  WHERE c.status IN ('submitted','under_review')
  ORDER BY c.filed_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_oem_warranty_pending_review() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_oem_warranty_pending_review() TO authenticated;

-- RPC 3: approved awaiting reimbursement
CREATE OR REPLACE FUNCTION founder_hospital_oem_warranty_awaiting_reimbursement()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  oem_name text,
  approved_amount_rupees numeric,
  approved_at timestamptz,
  age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, o.name, c.oem_name, c.approved_amount_rupees,
         c.resolved_at,
         EXTRACT(DAY FROM (now() - c.resolved_at))::int
  FROM hospital_oem_warranty_claims c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  WHERE c.status = 'approved'
  ORDER BY c.resolved_at ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_oem_warranty_awaiting_reimbursement() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_oem_warranty_awaiting_reimbursement() TO authenticated;

-- RPC 4: OEM disputed claims
CREATE OR REPLACE FUNCTION founder_hospital_oem_warranty_disputed()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  oem_name text,
  claim_amount_rupees numeric,
  oem_response text,
  filed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, o.name, c.oem_name, c.claim_amount_rupees, c.oem_response, c.filed_at
  FROM hospital_oem_warranty_claims c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  WHERE c.status = 'oem_disputed'
  ORDER BY c.filed_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_oem_warranty_disputed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_oem_warranty_disputed() TO authenticated;

-- RPC 5: OEM breakdown
CREATE OR REPLACE FUNCTION founder_hospital_oem_warranty_by_oem()
RETURNS TABLE(
  oem_name text,
  claim_count int,
  approved_count int,
  rejected_count int,
  disputed_count int,
  total_claim_value_rupees numeric,
  approval_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.oem_name,
         COUNT(*)::int,
         (COUNT(*) FILTER (WHERE c.status IN ('approved','reimbursed')))::int,
         (COUNT(*) FILTER (WHERE c.status='rejected'))::int,
         (COUNT(*) FILTER (WHERE c.status='oem_disputed'))::int,
         COALESCE(SUM(c.claim_amount_rupees),0)::numeric,
         CASE WHEN COUNT(*) FILTER (WHERE c.status IN ('approved','reimbursed','rejected')) > 0
              THEN ROUND(100.0 * COUNT(*) FILTER (WHERE c.status IN ('approved','reimbursed')) / NULLIF(COUNT(*) FILTER (WHERE c.status IN ('approved','reimbursed','rejected')),0), 1)
              ELSE 0 END
  FROM hospital_oem_warranty_claims c
  GROUP BY c.oem_name
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_oem_warranty_by_oem() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_oem_warranty_by_oem() TO authenticated;

-- RPC 6: top hospitals by claim volume
CREATE OR REPLACE FUNCTION founder_hospital_oem_warranty_top_hospitals()
RETURNS TABLE(
  hospital_org_id uuid,
  hospital_name text,
  state text,
  claim_count int,
  total_claim_value_rupees numeric,
  total_reimbursed_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.hospital_org_id, o.name, o.state,
         COUNT(*)::int,
         COALESCE(SUM(c.claim_amount_rupees),0)::numeric,
         COALESCE(SUM(c.reimbursed_amount_rupees) FILTER (WHERE c.status='reimbursed'),0)::numeric
  FROM hospital_oem_warranty_claims c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  GROUP BY c.hospital_org_id, o.name, o.state
  ORDER BY COUNT(*) DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_oem_warranty_top_hospitals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_oem_warranty_top_hospitals() TO authenticated;

-- RPC 7: 30-day daily trend
CREATE OR REPLACE FUNCTION founder_hospital_oem_warranty_daily_trend()
RETURNS TABLE(
  filed_day date,
  claims_filed int,
  claims_approved int,
  claims_rejected int,
  total_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('day', c.filed_at)::date,
         COUNT(*)::int,
         (COUNT(*) FILTER (WHERE c.status IN ('approved','reimbursed')))::int,
         (COUNT(*) FILTER (WHERE c.status='rejected'))::int,
         COALESCE(SUM(c.claim_amount_rupees),0)::numeric
  FROM hospital_oem_warranty_claims c
  WHERE c.filed_at > now() - interval '30 days'
  GROUP BY date_trunc('day', c.filed_at)::date
  ORDER BY date_trunc('day', c.filed_at)::date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_oem_warranty_daily_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_oem_warranty_daily_trend() TO authenticated;

COMMIT;