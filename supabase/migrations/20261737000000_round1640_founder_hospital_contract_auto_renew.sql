BEGIN;

-- ============================================================================
-- r1640 — Founder hospital AMC contract auto-renew console
-- ============================================================================

-- Table 1: renewal eligibility snapshots (one row per contract per scan)
CREATE TABLE IF NOT EXISTS founder_hospital_renewal_candidates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES amc_contracts(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL,
  amc_tier text NOT NULL,
  monthly_fee_rupees integer NOT NULL DEFAULT 0,
  ends_on date NOT NULL,
  days_to_expiry integer NOT NULL DEFAULT 0,
  jobs_last_90d integer NOT NULL DEFAULT 0,
  avg_hospital_rating numeric(3,2),
  outstanding_disputes integer NOT NULL DEFAULT 0,
  eligibility_score integer NOT NULL DEFAULT 0,
  auto_eligible boolean NOT NULL DEFAULT false,
  reasons jsonb NOT NULL DEFAULT '[]'::jsonb,
  scanned_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contract_id, scanned_at)
);

CREATE INDEX IF NOT EXISTS idx_fhrc_contract ON founder_hospital_renewal_candidates(contract_id);
CREATE INDEX IF NOT EXISTS idx_fhrc_eligible ON founder_hospital_renewal_candidates(auto_eligible, days_to_expiry);

ALTER TABLE founder_hospital_renewal_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only fhrc" ON founder_hospital_renewal_candidates;
CREATE POLICY "founder only fhrc" ON founder_hospital_renewal_candidates
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: founder go/no-go decisions on a candidate
CREATE TABLE IF NOT EXISTS founder_hospital_renewal_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES founder_hospital_renewal_candidates(id) ON DELETE CASCADE,
  contract_id uuid NOT NULL REFERENCES amc_contracts(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('go','no_go','hold')),
  notes text,
  decided_by uuid NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhrd_contract ON founder_hospital_renewal_decisions(contract_id, decided_at DESC);

