BEGIN;

-- ============================================================================
-- r1515 — Investor portfolio benchmarks intel
-- Capture peer biomedical AMC startup metrics; benchmark our trajectory.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: peer companies catalog
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_peer_companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  peer_name text NOT NULL UNIQUE,
  peer_country text NOT NULL DEFAULT 'IN',
  peer_segment text NOT NULL DEFAULT 'biomedical_amc',
  founded_year int,
  hq_city text,
  notes text,
  source_url text,
  is_tracked boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_peer_companies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_peer_companies_founder_all ON founder_peer_companies;
CREATE POLICY founder_peer_companies_founder_all
  ON founder_peer_companies
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS founder_peer_companies_tracked_idx
  ON founder_peer_companies(is_tracked, peer_name);

-- ----------------------------------------------------------------------------
-- Table 2: peer metric snapshots (time-series benchmarks)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_peer_metric_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  peer_id uuid NOT NULL REFERENCES founder_peer_companies(id) ON DELETE CASCADE,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  reporting_period text NOT NULL DEFAULT 'monthly',
  gmv_rupees bigint,
  hospital_count int,
  engineer_count int,
  monthly_revenue_rupees bigint,
  fundraise_stage text,
  total_raised_rupees bigint,
  valuation_rupees bigint,
  source_type text NOT NULL DEFAULT 'public',
  source_url text,
  confidence text NOT NULL DEFAULT 'medium',
  recorded_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_peer_metric_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_peer_metric_snapshots_founder_all ON founder_peer_metric_snapshots;
