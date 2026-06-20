BEGIN;

-- =====================================================================
-- r1498 — Founder Hospital Contract NPV Ladder
-- Compute per-AMC NPV (rev - cost - discount over 3yr term, discounted at WACC)
-- Rank by NPV; surface negative-NPV contracts for renegotiation
-- =====================================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS founder_contract_npv_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL,
  hospital_org_id uuid,
  hospital_user_id uuid,
  amc_tier text,
  term_months int NOT NULL DEFAULT 36,
  wacc_bps int NOT NULL DEFAULT 1500,  -- 15%
  monthly_fee_rupees numeric(14,2) NOT NULL DEFAULT 0,
  monthly_cost_rupees numeric(14,2) NOT NULL DEFAULT 0,
  upfront_discount_rupees numeric(14,2) NOT NULL DEFAULT 0,
  gross_revenue_rupees numeric(14,2) NOT NULL DEFAULT 0,
  gross_cost_rupees numeric(14,2) NOT NULL DEFAULT 0,
  npv_rupees numeric(14,2) NOT NULL DEFAULT 0,
  irr_bps int,
  payback_months int,
  status text NOT NULL DEFAULT 'computed',  -- computed | flagged | renegotiated | terminated
  notes text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcnpv_snap_amc ON founder_contract_npv_snapshots(amc_contract_id);
CREATE INDEX IF NOT EXISTS idx_fcnpv_snap_npv ON founder_contract_npv_snapshots(npv_rupees);
CREATE INDEX IF NOT EXISTS idx_fcnpv_snap_status ON founder_contract_npv_snapshots(status);

ALTER TABLE founder_contract_npv_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcnpv_snap_founder_only ON founder_contract_npv_snapshots;
CREATE POLICY fcnpv_snap_founder_only ON founder_contract_npv_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_contract_renegotiation_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL,
  snapshot_id uuid REFERENCES founder_contract_npv_snapshots(id) ON DELETE SET NULL,
  action_type text NOT NULL,  -- flag | propose_increase | propose_discount_cut | terminate | restructure
  proposed_fee_rupees numeric(14,2),
  proposed_discount_rupees numeric(14,2),
  expected_npv_lift_rupees numeric(14,2),
  rationale text,
  outcome text,  -- pending | accepted | declined | counter
  actor_user_id uuid,
  acted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcnpv_action_amc ON founder_contract_renegotiation_actions(amc_contract_id);
CREATE INDEX IF NOT EXISTS idx_fcnpv_action_outcome ON founder_contract_renegotiation_actions(outcome);

ALTER TABLE founder_contract_renegotiation_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcnpv_action_founder_only ON founder_contract_renegotiation_actions;
CREATE POLICY fcnpv_action_founder_only ON founder_contract_renegotiation_actions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- READ RPCs (STABLE) ----------

CREATE OR REPLACE FUNCTION founder_npv_ladder()
RETURNS TABLE(
  amc_contract_id uuid,
  hospital_user_id uuid,
  hospital_email text,
  amc_tier text,
  monthly_fee_rupees numeric,
  gross_revenue_rupees numeric,
  gross_cost_rupees numeric,
  upfront_discount_rupees numeric,
  npv_rupees numeric,
  rank_pos int,
  computed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.amc_contract_id) s.*
    FROM founder_contract_npv_snapshots s
    ORDER BY s.amc_contract_id, s.computed_at DESC
  )
  SELECT l.amc_contract_id,
         l.hospital_user_id,
         p.email::text,
         l.amc_tier,
         l.monthly_fee_rupees,
         l.gross_revenue_rupees,
         l.gross_cost_rupees,
         l.upfront_discount_rupees,
         l.npv_rupees,
         (rank() OVER (ORDER BY l.npv_rupees DESC))::int AS rank_pos,
         l.computed_at
  FROM latest l
  LEFT JOIN profiles p ON p.id = l.hospital_user_id
  ORDER BY l.npv_rupees ASC
  LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION founder_npv_summary()
