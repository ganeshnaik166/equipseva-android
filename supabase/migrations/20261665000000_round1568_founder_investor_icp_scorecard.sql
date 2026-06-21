BEGIN;

-- ============================================================
-- r1568 — Founder Investor ICP Scorecard
-- Score prospective investors against ideal customer profile
-- (stage fit, sector fit, geography fit, check size match)
-- to prioritize founder outreach.
-- ============================================================

-- ----- Tables ------------------------------------------------

CREATE TABLE IF NOT EXISTS founder_investor_icp_profiles_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  firm_name text,
  stage text NOT NULL CHECK (stage IN ('preseed','seed','seriesa','seriesb','growth','strategic')),
  sectors text[] NOT NULL DEFAULT ARRAY[]::text[],
  geographies text[] NOT NULL DEFAULT ARRAY[]::text[],
  min_check_inr bigint NOT NULL DEFAULT 0,
  max_check_inr bigint NOT NULL DEFAULT 0,
  recent_health_invest boolean NOT NULL DEFAULT false,
  warm_intro_available boolean NOT NULL DEFAULT false,
  partner_email text,
  notes text,
  added_at timestamptz NOT NULL DEFAULT now(),
  last_contacted_at timestamptz,
  status text NOT NULL DEFAULT 'prospect' CHECK (status IN ('prospect','contacted','meeting','diligence','pass','term_sheet','closed')),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE founder_investor_icp_profiles_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only icp profiles v2" ON founder_investor_icp_profiles_v2;
CREATE POLICY "founder only icp profiles v2"
  ON founder_investor_icp_profiles_v2
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_icp_profiles_v2_stage ON founder_investor_icp_profiles_v2(stage);
CREATE INDEX IF NOT EXISTS idx_icp_profiles_v2_status ON founder_investor_icp_profiles_v2(status);


CREATE TABLE IF NOT EXISTS founder_investor_icp_scores_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES founder_investor_icp_profiles_v2(id) ON DELETE CASCADE,
  stage_fit_score numeric(5,2) NOT NULL DEFAULT 0,
  sector_fit_score numeric(5,2) NOT NULL DEFAULT 0,
  geography_fit_score numeric(5,2) NOT NULL DEFAULT 0,
  check_size_score numeric(5,2) NOT NULL DEFAULT 0,
  warm_intro_bonus numeric(5,2) NOT NULL DEFAULT 0,
  composite_score numeric(5,2) NOT NULL DEFAULT 0,
  rank_position integer,
  scored_at timestamptz NOT NULL DEFAULT now(),
  scored_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE founder_investor_icp_scores_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only icp scores v2" ON founder_investor_icp_scores_v2;
CREATE POLICY "founder only icp scores v2"
  ON founder_investor_icp_scores_v2
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_icp_scores_v2_investor ON founder_investor_icp_scores_v2(investor_id);
CREATE INDEX IF NOT EXISTS idx_icp_scores_v2_composite ON founder_investor_icp_scores_v2(composite_score DESC);


-- ----- Logging helpers (VOLATILE SECDEF) ---------------------