CREATE POLICY founder_peer_metric_snapshots_founder_all
  ON founder_peer_metric_snapshots
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS founder_peer_metric_snapshots_peer_at_idx
  ON founder_peer_metric_snapshots(peer_id, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS founder_peer_metric_snapshots_stage_idx
  ON founder_peer_metric_snapshots(fundraise_stage);

-- ============================================================================
-- Read RPCs (STABLE)
-- ============================================================================

-- R1: peer catalog roster
DROP FUNCTION IF EXISTS founder_peer_roster();
CREATE OR REPLACE FUNCTION founder_peer_roster()
RETURNS TABLE (
  id uuid,
  peer_name text,
  peer_country text,
  peer_segment text,
  founded_year int,
  hq_city text,
  is_tracked boolean,
  snapshot_count bigint,
  latest_snapshot_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT pc.id, pc.peer_name, pc.peer_country, pc.peer_segment, pc.founded_year, pc.hq_city,
         pc.is_tracked,
         COUNT(ps.id) AS snapshot_count,
         MAX(ps.snapshot_at) AS latest_snapshot_at
  FROM founder_peer_companies pc
  LEFT JOIN founder_peer_metric_snapshots ps ON ps.peer_id = pc.id
  GROUP BY pc.id
  ORDER BY pc.is_tracked DESC, pc.peer_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_peer_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_peer_roster() TO authenticated;

-- R2: latest snapshot per peer
DROP FUNCTION IF EXISTS founder_peer_latest_snapshots();
CREATE OR REPLACE FUNCTION founder_peer_latest_snapshots()
RETURNS TABLE (
  id uuid,
  peer_id uuid,
  peer_name text,
  snapshot_at timestamptz,
  gmv_rupees bigint,
  hospital_count int,
  engineer_count int,
  monthly_revenue_rupees bigint,
  fundraise_stage text,
  total_raised_rupees bigint,
  valuation_rupees bigint,
  confidence text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (pc.id)
    ps.id, pc.id AS peer_id, pc.peer_name, ps.snapshot_at,
    ps.gmv_rupees, ps.hospital_count, ps.engineer_count,
    ps.monthly_revenue_rupees, ps.fundraise_stage,
    ps.total_raised_rupees, ps.valuation_rupees, ps.confidence
  FROM founder_peer_companies pc
  JOIN founder_peer_metric_snapshots ps ON ps.peer_id = pc.id
  WHERE pc.is_tracked
  ORDER BY pc.id, ps.snapshot_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_peer_latest_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_peer_latest_snapshots() TO authenticated;

-- R3: our trajectory snapshot (live calc)
DROP FUNCTION IF EXISTS founder_our_trajectory();
CREATE OR REPLACE FUNCTION founder_our_trajectory()
RETURNS TABLE (
  metric text,
  value_rupees bigint,
  value_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gmv bigint;
  v_mrr bigint;
  v_hosp int;
  v_eng int;
  v_amc int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(contracted_amount_rupees),0) INTO v_gmv
    FROM repair_jobs
    WHERE created_at >= now() - interval '30 days';

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_mrr
    FROM amc_contracts
    WHERE status = 'active';

  SELECT COUNT(DISTINCT o.id) INTO v_hosp
    FROM organizations o
    WHERE o.org_type = 'hospital';

  SELECT COUNT(*) INTO v_eng FROM engineers;

  SELECT COUNT(*) INTO v_amc FROM amc_contracts WHERE status = 'active';

  RETURN QUERY VALUES
    ('gmv_30d'::text, v_gmv, NULL::int),
    ('mrr_active_amc'::text, v_mrr, NULL::int),
    ('hospital_count'::text, NULL::bigint, v_hosp),
    ('engineer_count'::text, NULL::bigint, v_eng),
    ('active_amc_count'::text, NULL::bigint, v_amc);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_our_trajectory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_our_trajectory() TO authenticated;

-- R4: stage distribution
DROP FUNCTION IF EXISTS founder_peer_stage_distribution();
CREATE OR REPLACE FUNCTION founder_peer_stage_distribution()
RETURNS TABLE (
  id uuid,
  fundraise_stage text,
  peer_count bigint,
  total_raised_rupees bigint,
  avg_hospital_count numeric,
  avg_engineer_count numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (ps.peer_id)
      ps.peer_id, ps.fundraise_stage, ps.total_raised_rupees,
      ps.hospital_count, ps.engineer_count
    FROM founder_peer_metric_snapshots ps
    ORDER BY ps.peer_id, ps.snapshot_at DESC
  )
  SELECT gen_random_uuid() AS id,
         COALESCE(latest.fundraise_stage,'unknown') AS fundraise_stage,
         COUNT(*) AS peer_count,
         COALESCE(SUM(latest.total_raised_rupees),0) AS total_raised_rupees,
         AVG(latest.hospital_count) AS avg_hospital_count,
         AVG(latest.engineer_count) AS avg_engineer_count
  FROM latest
  GROUP BY latest.fundraise_stage
  ORDER BY peer_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_peer_stage_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_peer_stage_distribution() TO authenticated;

-- R5: trajectory comparison (us vs peer median)
DROP FUNCTION IF EXISTS founder_peer_benchmark_gaps();
CREATE OR REPLACE FUNCTION founder_peer_benchmark_gaps()
RETURNS TABLE (
  id uuid,
  metric text,
  our_value bigint,
  peer_median bigint,
  peer_p75 bigint,
  peer_max bigint,
  gap_to_median_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_our_gmv bigint;
  v_our_hosp bigint;
  v_our_eng bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(contracted_amount_rupees),0) INTO v_our_gmv
    FROM repair_jobs WHERE created_at >= now() - interval '30 days';
  SELECT COUNT(DISTINCT o.id) INTO v_our_hosp FROM organizations o WHERE o.org_type='hospital';
  SELECT COUNT(*) INTO v_our_eng FROM engineers;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (ps.peer_id)
      ps.peer_id, ps.gmv_rupees, ps.hospital_count, ps.engineer_count
    FROM founder_peer_metric_snapshots ps
    ORDER BY ps.peer_id, ps.snapshot_at DESC
  ),
  agg AS (
    SELECT
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gmv_rupees)::bigint AS gmv_med,
      PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY gmv_rupees)::bigint AS gmv_p75,
      MAX(gmv_rupees) AS gmv_max,
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hospital_count)::bigint AS hosp_med,
      PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY hospital_count)::bigint AS hosp_p75,
      MAX(hospital_count)::bigint AS hosp_max,
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY engineer_count)::bigint AS eng_med,
      PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY engineer_count)::bigint AS eng_p75,
      MAX(engineer_count)::bigint AS eng_max
    FROM latest
  )
  SELECT * FROM (
    SELECT gen_random_uuid() AS id, 'gmv_30d'::text AS metric, v_our_gmv AS our_value,
           agg.gmv_med AS peer_median, agg.gmv_p75 AS peer_p75, agg.gmv_max AS peer_max,
           CASE WHEN agg.gmv_med>0 THEN ROUND(((v_our_gmv::numeric - agg.gmv_med)/agg.gmv_med)*100, 1) ELSE NULL END AS gap_to_median_pct
    FROM agg
    UNION ALL
    SELECT gen_random_uuid(), 'hospital_count', v_our_hosp, agg.hosp_med, agg.hosp_p75, agg.hosp_max,
           CASE WHEN agg.hosp_med>0 THEN ROUND(((v_our_hosp::numeric - agg.hosp_med)/agg.hosp_med)*100, 1) ELSE NULL END
    FROM agg
    UNION ALL
    SELECT gen_random_uuid(), 'engineer_count', v_our_eng, agg.eng_med, agg.eng_p75, agg.eng_max,
           CASE WHEN agg.eng_med>0 THEN ROUND(((v_our_eng::numeric - agg.eng_med)/agg.eng_med)*100, 1) ELSE NULL END
    FROM agg
  ) x;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_peer_benchmark_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_peer_benchmark_gaps() TO authenticated;