RETURNS TABLE(
  total_contracts int,
  positive_npv_count int,
  negative_npv_count int,
  zero_npv_count int,
  total_npv_rupees numeric,
  avg_npv_rupees numeric,
  median_npv_rupees numeric,
  worst_npv_rupees numeric,
  best_npv_rupees numeric,
  total_revenue_rupees numeric,
  total_cost_rupees numeric,
  total_discount_rupees numeric,
  pending_actions int,
  flagged_count int,
  renegotiated_count int,
  last_compute_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.amc_contract_id) s.*
    FROM founder_contract_npv_snapshots s
    ORDER BY s.amc_contract_id, s.computed_at DESC
  )
  SELECT
    (SELECT count(*)::int FROM latest),
    (SELECT count(*)::int FROM latest WHERE npv_rupees > 0),
    (SELECT count(*)::int FROM latest WHERE npv_rupees < 0),
    (SELECT count(*)::int FROM latest WHERE npv_rupees = 0),
    COALESCE((SELECT sum(npv_rupees) FROM latest), 0)::numeric,
    COALESCE((SELECT avg(npv_rupees) FROM latest), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY npv_rupees) FROM latest), 0)::numeric,
    COALESCE((SELECT min(npv_rupees) FROM latest), 0)::numeric,
    COALESCE((SELECT max(npv_rupees) FROM latest), 0)::numeric,
    COALESCE((SELECT sum(gross_revenue_rupees) FROM latest), 0)::numeric,
    COALESCE((SELECT sum(gross_cost_rupees) FROM latest), 0)::numeric,
    COALESCE((SELECT sum(upfront_discount_rupees) FROM latest), 0)::numeric,
    (SELECT count(*)::int FROM founder_contract_renegotiation_actions WHERE outcome = 'pending'),
    (SELECT count(*)::int FROM latest WHERE status = 'flagged'),
    (SELECT count(*)::int FROM latest WHERE status = 'renegotiated'),
    (SELECT max(computed_at) FROM latest);
END $$;

CREATE OR REPLACE FUNCTION founder_npv_negative_contracts()
RETURNS TABLE(
  amc_contract_id uuid,
  hospital_email text,
  amc_tier text,
  monthly_fee_rupees numeric,
  gross_cost_rupees numeric,
  upfront_discount_rupees numeric,
  npv_rupees numeric,
  loss_per_month numeric,
  computed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.amc_contract_id) s.*
    FROM founder_contract_npv_snapshots s
    ORDER BY s.amc_contract_id, s.computed_at DESC
  )
  SELECT l.amc_contract_id,
         p.email::text,
         l.amc_tier,
         l.monthly_fee_rupees,
         l.gross_cost_rupees,
         l.upfront_discount_rupees,
         l.npv_rupees,
         CASE WHEN l.term_months > 0 THEN (l.npv_rupees / l.term_months)::numeric ELSE 0 END,
         l.computed_at
  FROM latest l
  LEFT JOIN profiles p ON p.id = l.hospital_user_id
  WHERE l.npv_rupees < 0
  ORDER BY l.npv_rupees ASC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION founder_npv_by_tier()
RETURNS TABLE(
  amc_tier text,
  contract_count int,
  avg_npv_rupees numeric,
  total_npv_rupees numeric,
  negative_count int,
  avg_monthly_fee numeric,
  avg_discount numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.amc_contract_id) s.*
    FROM founder_contract_npv_snapshots s
    ORDER BY s.amc_contract_id, s.computed_at DESC
  )
  SELECT COALESCE(l.amc_tier, 'unknown')::text,
         count(*)::int,
         COALESCE(avg(l.npv_rupees), 0)::numeric,
         COALESCE(sum(l.npv_rupees), 0)::numeric,
         count(*) FILTER (WHERE l.npv_rupees < 0)::int,
         COALESCE(avg(l.monthly_fee_rupees), 0)::numeric,
         COALESCE(avg(l.upfront_discount_rupees), 0)::numeric
  FROM latest l
  GROUP BY COALESCE(l.amc_tier, 'unknown')
  ORDER BY total_npv_rupees ASC;
