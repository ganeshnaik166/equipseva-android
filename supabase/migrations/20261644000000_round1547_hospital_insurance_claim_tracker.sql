BEGIN;

-- ============================================================
-- r1547 — Hospital Insurance Claim Tracker
-- Founder-only console for tracking insurance claims filed by
-- hospitals against repair jobs (filed/approved/rejected),
-- per-hospital approval rate, and finance reconciliation.
-- ============================================================

CREATE TABLE IF NOT EXISTS hospital_insurance_claims_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES repair_jobs(id) ON DELETE SET NULL,
  insurer_name text NOT NULL,
  policy_number text,
  claim_reference text,
  claimed_amount_rupees integer NOT NULL CHECK (claimed_amount_rupees >= 0),
  approved_amount_rupees integer CHECK (approved_amount_rupees IS NULL OR approved_amount_rupees >= 0),
  status text NOT NULL DEFAULT 'filed' CHECK (status IN ('filed','approved','rejected','partial','withdrawn')),
  filed_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  reconciled_at timestamptz,
  rejection_reason text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hic_v2_hospital ON hospital_insurance_claims_v2(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hic_v2_status  ON hospital_insurance_claims_v2(status);
CREATE INDEX IF NOT EXISTS idx_hic_v2_filed   ON hospital_insurance_claims_v2(filed_at DESC);

ALTER TABLE hospital_insurance_claims_v2 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hic_v2_founder_only ON hospital_insurance_claims_v2;
CREATE POLICY hic_v2_founder_only ON hospital_insurance_claims_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_insurance_claim_events_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES hospital_insurance_claims_v2(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('filed','status_changed','approved','rejected','reconciled','note_added')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hic_v2_events_claim ON hospital_insurance_claim_events_v2(claim_id, occurred_at DESC);

ALTER TABLE hospital_insurance_claim_events_v2 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hic_v2_events_founder_only ON hospital_insurance_claim_events_v2;
CREATE POLICY hic_v2_events_founder_only ON hospital_insurance_claim_events_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_insurance_claim_summary()
RETURNS TABLE (
  total_claims bigint,
  filed_claims bigint,
  approved_claims bigint,
  rejected_claims bigint,
  partial_claims bigint,
  withdrawn_claims bigint,
  total_claimed_rupees bigint,
  total_approved_rupees bigint,
  approval_rate_pct numeric,
  reconciled_claims bigint,
  unreconciled_approved bigint,
  hospitals_with_claims bigint,
  avg_decision_days numeric,
  claims_last_30d bigint,
  approved_last_30d bigint,
  rejected_last_30d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='filed')::bigint,
    COUNT(*) FILTER (WHERE status='approved')::bigint,
    COUNT(*) FILTER (WHERE status='rejected')::bigint,
    COUNT(*) FILTER (WHERE status='partial')::bigint,
    COUNT(*) FILTER (WHERE status='withdrawn')::bigint,
    COALESCE(SUM(claimed_amount_rupees),0)::bigint,
    COALESCE(SUM(approved_amount_rupees) FILTER (WHERE status IN ('approved','partial')),0)::bigint,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE status IN ('approved','partial'))::numeric
      / NULLIF(COUNT(*) FILTER (WHERE status IN ('approved','partial','rejected')),0),
    2),
    COUNT(*) FILTER (WHERE reconciled_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE status IN ('approved','partial') AND reconciled_at IS NULL)::bigint,
    COUNT(DISTINCT hospital_org_id)::bigint,
    ROUND(AVG( (decided_at::date - filed_at::date) ) FILTER (WHERE decided_at IS NOT NULL), 2),
    COUNT(*) FILTER (WHERE filed_at >= now() - interval '30 days')::bigint,
    COUNT(*) FILTER (WHERE status='approved' AND decided_at >= now() - interval '30 days')::bigint,
    COUNT(*) FILTER (WHERE status='rejected' AND decided_at >= now() - interval '30 days')::bigint
  FROM hospital_insurance_claims_v2;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_insurance_claim_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_insurance_claim_summary() TO authenticated;