CREATE OR REPLACE FUNCTION log_founder_icp_profile_added(
  p_investor_id uuid,
  p_investor_name text,
  p_stage text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'icp_profile_added',
    jsonb_build_object('investor_id', p_investor_id, 'investor_name', p_investor_name, 'stage', p_stage)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_icp_profile_added(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_icp_profile_added(uuid, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_icp_rescored(
  p_investor_id uuid,
  p_composite_score numeric
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'icp_rescored',
    jsonb_build_object('investor_id', p_investor_id, 'composite_score', p_composite_score)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_icp_rescored(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_icp_rescored(uuid, numeric) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_icp_status_changed(
  p_investor_id uuid,
  p_old_status text,
  p_new_status text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'icp_status_changed',
    jsonb_build_object('investor_id', p_investor_id, 'old_status', p_old_status, 'new_status', p_new_status)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_icp_status_changed(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_icp_status_changed(uuid, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_icp_bulk_rescore(
  p_count integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'icp_bulk_rescore',
    jsonb_build_object('count', p_count)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_icp_bulk_rescore(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_icp_bulk_rescore(integer) TO authenticated;


-- ----- Read RPCs (STABLE SECDEF) -----------------------------

CREATE OR REPLACE FUNCTION rpc_founder_icp_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total_profiles integer;
  v_scored_count integer;
  v_avg_score numeric;
  v_top_score numeric;
  v_high_fit_count integer;
  v_warm_intro_count integer;
  v_recent_health integer;
  v_meetings integer;
  v_in_diligence integer;
  v_term_sheets integer;
  v_passed integer;
  v_contacted_30d integer;
  v_stage_seed integer;
  v_stage_seriesa integer;
  v_target_check_match integer;
  v_uncontacted integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*) INTO v_total_profiles FROM founder_investor_icp_profiles_v2;
  SELECT count(DISTINCT investor_id) INTO v_scored_count FROM founder_investor_icp_scores_v2;
  SELECT COALESCE(round(avg(composite_score), 1), 0) INTO v_avg_score FROM founder_investor_icp_scores_v2;
  SELECT COALESCE(max(composite_score), 0) INTO v_top_score FROM founder_investor_icp_scores_v2;
  SELECT count(*) INTO v_high_fit_count FROM founder_investor_icp_scores_v2 WHERE composite_score >= 75;
  SELECT count(*) INTO v_warm_intro_count FROM founder_investor_icp_profiles_v2 WHERE warm_intro_available;
  SELECT count(*) INTO v_recent_health FROM founder_investor_icp_profiles_v2 WHERE recent_health_invest;
  SELECT count(*) INTO v_meetings FROM founder_investor_icp_profiles_v2 WHERE status = 'meeting';
  SELECT count(*) INTO v_in_diligence FROM founder_investor_icp_profiles_v2 WHERE status = 'diligence';
  SELECT count(*) INTO v_term_sheets FROM founder_investor_icp_profiles_v2 WHERE status = 'term_sheet';
  SELECT count(*) INTO v_passed FROM founder_investor_icp_profiles_v2 WHERE status = 'pass';
  SELECT count(*) INTO v_contacted_30d FROM founder_investor_icp_profiles_v2 WHERE last_contacted_at > (now() - interval '30 days');
  SELECT count(*) INTO v_stage_seed FROM founder_investor_icp_profiles_v2 WHERE stage = 'seed';
  SELECT count(*) INTO v_stage_seriesa FROM founder_investor_icp_profiles_v2 WHERE stage = 'seriesa';
  SELECT count(*) INTO v_target_check_match FROM founder_investor_icp_profiles_v2
    WHERE min_check_inr <= 50000000 AND max_check_inr >= 30000000;
  SELECT count(*) INTO v_uncontacted FROM founder_investor_icp_profiles_v2 WHERE last_contacted_at IS NULL;

  RETURN jsonb_build_object(
    'total_profiles', v_total_profiles,
    'scored_count', v_scored_count,
    'avg_score', v_avg_score,
    'top_score', v_top_score,
    'high_fit_count', v_high_fit_count,
    'warm_intro_count', v_warm_intro_count,
    'recent_health', v_recent_health,
    'meetings', v_meetings,
    'in_diligence', v_in_diligence,
    'term_sheets', v_term_sheets,
    'passed', v_passed,
    'contacted_30d', v_contacted_30d,
    'stage_seed', v_stage_seed,
    'stage_seriesa', v_stage_seriesa,
    'target_check_match', v_target_check_match,
    'uncontacted', v_uncontacted
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_kpis() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_icp_top_prospects(p_limit integer DEFAULT 25)
RETURNS TABLE (
  id uuid,
  investor_name text,
  firm_name text,
  stage text,
  composite_score numeric,
  status text,
  warm_intro boolean,
  partner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.investor_name,
    p.firm_name,
    p.stage,
    COALESCE(s.composite_score, 0)::numeric AS composite_score,
    p.status,
    p.warm_intro_available AS warm_intro,
    p.partner_email
  FROM founder_investor_icp_profiles_v2 p
  LEFT JOIN LATERAL (
    SELECT composite_score FROM founder_investor_icp_scores_v2 s2
    WHERE s2.investor_id = p.id
    ORDER BY s2.scored_at DESC
    LIMIT 1
  ) s ON true
  WHERE p.status NOT IN ('pass','closed')
  ORDER BY COALESCE(s.composite_score, 0) DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_top_prospects(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_top_prospects(integer) TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_icp_score_breakdown()
RETURNS TABLE (
  investor_id uuid,
  investor_name text,
  stage_fit_score numeric,
  sector_fit_score numeric,
  geography_fit_score numeric,
  check_size_score numeric,
  warm_intro_bonus numeric,
  composite_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id AS investor_id,
    p.investor_name,
    s.stage_fit_score,
    s.sector_fit_score,
    s.geography_fit_score,
    s.check_size_score,
    s.warm_intro_bonus,
    s.composite_score
  FROM founder_investor_icp_profiles_v2 p
  JOIN LATERAL (
    SELECT * FROM founder_investor_icp_scores_v2 s2
    WHERE s2.investor_id = p.id
    ORDER BY s2.scored_at DESC
    LIMIT 1
  ) s ON true
  ORDER BY s.composite_score DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_score_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_score_breakdown() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_icp_stage_distribution()
RETURNS TABLE (
  stage text,
  prospect_count integer,
  avg_score numeric,
  high_fit_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.stage,
    count(*)::integer AS prospect_count,
    COALESCE(round(avg(s.composite_score), 1), 0)::numeric AS avg_score,
    count(*) FILTER (WHERE s.composite_score >= 75)::integer AS high_fit_count
  FROM founder_investor_icp_profiles_v2 p
  LEFT JOIN LATERAL (
    SELECT composite_score FROM founder_investor_icp_scores_v2 s2
    WHERE s2.investor_id = p.id
    ORDER BY s2.scored_at DESC
    LIMIT 1
  ) s ON true
  GROUP BY p.stage
  ORDER BY prospect_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_stage_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_stage_distribution() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_icp_pipeline_status()
RETURNS TABLE (
  status text,
  count_at_stage integer,
  avg_fit_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.status,
    count(*)::integer AS count_at_stage,
    COALESCE(round(avg(s.composite_score), 1), 0)::numeric AS avg_fit_score
  FROM founder_investor_icp_profiles_v2 p
  LEFT JOIN LATERAL (
    SELECT composite_score FROM founder_investor_icp_scores_v2 s2
    WHERE s2.investor_id = p.id
    ORDER BY s2.scored_at DESC
    LIMIT 1
  ) s ON true
  GROUP BY p.status
  ORDER BY count_at_stage DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_pipeline_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_pipeline_status() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_icp_uncontacted_high_fit()
RETURNS TABLE (
  investor_id uuid,
  investor_name text,
  firm_name text,
  composite_score numeric,
  warm_intro boolean,
  partner_email text,
  added_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id AS investor_id,
    p.investor_name,
    p.firm_name,
    COALESCE(s.composite_score, 0)::numeric AS composite_score,
    p.warm_intro_available AS warm_intro,
    p.partner_email,
    p.added_at
  FROM founder_investor_icp_profiles_v2 p
  LEFT JOIN LATERAL (
    SELECT composite_score FROM founder_investor_icp_scores_v2 s2
    WHERE s2.investor_id = p.id
    ORDER BY s2.scored_at DESC
    LIMIT 1
  ) s ON true
  WHERE p.last_contacted_at IS NULL
    AND COALESCE(s.composite_score, 0) >= 65
  ORDER BY s.composite_score DESC NULLS LAST
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_uncontacted_high_fit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_uncontacted_high_fit() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_icp_recent_activity()
RETURNS TABLE (
  investor_id uuid,
  investor_name text,
  status text,
  last_contacted_at timestamptz,
  days_since_contact numeric,
  composite_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id AS investor_id,
    p.investor_name,
    p.status,
    p.last_contacted_at,
    CASE
      WHEN p.last_contacted_at IS NULL THEN NULL
      ELSE round((EXTRACT(EPOCH FROM (now() - p.last_contacted_at)) / 86400.0)::numeric, 1)
    END AS days_since_contact,
    COALESCE(s.composite_score, 0)::numeric AS composite_score
  FROM founder_investor_icp_profiles_v2 p
  LEFT JOIN LATERAL (
    SELECT composite_score FROM founder_investor_icp_scores_v2 s2
    WHERE s2.investor_id = p.id
    ORDER BY s2.scored_at DESC
    LIMIT 1
  ) s ON true
  WHERE p.last_contacted_at IS NOT NULL
  ORDER BY p.last_contacted_at DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_recent_activity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_recent_activity() TO authenticated;


-- ----- Write RPC (VOLATILE SECDEF) ---------------------------

CREATE OR REPLACE FUNCTION rpc_founder_icp_rescore_all()
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
  r record;
  v_stage_fit numeric;
  v_sector_fit numeric;
  v_geo_fit numeric;
  v_check_fit numeric;
  v_warm_bonus numeric;
  v_composite numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  FOR r IN SELECT * FROM founder_investor_icp_profiles_v2 LOOP
    v_stage_fit := CASE WHEN r.stage IN ('seed','seriesa') THEN 25 WHEN r.stage = 'preseed' THEN 15 ELSE 8 END;
    v_sector_fit := CASE
      WHEN 'healthtech' = ANY(r.sectors) OR 'medtech' = ANY(r.sectors) THEN 25
      WHEN 'b2b_saas' = ANY(r.sectors) OR 'enterprise' = ANY(r.sectors) THEN 15
      ELSE 5
    END;
    v_geo_fit := CASE
      WHEN 'india' = ANY(r.geographies) THEN 20
      WHEN 'apac' = ANY(r.geographies) OR 'global' = ANY(r.geographies) THEN 12
      ELSE 4
    END;
    v_check_fit := CASE
      WHEN r.min_check_inr <= 50000000 AND r.max_check_inr >= 30000000 THEN 20
      WHEN r.max_check_inr >= 20000000 THEN 12
      ELSE 5
    END;
    v_warm_bonus := CASE
      WHEN r.warm_intro_available AND r.recent_health_invest THEN 10
      WHEN r.warm_intro_available OR r.recent_health_invest THEN 5
      ELSE 0
    END;
    v_composite := v_stage_fit + v_sector_fit + v_geo_fit + v_check_fit + v_warm_bonus;

    INSERT INTO founder_investor_icp_scores_v2 (
      investor_id, stage_fit_score, sector_fit_score, geography_fit_score,
      check_size_score, warm_intro_bonus, composite_score, scored_by
    )
    VALUES (
      r.id, v_stage_fit, v_sector_fit, v_geo_fit,
      v_check_fit, v_warm_bonus, v_composite, auth.uid()
    );
    v_count := v_count + 1;
  END LOOP;

  PERFORM log_founder_icp_bulk_rescore(v_count);

  RETURN jsonb_build_object('rescored', v_count);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_icp_rescore_all() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_icp_rescore_all() TO authenticated;

COMMIT;