END $$;

CREATE OR REPLACE FUNCTION founder_npv_renegotiation_actions()
RETURNS TABLE(
  id uuid,
  amc_contract_id uuid,
  action_type text,
  proposed_fee_rupees numeric,
  expected_npv_lift_rupees numeric,
  outcome text,
  rationale text,
  acted_at timestamptz,
  days_open numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id,
         a.amc_contract_id,
         a.action_type,
         a.proposed_fee_rupees,
         a.expected_npv_lift_rupees,
         a.outcome,
         a.rationale,
         a.acted_at,
         (EXTRACT(EPOCH FROM (now() - a.acted_at))/86400.0)::numeric
  FROM founder_contract_renegotiation_actions a
  ORDER BY a.acted_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION founder_npv_top_lifts()
RETURNS TABLE(
  amc_contract_id uuid,
  hospital_email text,
  current_npv_rupees numeric,
  expected_npv_lift_rupees numeric,
  action_type text,
  outcome text,
  acted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.amc_contract_id) s.*
    FROM founder_contract_npv_snapshots s
    ORDER BY s.amc_contract_id, s.computed_at DESC
  )
  SELECT a.amc_contract_id,
         p.email::text,
         l.npv_rupees,
         a.expected_npv_lift_rupees,
         a.action_type,
         a.outcome,
         a.acted_at
  FROM founder_contract_renegotiation_actions a
  LEFT JOIN latest l ON l.amc_contract_id = a.amc_contract_id
  LEFT JOIN profiles p ON p.id = l.hospital_user_id
  WHERE a.expected_npv_lift_rupees IS NOT NULL
  ORDER BY a.expected_npv_lift_rupees DESC NULLS LAST
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION founder_npv_recompute_preview()
RETURNS TABLE(
  candidate_count int,
  amc_with_no_snapshot int,
  oldest_snapshot_age_days numeric,
  est_negative_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM amc_contracts),
    (SELECT count(*)::int FROM amc_contracts c
      WHERE NOT EXISTS (SELECT 1 FROM founder_contract_npv_snapshots s WHERE s.amc_contract_id = c.id)),
    COALESCE((SELECT EXTRACT(EPOCH FROM (now() - min(computed_at)))/86400.0 FROM founder_contract_npv_snapshots), 0)::numeric,
    (SELECT count(*)::int FROM founder_contract_npv_snapshots WHERE npv_rupees < 0);
END $$;

-- ---------- WRITE RPCs (VOLATILE) ----------

