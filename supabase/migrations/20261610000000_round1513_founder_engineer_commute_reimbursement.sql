BEGIN;

-- =========================================================================
-- Round 1513 — Engineer Commute Reimbursement
-- Per-job commute claims (distance, vehicle, fuel, per-km rate),
-- approval ladder, per-engineer monthly cap, founder review for outliers.
-- =========================================================================

-- ---- Tables ----
CREATE TABLE IF NOT EXISTS engineer_commute_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES repair_jobs(id) ON DELETE SET NULL,
  claim_month date NOT NULL,
  vehicle_type text NOT NULL CHECK (vehicle_type IN ('two_wheeler','car','public_transport','other')),
  distance_km numeric(10,2) NOT NULL CHECK (distance_km >= 0),
  per_km_rate_rupees numeric(10,2) NOT NULL CHECK (per_km_rate_rupees >= 0),
  fuel_cost_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (fuel_cost_rupees >= 0),
  toll_cost_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (toll_cost_rupees >= 0),
  computed_amount_rupees numeric(12,2) NOT NULL CHECK (computed_amount_rupees >= 0),
  approval_state text NOT NULL DEFAULT 'submitted'
    CHECK (approval_state IN ('submitted','team_lead_approved','ops_approved','founder_approved','rejected','paid')),
  approval_level smallint NOT NULL DEFAULT 0,
  flagged_outlier boolean NOT NULL DEFAULT false,
  outlier_reason text,
  rejection_reason text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  team_lead_approved_at timestamptz,
  ops_approved_at timestamptz,
  founder_reviewed_at timestamptz,
  paid_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecc_engineer_month ON engineer_commute_claims(engineer_id, claim_month);
CREATE INDEX IF NOT EXISTS idx_ecc_state ON engineer_commute_claims(approval_state);
CREATE INDEX IF NOT EXISTS idx_ecc_outlier ON engineer_commute_claims(flagged_outlier) WHERE flagged_outlier;
CREATE INDEX IF NOT EXISTS idx_ecc_submitted ON engineer_commute_claims(submitted_at DESC);

ALTER TABLE engineer_commute_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_ecc ON engineer_commute_claims;
CREATE POLICY founder_only_ecc ON engineer_commute_claims
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_commute_monthly_caps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  cap_month date NOT NULL,
  cap_amount_rupees numeric(12,2) NOT NULL CHECK (cap_amount_rupees >= 0),
  used_amount_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (used_amount_rupees >= 0),
  set_by_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id, cap_month)
);

CREATE INDEX IF NOT EXISTS idx_eccap_engineer ON engineer_commute_monthly_caps(engineer_id);
CREATE INDEX IF NOT EXISTS idx_eccap_month ON engineer_commute_monthly_caps(cap_month);