-- R6: snapshot history per peer (paginated cap)
DROP FUNCTION IF EXISTS founder_peer_snapshot_history(int);
CREATE OR REPLACE FUNCTION founder_peer_snapshot_history(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  peer_name text,
  snapshot_at timestamptz,
  gmv_rupees bigint,
  hospital_count int,
  engineer_count int,
  fundraise_stage text,
  total_raised_rupees bigint,
  confidence text,
  source_type text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ps.id, pc.peer_name, ps.snapshot_at,
         ps.gmv_rupees, ps.hospital_count, ps.engineer_count,
         ps.fundraise_stage, ps.total_raised_rupees,
         ps.confidence, ps.source_type
  FROM founder_peer_metric_snapshots ps
  JOIN founder_peer_companies pc ON pc.id = ps.peer_id
  ORDER BY ps.snapshot_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_peer_snapshot_history(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_peer_snapshot_history(int) TO authenticated;

-- R7: capital efficiency leaders
DROP FUNCTION IF EXISTS founder_peer_capital_efficiency();
CREATE OR REPLACE FUNCTION founder_peer_capital_efficiency()
RETURNS TABLE (
  id uuid,
  peer_name text,
  total_raised_rupees bigint,
  gmv_rupees bigint,
  hospital_count int,
  rupees_per_hospital bigint,
  gmv_per_rupee_raised numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (ps.peer_id)
      ps.peer_id, ps.total_raised_rupees, ps.gmv_rupees, ps.hospital_count
    FROM founder_peer_metric_snapshots ps
    ORDER BY ps.peer_id, ps.snapshot_at DESC
  )
  SELECT pc.id, pc.peer_name,
         latest.total_raised_rupees, latest.gmv_rupees, latest.hospital_count,
         CASE WHEN latest.hospital_count>0 THEN (latest.total_raised_rupees/latest.hospital_count) ELSE NULL END AS rupees_per_hospital,
         CASE WHEN latest.total_raised_rupees>0 THEN ROUND((latest.gmv_rupees::numeric/latest.total_raised_rupees), 4) ELSE NULL END AS gmv_per_rupee_raised
  FROM founder_peer_companies pc
  JOIN latest ON latest.peer_id = pc.id
  WHERE pc.is_tracked
  ORDER BY gmv_per_rupee_raised DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_peer_capital_efficiency() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_peer_capital_efficiency() TO authenticated;

-- ============================================================================
-- Write helpers (VOLATILE) — log_founder_*
-- ============================================================================

-- W1: log peer company add
DROP FUNCTION IF EXISTS log_founder_peer_add(text, text, text, int, text, text);
CREATE OR REPLACE FUNCTION log_founder_peer_add(
  p_peer_name text,
  p_country text DEFAULT 'IN',
  p_segment text DEFAULT 'biomedical_amc',
  p_founded_year int DEFAULT NULL,
  p_hq_city text DEFAULT NULL,
  p_source_url text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_peer_companies(peer_name, peer_country, peer_segment, founded_year, hq_city, source_url)
  VALUES (p_peer_name, p_country, p_segment, p_founded_year, p_hq_city, p_source_url)
  ON CONFLICT (peer_name) DO UPDATE
    SET peer_country = EXCLUDED.peer_country,
        peer_segment = EXCLUDED.peer_segment,
        founded_year = COALESCE(EXCLUDED.founded_year, founder_peer_companies.founded_year),
        hq_city = COALESCE(EXCLUDED.hq_city, founder_peer_companies.hq_city),
        source_url = COALESCE(EXCLUDED.source_url, founder_peer_companies.source_url),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_peer_add',
          jsonb_build_object('peer_id', v_id, 'peer_name', p_peer_name, 'country', p_country));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_peer_add(text, text, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_peer_add(text, text, text, int, text, text) TO authenticated;

-- W2: log peer snapshot insert
DROP FUNCTION IF EXISTS log_founder_peer_snapshot(uuid, bigint, int, int, bigint, text, bigint, bigint, text, text, text);
CREATE OR REPLACE FUNCTION log_founder_peer_snapshot(
  p_peer_id uuid,
  p_gmv_rupees bigint DEFAULT NULL,
  p_hospital_count int DEFAULT NULL,
  p_engineer_count int DEFAULT NULL,
  p_monthly_revenue_rupees bigint DEFAULT NULL,
  p_fundraise_stage text DEFAULT NULL,
  p_total_raised_rupees bigint DEFAULT NULL,
  p_valuation_rupees bigint DEFAULT NULL,
  p_source_type text DEFAULT 'public',
  p_source_url text DEFAULT NULL,
  p_confidence text DEFAULT 'medium'
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_peer_metric_snapshots(
    peer_id, gmv_rupees, hospital_count, engineer_count, monthly_revenue_rupees,
    fundraise_stage, total_raised_rupees, valuation_rupees,
    source_type, source_url, confidence, recorded_by
  )
  VALUES (
    p_peer_id, p_gmv_rupees, p_hospital_count, p_engineer_count, p_monthly_revenue_rupees,
    p_fundraise_stage, p_total_raised_rupees, p_valuation_rupees,
    p_source_type, p_source_url, p_confidence, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_peer_snapshot',
          jsonb_build_object('snapshot_id', v_id, 'peer_id', p_peer_id, 'stage', p_fundraise_stage));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_peer_snapshot(uuid, bigint, int, int, bigint, text, bigint, bigint, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_peer_snapshot(uuid, bigint, int, int, bigint, text, bigint, bigint, text, text, text) TO authenticated;

-- W3: toggle tracking
DROP FUNCTION IF EXISTS log_founder_peer_set_tracking(uuid, boolean);
CREATE OR REPLACE FUNCTION log_founder_peer_set_tracking(p_peer_id uuid, p_tracked boolean)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_peer_companies SET is_tracked = p_tracked, updated_at = now() WHERE id = p_peer_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_peer_set_tracking',
          jsonb_build_object('peer_id', p_peer_id, 'is_tracked', p_tracked));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_peer_set_tracking(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_peer_set_tracking(uuid, boolean) TO authenticated;

-- W4: log benchmark review (audit trail when founder reviews dashboard)
DROP FUNCTION IF EXISTS log_founder_benchmark_review(text);
CREATE OR REPLACE FUNCTION log_founder_benchmark_review(p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_benchmark_review',
          jsonb_build_object('note', p_note, 'at', now()));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_benchmark_review(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_benchmark_review(text) TO authenticated;

COMMIT;