CREATE OR REPLACE FUNCTION founder_insurance_claims_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  insurer_name text,
  claim_reference text,
  status text,
  claimed_amount_rupees integer,
  approved_amount_rupees integer,
  filed_at timestamptz,
  decided_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_org_id, o.name, c.insurer_name, c.claim_reference,
         c.status, c.claimed_amount_rupees, c.approved_amount_rupees,
         c.filed_at, c.decided_at
  FROM hospital_insurance_claims_v2 c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  ORDER BY c.filed_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 50), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_insurance_claims_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_insurance_claims_recent(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_insurance_per_hospital()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  total_claims bigint,
  approved_count bigint,
  rejected_count bigint,
  partial_count bigint,
  approval_rate_pct numeric,
  total_claimed_rupees bigint,
  total_approved_rupees bigint,
  unreconciled_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.hospital_org_id,
         o.name,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.status='approved')::bigint,
         COUNT(*) FILTER (WHERE c.status='rejected')::bigint,
         COUNT(*) FILTER (WHERE c.status='partial')::bigint,
         ROUND(
           100.0 * COUNT(*) FILTER (WHERE c.status IN ('approved','partial'))::numeric
           / NULLIF(COUNT(*) FILTER (WHERE c.status IN ('approved','partial','rejected')),0),
         2),
         COALESCE(SUM(c.claimed_amount_rupees),0)::bigint,
         COALESCE(SUM(c.approved_amount_rupees) FILTER (WHERE c.status IN ('approved','partial')),0)::bigint,
         COUNT(*) FILTER (WHERE c.status IN ('approved','partial') AND c.reconciled_at IS NULL)::bigint
  FROM hospital_insurance_claims_v2 c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  GROUP BY c.hospital_org_id, o.name
  ORDER BY COUNT(*) DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_insurance_per_hospital() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_insurance_per_hospital() TO authenticated;

CREATE OR REPLACE FUNCTION founder_insurance_per_insurer()
RETURNS TABLE (
  insurer_name text,
  total_claims bigint,
  approved_count bigint,
  rejected_count bigint,
  approval_rate_pct numeric,
  total_claimed_rupees bigint,
  total_approved_rupees bigint,
  avg_decision_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.insurer_name,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.status='approved')::bigint,
         COUNT(*) FILTER (WHERE c.status='rejected')::bigint,
         ROUND(
           100.0 * COUNT(*) FILTER (WHERE c.status IN ('approved','partial'))::numeric
           / NULLIF(COUNT(*) FILTER (WHERE c.status IN ('approved','partial','rejected')),0),
         2),
         COALESCE(SUM(c.claimed_amount_rupees),0)::bigint,
         COALESCE(SUM(c.approved_amount_rupees) FILTER (WHERE c.status IN ('approved','partial')),0)::bigint,
         ROUND(AVG( (c.decided_at::date - c.filed_at::date) ) FILTER (WHERE c.decided_at IS NOT NULL), 2)
  FROM hospital_insurance_claims_v2 c
  GROUP BY c.insurer_name
  ORDER BY COUNT(*) DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_insurance_per_insurer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_insurance_per_insurer() TO authenticated;

CREATE OR REPLACE FUNCTION founder_insurance_unreconciled()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  insurer_name text,
  approved_amount_rupees integer,
  decided_at timestamptz,
  days_since_decision integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_org_id, o.name, c.insurer_name,
         c.approved_amount_rupees, c.decided_at,
         (CURRENT_DATE - c.decided_at::date)::int
  FROM hospital_insurance_claims_v2 c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  WHERE c.status IN ('approved','partial') AND c.reconciled_at IS NULL
  ORDER BY c.decided_at NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_insurance_unreconciled() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_insurance_unreconciled() TO authenticated;