ALTER TABLE founder_hospital_renewal_decisions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only fhrd" ON founder_hospital_renewal_decisions;
CREATE POLICY "founder only fhrd" ON founder_hospital_renewal_decisions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- log helper
-- ============================================================================
CREATE OR REPLACE FUNCTION log_founder_hospital_auto_renew(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, COALESCE(p_after,'{}'::jsonb), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_hospital_auto_renew(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hospital_auto_renew(text, jsonb) TO authenticated;

-- ============================================================================
-- RPC 1: KPIs
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_hospital_auto_renew_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total integer;
  v_auto integer;
  v_hold integer;
  v_revenue integer;
  v_avg_score numeric;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT count(DISTINCT contract_id) INTO v_total
  FROM founder_hospital_renewal_candidates
  WHERE scanned_at > now() - interval '7 days';

  SELECT count(DISTINCT contract_id) INTO v_auto
  FROM founder_hospital_renewal_candidates
  WHERE scanned_at > now() - interval '7 days' AND auto_eligible = true;

  SELECT count(*) INTO v_hold
  FROM founder_hospital_renewal_decisions
  WHERE decision = 'hold' AND decided_at > now() - interval '30 days';

  SELECT COALESCE(sum(monthly_fee_rupees * 12), 0) INTO v_revenue
  FROM founder_hospital_renewal_candidates
  WHERE scanned_at > now() - interval '7 days' AND auto_eligible = true;

  SELECT COALESCE(avg(eligibility_score), 0) INTO v_avg_score
  FROM founder_hospital_renewal_candidates
  WHERE scanned_at > now() - interval '7 days';

  RETURN jsonb_build_object(
    'total_candidates', v_total,
    'auto_eligible', v_auto,
    'on_hold', v_hold,
    'arr_at_risk_rupees', v_revenue,
    'avg_score', round(v_avg_score, 1)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_auto_renew_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_auto_renew_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: list candidates (latest scan per contract)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_hospital_auto_renew_candidates()
RETURNS TABLE (
  candidate_id uuid,
  contract_id uuid,
  hospital_name text,
  amc_tier text,
  monthly_fee_rupees integer,
  ends_on date,
  days_to_expiry integer,
  jobs_last_90d integer,
  avg_hospital_rating numeric,
  outstanding_disputes integer,
  eligibility_score integer,
  auto_eligible boolean,
  reasons jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (c.contract_id) c.*
    FROM founder_hospital_renewal_candidates c
    ORDER BY c.contract_id, c.scanned_at DESC
  )
  SELECT
    l.id,
    l.contract_id,
    COALESCE(o.name, p.full_name, 'Hospital'),
    l.amc_tier,
    l.monthly_fee_rupees,
    l.ends_on,
    l.days_to_expiry,
    l.jobs_last_90d,
    l.avg_hospital_rating,
    l.outstanding_disputes,
    l.eligibility_score,
    l.auto_eligible,
    l.reasons
  FROM latest l
  LEFT JOIN profiles p ON p.id = l.hospital_user_id
  LEFT JOIN organizations o ON o.id = p.organization_id
  ORDER BY l.days_to_expiry ASC, l.eligibility_score DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_auto_renew_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_auto_renew_candidates() TO authenticated;

-- ============================================================================
-- RPC 3: tier breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_hospital_auto_renew_by_tier()
RETURNS TABLE (
  amc_tier text,
  candidate_count bigint,
  auto_eligible_count bigint,
  arr_rupees bigint,
  avg_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (contract_id) *
    FROM founder_hospital_renewal_candidates
    ORDER BY contract_id, scanned_at DESC
  )
  SELECT
    l.amc_tier,
    count(*)::bigint,
    count(*) FILTER (WHERE l.auto_eligible)::bigint,
    COALESCE(sum(l.monthly_fee_rupees * 12) FILTER (WHERE l.auto_eligible), 0)::bigint,
    round(avg(l.eligibility_score), 1)
  FROM latest l
  GROUP BY l.amc_tier
  ORDER BY arr_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_auto_renew_by_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_auto_renew_by_tier() TO authenticated;

-- ============================================================================
-- RPC 4: recent founder decisions
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_hospital_auto_renew_recent_decisions()
RETURNS TABLE (
  decision_id uuid,
  contract_id uuid,
  hospital_name text,
  decision text,
  notes text,
  decided_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.contract_id,
    COALESCE(o.name, p.full_name, 'Hospital'),
    d.decision,
    d.notes,
    d.decided_at
  FROM founder_hospital_renewal_decisions d
  LEFT JOIN amc_contracts ac ON ac.id = d.contract_id
  LEFT JOIN profiles p ON p.id = ac.hospital_user_id
  LEFT JOIN organizations o ON o.id = p.organization_id
  ORDER BY d.decided_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_auto_renew_recent_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_auto_renew_recent_decisions() TO authenticated;

-- ============================================================================
-- RPC 5: expiry bucket histogram
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_hospital_auto_renew_expiry_buckets()
RETURNS TABLE (
  bucket text,
  candidate_count bigint,
  arr_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (contract_id) *
    FROM founder_hospital_renewal_candidates
    ORDER BY contract_id, scanned_at DESC
  ), bucketed AS (
    SELECT
      CASE
        WHEN days_to_expiry <= 7 THEN '0-7 days'
        WHEN days_to_expiry <= 30 THEN '8-30 days'
        WHEN days_to_expiry <= 60 THEN '31-60 days'
        WHEN days_to_expiry <= 90 THEN '61-90 days'
        ELSE '90+ days'
      END AS b,
      CASE
        WHEN days_to_expiry <= 7 THEN 1
        WHEN days_to_expiry <= 30 THEN 2
        WHEN days_to_expiry <= 60 THEN 3
        WHEN days_to_expiry <= 90 THEN 4
        ELSE 5
      END AS ord,
      monthly_fee_rupees
    FROM latest
  )
  SELECT b, count(*)::bigint, COALESCE(sum(monthly_fee_rupees * 12), 0)::bigint
  FROM bucketed
  GROUP BY b, ord
  ORDER BY ord;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_auto_renew_expiry_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_auto_renew_expiry_buckets() TO authenticated;

-- ============================================================================
-- RPC 6: scan / refresh candidates (VOLATILE write)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_hospital_auto_renew_scan()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inserted integer := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  WITH base AS (
    SELECT
      ac.id AS contract_id,
      ac.hospital_user_id,
      ac.amc_tier,
      ac.monthly_fee_rupees,
      ac.ends_on,
      (ac.ends_on - current_date)::integer AS days_to_expiry,
      (
        SELECT count(*) FROM repair_jobs rj
        JOIN profiles p ON p.id = ac.hospital_user_id
        WHERE rj.hospital_org_id = p.organization_id
          AND rj.created_at > now() - interval '90 days'
      ) AS jobs_last_90d,
      (
        SELECT avg(rj.hospital_rating) FROM repair_jobs rj
        JOIN profiles p ON p.id = ac.hospital_user_id
        WHERE rj.hospital_org_id = p.organization_id
          AND rj.hospital_rating IS NOT NULL
          AND rj.created_at > now() - interval '180 days'
      ) AS avg_rating,
      (
        SELECT count(*) FROM repair_job_escrow e
        JOIN repair_jobs rj ON rj.id = e.repair_job_id
        JOIN profiles p ON p.id = ac.hospital_user_id
        WHERE rj.hospital_org_id = p.organization_id
          AND e.status = 'in_dispute'
      ) AS disputes
    FROM amc_contracts ac
    WHERE ac.ends_on BETWEEN current_date AND current_date + interval '120 days'
  ), scored AS (
    SELECT *,
      (
        LEAST(jobs_last_90d * 4, 40)
        + COALESCE((avg_rating * 10)::integer, 30)
        + CASE WHEN disputes = 0 THEN 30 ELSE GREATEST(0, 30 - disputes * 10) END
      ) AS score
    FROM base
  )
  INSERT INTO founder_hospital_renewal_candidates(
    contract_id, hospital_user_id, amc_tier, monthly_fee_rupees, ends_on,
    days_to_expiry, jobs_last_90d, avg_hospital_rating, outstanding_disputes,
    eligibility_score, auto_eligible, reasons
  )
  SELECT
    contract_id, hospital_user_id, amc_tier, monthly_fee_rupees, ends_on,
    days_to_expiry, jobs_last_90d, avg_rating, disputes,
    score,
    (score >= 70 AND disputes = 0 AND jobs_last_90d >= 1),
    jsonb_build_array(
      jsonb_build_object('factor','jobs_90d','value',jobs_last_90d),
      jsonb_build_object('factor','avg_rating','value',COALESCE(avg_rating, 0)),
      jsonb_build_object('factor','disputes','value',disputes)
    )
  FROM scored
  ON CONFLICT (contract_id, scanned_at) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  PERFORM log_founder_hospital_auto_renew(
    'auto_renew_scan',
    jsonb_build_object('inserted', v_inserted)
  );

  RETURN v_inserted;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_auto_renew_scan() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_auto_renew_scan() TO authenticated;

-- ============================================================================
-- RPC 7: record founder go/no-go decision (VOLATILE write)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_hospital_auto_renew_decide(
  p_candidate_id uuid,
  p_decision text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_contract_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_decision NOT IN ('go','no_go','hold') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;

  SELECT contract_id INTO v_contract_id
  FROM founder_hospital_renewal_candidates
  WHERE id = p_candidate_id;

  IF v_contract_id IS NULL THEN
    RAISE EXCEPTION 'candidate not found';
  END IF;

  INSERT INTO founder_hospital_renewal_decisions(
    candidate_id, contract_id, decision, notes, decided_by
  ) VALUES (
    p_candidate_id, v_contract_id, p_decision, p_notes, auth.uid()
  )
  RETURNING id INTO v_id;

  PERFORM log_founder_hospital_auto_renew(
    'auto_renew_decision',
    jsonb_build_object(
      'candidate_id', p_candidate_id,
      'contract_id', v_contract_id,
      'decision', p_decision
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_auto_renew_decide(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_auto_renew_decide(uuid, text, text) TO authenticated;

COMMIT;