ALTER TABLE engineer_commute_monthly_caps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_eccap ON engineer_commute_monthly_caps;
CREATE POLICY founder_only_eccap ON engineer_commute_monthly_caps
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---- Helpers ----
CREATE OR REPLACE FUNCTION log_founder_commute_claim_review(p_claim_id uuid, p_decision text, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'commute_claim_review',
    jsonb_build_object('claim_id', p_claim_id, 'decision', p_decision, 'reason', p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_commute_cap_change(p_engineer_id uuid, p_month date, p_amount numeric)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'commute_cap_change',
    jsonb_build_object('engineer_id', p_engineer_id, 'month', p_month, 'amount', p_amount));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_commute_outlier_flag(p_claim_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'commute_outlier_flag',
    jsonb_build_object('claim_id', p_claim_id, 'reason', p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_commute_bulk_pay(p_count int, p_total numeric)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'commute_bulk_pay',
    jsonb_build_object('count', p_count, 'total_rupees', p_total));
END;
$$;

-- ---- READ RPCs (STABLE) ----
CREATE OR REPLACE FUNCTION rpc_founder_commute_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_now timestamptz := now();
  v_month_start date := date_trunc('month', v_now)::date;
  v_result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT jsonb_build_object(
    'total_claims_mtd', (SELECT count(*) FROM engineer_commute_claims WHERE claim_month = v_month_start),
    'total_amount_mtd_rupees', (SELECT COALESCE(SUM(computed_amount_rupees),0) FROM engineer_commute_claims WHERE claim_month = v_month_start),
    'pending_submitted', (SELECT count(*) FROM engineer_commute_claims WHERE approval_state = 'submitted'),
    'pending_team_lead', (SELECT count(*) FROM engineer_commute_claims WHERE approval_state = 'team_lead_approved'),
    'pending_ops', (SELECT count(*) FROM engineer_commute_claims WHERE approval_state = 'ops_approved'),
    'rejected_mtd', (SELECT count(*) FROM engineer_commute_claims WHERE approval_state = 'rejected' AND claim_month = v_month_start),
    'paid_mtd', (SELECT count(*) FROM engineer_commute_claims WHERE approval_state = 'paid' AND claim_month = v_month_start),
    'paid_amount_mtd_rupees', (SELECT COALESCE(SUM(computed_amount_rupees),0) FROM engineer_commute_claims WHERE approval_state = 'paid' AND claim_month = v_month_start),
    'flagged_outliers', (SELECT count(*) FROM engineer_commute_claims WHERE flagged_outlier AND approval_state NOT IN ('paid','rejected')),
    'engineers_with_claims_mtd', (SELECT count(DISTINCT engineer_id) FROM engineer_commute_claims WHERE claim_month = v_month_start),
    'engineers_over_cap', (
      SELECT count(*) FROM engineer_commute_monthly_caps
      WHERE cap_month = v_month_start AND used_amount_rupees > cap_amount_rupees
    ),
    'avg_claim_amount_rupees', (SELECT COALESCE(ROUND(AVG(computed_amount_rupees)::numeric, 2), 0) FROM engineer_commute_claims WHERE claim_month = v_month_start),
    'avg_distance_km', (SELECT COALESCE(ROUND(AVG(distance_km)::numeric, 2), 0) FROM engineer_commute_claims WHERE claim_month = v_month_start),
    'max_single_claim_rupees', (SELECT COALESCE(MAX(computed_amount_rupees), 0) FROM engineer_commute_claims WHERE claim_month = v_month_start),
    'two_wheeler_share_pct', (
      SELECT COALESCE(ROUND(100.0 * count(*) FILTER (WHERE vehicle_type = 'two_wheeler') / NULLIF(count(*),0), 1), 0)
      FROM engineer_commute_claims WHERE claim_month = v_month_start
    ),
    'founder_reviews_needed', (SELECT count(*) FROM engineer_commute_claims WHERE flagged_outlier AND approval_state = 'ops_approved')
  ) INTO v_result;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_commute_pending_claims()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  vehicle_type text,
  distance_km numeric,
  per_km_rate_rupees numeric,
  computed_amount_rupees numeric,
  approval_state text,
  flagged_outlier boolean,
  submitted_at timestamptz,
  claim_month date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_id, c.vehicle_type, c.distance_km, c.per_km_rate_rupees,
         c.computed_amount_rupees, c.approval_state, c.flagged_outlier, c.submitted_at, c.claim_month
  FROM engineer_commute_claims c
  WHERE c.approval_state IN ('submitted','team_lead_approved','ops_approved')
  ORDER BY c.flagged_outlier DESC, c.submitted_at ASC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_commute_outliers()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  distance_km numeric,
  computed_amount_rupees numeric,
  outlier_reason text,
  approval_state text,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_id, c.distance_km, c.computed_amount_rupees,
         c.outlier_reason, c.approval_state, c.submitted_at
  FROM engineer_commute_claims c
  WHERE c.flagged_outlier
  ORDER BY c.computed_amount_rupees DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_commute_engineer_summary()
RETURNS TABLE(
  engineer_id uuid,
  claims_count integer,
  total_amount_rupees numeric,
  total_distance_km numeric,
  cap_amount_rupees numeric,
  used_amount_rupees numeric,
  over_cap boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_month date := date_trunc('month', now())::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_id,
         count(*)::integer AS claims_count,
         COALESCE(SUM(c.computed_amount_rupees),0)::numeric AS total_amount_rupees,
         COALESCE(SUM(c.distance_km),0)::numeric AS total_distance_km,
         COALESCE(cap.cap_amount_rupees, 0)::numeric AS cap_amount_rupees,
         COALESCE(cap.used_amount_rupees, 0)::numeric AS used_amount_rupees,
         (COALESCE(cap.used_amount_rupees,0) > COALESCE(cap.cap_amount_rupees,0)) AS over_cap
  FROM engineer_commute_claims c
  LEFT JOIN engineer_commute_monthly_caps cap
    ON cap.engineer_id = c.engineer_id AND cap.cap_month = v_month
  WHERE c.claim_month = v_month
  GROUP BY c.engineer_id, cap.cap_amount_rupees, cap.used_amount_rupees
  ORDER BY total_amount_rupees DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_commute_recent_decisions()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  approval_state text,
  computed_amount_rupees numeric,
  founder_reviewed_at timestamptz,
  paid_at timestamptz,
  rejection_reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_id, c.approval_state, c.computed_amount_rupees,
         c.founder_reviewed_at, c.paid_at, c.rejection_reason
  FROM engineer_commute_claims c
  WHERE c.approval_state IN ('paid','rejected','founder_approved')
    AND COALESCE(c.founder_reviewed_at, c.paid_at) IS NOT NULL
  ORDER BY COALESCE(c.founder_reviewed_at, c.paid_at) DESC
  LIMIT 100;
END;
$$;

-- ---- WRITE RPCs (VOLATILE) ----
CREATE OR REPLACE FUNCTION rpc_founder_commute_approve(p_claim_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_commute_claims
     SET approval_state = 'founder_approved',
         founder_reviewed_at = now(),
         updated_at = now()
   WHERE id = p_claim_id;
  PERFORM log_founder_commute_claim_review(p_claim_id, 'approved', NULL);
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_commute_reject(p_claim_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_commute_claims
     SET approval_state = 'rejected',
         rejection_reason = p_reason,
         founder_reviewed_at = now(),
         updated_at = now()
   WHERE id = p_claim_id;
  PERFORM log_founder_commute_claim_review(p_claim_id, 'rejected', p_reason);
END;
$$;

-- ---- Permissions ----
REVOKE EXECUTE ON FUNCTION rpc_founder_commute_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_commute_pending_claims() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_commute_outliers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_commute_engineer_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_commute_recent_decisions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_commute_approve(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_commute_reject(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_founder_commute_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_commute_pending_claims() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_commute_outliers() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_commute_engineer_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_commute_recent_decisions() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_commute_approve(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_commute_reject(uuid, text) TO authenticated;

COMMIT;