CREATE OR REPLACE FUNCTION founder_insurance_status_timeline(p_days int DEFAULT 30)
RETURNS TABLE (
  day date,
  filed_count bigint,
  approved_count bigint,
  rejected_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (CURRENT_DATE - (GREATEST(COALESCE(p_days,30),1) - 1))::date,
      CURRENT_DATE,
      interval '1 day'
    )::date AS d
  )
  SELECT d.d,
         COUNT(c.id) FILTER (WHERE c.filed_at::date = d.d)::bigint,
         COUNT(c.id) FILTER (WHERE c.status='approved' AND c.decided_at::date = d.d)::bigint,
         COUNT(c.id) FILTER (WHERE c.status='rejected' AND c.decided_at::date = d.d)::bigint
  FROM days d
  LEFT JOIN hospital_insurance_claims_v2 c
    ON c.filed_at::date = d.d OR c.decided_at::date = d.d
  GROUP BY d.d
  ORDER BY d.d;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_insurance_status_timeline(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_insurance_status_timeline(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_insurance_claim_events(p_claim_id uuid)
RETURNS TABLE (
  id uuid,
  event_type text,
  payload jsonb,
  occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_type, e.payload, e.occurred_at
  FROM hospital_insurance_claim_events_v2 e
  WHERE e.claim_id = p_claim_id
  ORDER BY e.occurred_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_insurance_claim_events(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_insurance_claim_events(uuid) TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE) — log_founder_* helpers
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_insurance_claim_file(
  p_hospital_org_id uuid,
  p_insurer_name text,
  p_claimed_amount_rupees integer,
  p_claim_reference text DEFAULT NULL,
  p_repair_job_id uuid DEFAULT NULL,
  p_policy_number text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO hospital_insurance_claims_v2(
    hospital_org_id, insurer_name, claim_reference,
    claimed_amount_rupees, repair_job_id, policy_number, notes, status, filed_at
  ) VALUES (
    p_hospital_org_id, p_insurer_name, p_claim_reference,
    p_claimed_amount_rupees, p_repair_job_id, p_policy_number, p_notes, 'filed', now()
  ) RETURNING id INTO v_id;

  INSERT INTO hospital_insurance_claim_events_v2(claim_id, event_type, payload)
  VALUES (v_id, 'filed', jsonb_build_object(
    'insurer', p_insurer_name,
    'amount', p_claimed_amount_rupees,
    'reference', p_claim_reference
  ));

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'insurance_claim_file',
    jsonb_build_object(
      'claim_id', v_id,
      'hospital_org_id', p_hospital_org_id,
      'insurer', p_insurer_name,
      'amount', p_claimed_amount_rupees
    )
  );

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_insurance_claim_file(uuid, text, integer, text, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_insurance_claim_file(uuid, text, integer, text, uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_insurance_claim_decide(
  p_claim_id uuid,
  p_decision text,
  p_approved_amount_rupees integer DEFAULT NULL,
  p_rejection_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_decision NOT IN ('approved','rejected','partial') THEN
    RAISE EXCEPTION 'invalid decision %', p_decision;
  END IF;

  UPDATE hospital_insurance_claims_v2
  SET status = p_decision,
      approved_amount_rupees = CASE WHEN p_decision IN ('approved','partial') THEN p_approved_amount_rupees ELSE NULL END,
      rejection_reason = CASE WHEN p_decision = 'rejected' THEN p_rejection_reason ELSE NULL END,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_claim_id;

  INSERT INTO hospital_insurance_claim_events_v2(claim_id, event_type, payload)
  VALUES (p_claim_id,
    CASE WHEN p_decision='rejected' THEN 'rejected' ELSE 'approved' END,
    jsonb_build_object('decision', p_decision, 'approved_amount', p_approved_amount_rupees, 'reason', p_rejection_reason)
  );

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'insurance_claim_decide',
    jsonb_build_object('claim_id', p_claim_id, 'decision', p_decision, 'approved_amount', p_approved_amount_rupees)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_insurance_claim_decide(uuid, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_insurance_claim_decide(uuid, text, integer, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_insurance_claim_reconcile(
  p_claim_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE hospital_insurance_claims_v2
  SET reconciled_at = now(),
      notes = COALESCE(p_notes, notes),
      updated_at = now()
  WHERE id = p_claim_id;

  INSERT INTO hospital_insurance_claim_events_v2(claim_id, event_type, payload)
  VALUES (p_claim_id, 'reconciled', jsonb_build_object('notes', p_notes));

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'insurance_claim_reconcile',
    jsonb_build_object('claim_id', p_claim_id)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_insurance_claim_reconcile(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_insurance_claim_reconcile(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_insurance_claim_note(
  p_claim_id uuid,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO hospital_insurance_claim_events_v2(claim_id, event_type, payload)
  VALUES (p_claim_id, 'note_added', jsonb_build_object('note', p_note));

  UPDATE hospital_insurance_claims_v2
  SET notes = COALESCE(notes || E'\n---\n', '') || p_note,
      updated_at = now()
  WHERE id = p_claim_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'insurance_claim_note',
    jsonb_build_object('claim_id', p_claim_id, 'note_len', length(p_note))
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_insurance_claim_note(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_insurance_claim_note(uuid, text) TO authenticated;

COMMIT;