CREATE OR REPLACE FUNCTION log_founder_npv_snapshot(
  p_amc_contract_id uuid,
  p_monthly_fee numeric,
  p_monthly_cost numeric,
  p_upfront_discount numeric,
  p_wacc_bps int DEFAULT 1500,
  p_term_months int DEFAULT 36
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_hospital_user_id uuid;
  v_org_id uuid;
  v_tier text;
  v_rev numeric := 0;
  v_cost numeric := 0;
  v_npv numeric := 0;
  v_r numeric;
  v_disc numeric;
  m int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT c.hospital_user_id, c.amc_tier
    INTO v_hospital_user_id, v_tier
  FROM amc_contracts c WHERE c.id = p_amc_contract_id;

  SELECT p.organization_id INTO v_org_id FROM profiles p WHERE p.id = v_hospital_user_id;

  v_r := (p_wacc_bps::numeric / 10000.0) / 12.0;

  FOR m IN 1..p_term_months LOOP
    v_disc := power(1 + v_r, m);
    v_rev  := v_rev  + (p_monthly_fee  / v_disc);
    v_cost := v_cost + (p_monthly_cost / v_disc);
  END LOOP;

  v_npv := v_rev - v_cost - p_upfront_discount;

  INSERT INTO founder_contract_npv_snapshots(
    amc_contract_id, hospital_org_id, hospital_user_id, amc_tier,
    term_months, wacc_bps, monthly_fee_rupees, monthly_cost_rupees,
    upfront_discount_rupees, gross_revenue_rupees, gross_cost_rupees,
    npv_rupees, status
  ) VALUES (
    p_amc_contract_id, v_org_id, v_hospital_user_id, v_tier,
    p_term_months, p_wacc_bps, p_monthly_fee, p_monthly_cost,
    p_upfront_discount, v_rev, v_cost,
    v_npv, CASE WHEN v_npv < 0 THEN 'flagged' ELSE 'computed' END
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'founder.npv.snapshot',
          jsonb_build_object('snapshot_id', v_id, 'amc_contract_id', p_amc_contract_id, 'npv_rupees', v_npv));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION log_founder_npv_flag(
  p_amc_contract_id uuid,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_snap uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT id INTO v_snap FROM founder_contract_npv_snapshots
  WHERE amc_contract_id = p_amc_contract_id
  ORDER BY computed_at DESC LIMIT 1;

  UPDATE founder_contract_npv_snapshots
    SET status = 'flagged', notes = COALESCE(p_notes, notes)
    WHERE id = v_snap;

  INSERT INTO founder_contract_renegotiation_actions(
    amc_contract_id, snapshot_id, action_type, rationale, outcome, actor_user_id
  ) VALUES (
    p_amc_contract_id, v_snap, 'flag', p_notes, 'pending', auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'founder.npv.flag',
          jsonb_build_object('action_id', v_id, 'amc_contract_id', p_amc_contract_id));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION log_founder_npv_propose(
  p_amc_contract_id uuid,
  p_action_type text,
  p_proposed_fee numeric,
  p_proposed_discount numeric,
  p_expected_lift numeric,
  p_rationale text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_snap uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT id INTO v_snap FROM founder_contract_npv_snapshots
  WHERE amc_contract_id = p_amc_contract_id
  ORDER BY computed_at DESC LIMIT 1;

  INSERT INTO founder_contract_renegotiation_actions(
    amc_contract_id, snapshot_id, action_type,
    proposed_fee_rupees, proposed_discount_rupees, expected_npv_lift_rupees,
    rationale, outcome, actor_user_id
  ) VALUES (
    p_amc_contract_id, v_snap, p_action_type,
    p_proposed_fee, p_proposed_discount, p_expected_lift,
    p_rationale, 'pending', auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'founder.npv.propose',
          jsonb_build_object('action_id', v_id, 'amc_contract_id', p_amc_contract_id, 'lift', p_expected_lift));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION log_founder_npv_resolve(
  p_action_id uuid,
  p_outcome text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_amc uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_contract_renegotiation_actions
    SET outcome = p_outcome
    WHERE id = p_action_id
    RETURNING amc_contract_id INTO v_amc;

  IF p_outcome = 'accepted' THEN
    UPDATE founder_contract_npv_snapshots
      SET status = 'renegotiated'
      WHERE amc_contract_id = v_amc
        AND id = (SELECT id FROM founder_contract_npv_snapshots
                  WHERE amc_contract_id = v_amc
                  ORDER BY computed_at DESC LIMIT 1);
  END IF;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'founder.npv.resolve',
          jsonb_build_object('action_id', p_action_id, 'outcome', p_outcome));

  RETURN p_action_id;
END $$;

-- ---------- Grants ----------

REVOKE EXECUTE ON FUNCTION founder_npv_ladder() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_npv_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_npv_negative_contracts() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_npv_by_tier() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_npv_renegotiation_actions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_npv_top_lifts() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_npv_recompute_preview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_npv_snapshot(uuid, numeric, numeric, numeric, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_npv_flag(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_npv_propose(uuid, text, numeric, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_npv_resolve(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_npv_ladder() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_npv_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_npv_negative_contracts() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_npv_by_tier() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_npv_renegotiation_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_npv_top_lifts() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_npv_recompute_preview() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_npv_snapshot(uuid, numeric, numeric, numeric, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_npv_flag(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_npv_propose(uuid, text, numeric, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_npv_resolve(uuid, text) TO authenticated;

COMMIT;