BEGIN;

-- =====================================================================
-- Round 1538 — Founder Hospital Lifetime-Value Ladder
-- Compute cumulative + projected LTV; rank; VIP-tier promotion list
-- =====================================================================

-- ---------- Tables ----------
CREATE TABLE IF NOT EXISTS founder_hospital_ltv_snapshots_v2 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id  uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  computed_at      timestamptz NOT NULL DEFAULT now(),
  cumulative_rev_rupees     bigint NOT NULL DEFAULT 0,
  projected_next_12m_rupees bigint NOT NULL DEFAULT 0,
  retention_prob   numeric(5,4) NOT NULL DEFAULT 0.0,
  ltv_rupees       bigint NOT NULL DEFAULT 0,
  rank_position    int,
  notes            text
);
CREATE INDEX IF NOT EXISTS idx_ltv_snap_v2_org ON founder_hospital_ltv_snapshots_v2(hospital_org_id, computed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ltv_snap_v2_rank ON founder_hospital_ltv_snapshots_v2(rank_position) WHERE rank_position IS NOT NULL;

ALTER TABLE founder_hospital_ltv_snapshots_v2 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_ltv_snap_v2 ON founder_hospital_ltv_snapshots_v2;
CREATE POLICY founder_only_ltv_snap_v2 ON founder_hospital_ltv_snapshots_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_hospital_vip_promotions_v2 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id  uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  promoted_at      timestamptz NOT NULL DEFAULT now(),
  promoted_to_tier text NOT NULL CHECK (promoted_to_tier IN ('vip_gold','vip_platinum','vip_diamond')),
  rationale        text,
  promoted_by      uuid REFERENCES auth.users(id)
);
CREATE INDEX IF NOT EXISTS idx_vip_promo_v2_org ON founder_hospital_vip_promotions_v2(hospital_org_id, promoted_at DESC);

ALTER TABLE founder_hospital_vip_promotions_v2 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_vip_promo_v2 ON founder_hospital_vip_promotions_v2;
CREATE POLICY founder_only_vip_promo_v2 ON founder_hospital_vip_promotions_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- log helpers ----------
CREATE OR REPLACE FUNCTION log_founder_ltv_snapshot_action(p_hospital uuid, p_ltv bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ltv_snapshot',
          jsonb_build_object('hospital_org_id', p_hospital, 'ltv', p_ltv));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_ltv_snapshot_action(uuid,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ltv_snapshot_action(uuid,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ltv_promotion_action(p_hospital uuid, p_tier text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ltv_vip_promote',
          jsonb_build_object('hospital_org_id', p_hospital, 'tier', p_tier));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_ltv_promotion_action(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ltv_promotion_action(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ltv_recompute_action(p_count int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ltv_recompute',
          jsonb_build_object('hospitals_scored', p_count));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_ltv_recompute_action(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ltv_recompute_action(int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ltv_export_action(p_rows int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ltv_export',
          jsonb_build_object('rows', p_rows));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_ltv_export_action(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ltv_export_action(int) TO authenticated;

-- ---------- 7 SECDEF RPCs ----------

-- 1. Headline KPIs
CREATE OR REPLACE FUNCTION founder_ltv_headline()
RETURNS TABLE(
  total_hospitals bigint,
  scored_hospitals bigint,
  vip_count bigint,
  total_ltv_rupees bigint,
  median_ltv_rupees bigint,
  top_decile_ltv_rupees bigint,
  avg_retention numeric,
  projected_12m_rupees bigint,
  cumulative_rev_rupees bigint,
  active_hospitals_90d bigint,
  churned_hospitals bigint,
  ladder_p50_rupees bigint,
  ladder_p90_rupees bigint,
  ladder_p99_rupees bigint,
  last_recompute_at timestamptz,
  hospitals_with_amc bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM founder_hospital_ltv_snapshots_v2
    ORDER BY hospital_org_id, computed_at DESC
  )
  SELECT
    (SELECT count(*) FROM organizations WHERE org_type = 'hospital')::bigint,
    (SELECT count(*) FROM latest)::bigint,
    (SELECT count(DISTINCT hospital_org_id) FROM founder_hospital_vip_promotions_v2)::bigint,
    COALESCE((SELECT sum(ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT avg(retention_prob) FROM latest), 0)::numeric,
    COALESCE((SELECT sum(projected_next_12m_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT sum(cumulative_rev_rupees) FROM latest), 0)::bigint,
    (SELECT count(DISTINCT hospital_org_id) FROM repair_jobs
      WHERE created_at >= now() - interval '90 days')::bigint,
    (SELECT count(*) FROM latest WHERE retention_prob < 0.20)::bigint,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    (SELECT max(computed_at) FROM founder_hospital_ltv_snapshots_v2),
    (SELECT count(DISTINCT p.organization_id)
       FROM amc_contracts a
       JOIN profiles p ON p.id = a.hospital_user_id
      WHERE a.status = 'active')::bigint;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_ltv_headline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ltv_headline() TO authenticated;

-- 2. Ladder ranked
CREATE OR REPLACE FUNCTION founder_ltv_ladder()
RETURNS TABLE(
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  cumulative_rev_rupees bigint,
  projected_next_12m_rupees bigint,
  retention_prob numeric,
  ltv_rupees bigint,
  rank_position int,
  computed_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.hospital_org_id) s.*
    FROM founder_hospital_ltv_snapshots_v2 s
    ORDER BY s.hospital_org_id, s.computed_at DESC
  )
  SELECT l.id, l.hospital_org_id, o.name,
         l.cumulative_rev_rupees, l.projected_next_12m_rupees,
         l.retention_prob, l.ltv_rupees, l.rank_position, l.computed_at
  FROM latest l
  JOIN organizations o ON o.id = l.hospital_org_id
  ORDER BY l.ltv_rupees DESC NULLS LAST
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_ltv_ladder() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ltv_ladder() TO authenticated;

-- 3. VIP promotions list
CREATE OR REPLACE FUNCTION founder_ltv_vip_list()
RETURNS TABLE(
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  promoted_to_tier text,
  promoted_at timestamptz,
  rationale text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_org_id, o.name, v.promoted_to_tier, v.promoted_at, v.rationale
  FROM founder_hospital_vip_promotions_v2 v
  JOIN organizations o ON o.id = v.hospital_org_id
  ORDER BY v.promoted_at DESC
  LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_ltv_vip_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ltv_vip_list() TO authenticated;

-- 4. Retention buckets
CREATE OR REPLACE FUNCTION founder_ltv_retention_buckets()
RETURNS TABLE(
  bucket text,
  hospital_count bigint,
  avg_ltv_rupees bigint,
  sum_ltv_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM founder_hospital_ltv_snapshots_v2
    ORDER BY hospital_org_id, computed_at DESC
  ), bucketed AS (
    SELECT CASE
      WHEN retention_prob >= 0.80 THEN 'champion'
      WHEN retention_prob >= 0.50 THEN 'loyal'
      WHEN retention_prob >= 0.20 THEN 'at_risk'
      ELSE 'churning'
    END AS b, ltv_rupees
    FROM latest
  )
  SELECT b, count(*)::bigint, COALESCE(avg(ltv_rupees),0)::bigint, COALESCE(sum(ltv_rupees),0)::bigint
  FROM bucketed GROUP BY b ORDER BY b;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_ltv_retention_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ltv_retention_buckets() TO authenticated;

-- 5. Top movers (delta from prior snapshot)
CREATE OR REPLACE FUNCTION founder_ltv_top_movers()
RETURNS TABLE(
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  current_ltv bigint,
  prior_ltv bigint,
  delta_ltv bigint,
  delta_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ranked AS (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY hospital_org_id ORDER BY computed_at DESC) rn
    FROM founder_hospital_ltv_snapshots_v2 s
  ), cur AS (SELECT * FROM ranked WHERE rn = 1),
  prv AS (SELECT * FROM ranked WHERE rn = 2)
  SELECT cur.id, cur.hospital_org_id, o.name,
         cur.ltv_rupees,
         COALESCE(prv.ltv_rupees, 0),
         (cur.ltv_rupees - COALESCE(prv.ltv_rupees, 0))::bigint,
         CASE WHEN COALESCE(prv.ltv_rupees,0) = 0 THEN 0
              ELSE ROUND(((cur.ltv_rupees - prv.ltv_rupees)::numeric / prv.ltv_rupees) * 100, 2)
         END
  FROM cur
  LEFT JOIN prv ON prv.hospital_org_id = cur.hospital_org_id
  JOIN organizations o ON o.id = cur.hospital_org_id
  ORDER BY (cur.ltv_rupees - COALESCE(prv.ltv_rupees, 0)) DESC
  LIMIT 50;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_ltv_top_movers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ltv_top_movers() TO authenticated;

-- 6. Recompute snapshots (VOLATILE write)
CREATE OR REPLACE FUNCTION founder_ltv_recompute()
RETURNS int LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH per_hosp AS (
    SELECT rj.hospital_org_id AS org_id,
           COALESCE(sum(rj.contracted_amount_rupees), 0)::bigint AS cum_rev,
           count(*)::int AS jobs,
           max(rj.created_at) AS last_job
    FROM repair_jobs rj
    WHERE rj.hospital_org_id IS NOT NULL
    GROUP BY rj.hospital_org_id
  ), scored AS (
    SELECT p.org_id,
           p.cum_rev,
           CASE
             WHEN p.last_job IS NULL THEN 0.10
             WHEN p.last_job >= now() - interval '30 days' THEN 0.90
             WHEN p.last_job >= now() - interval '90 days' THEN 0.65
             WHEN p.last_job >= now() - interval '180 days' THEN 0.35
             ELSE 0.10
           END AS retention,
           (p.cum_rev / GREATEST(p.jobs, 1)) * 4 AS proj12
    FROM per_hosp p
  ), final AS (
    SELECT org_id, cum_rev, retention,
           proj12::bigint AS proj12,
           (cum_rev + (proj12 * retention)::bigint) AS ltv
    FROM scored
  ), ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY ltv DESC) AS rnk FROM final
  )
  INSERT INTO founder_hospital_ltv_snapshots_v2
    (hospital_org_id, cumulative_rev_rupees, projected_next_12m_rupees, retention_prob, ltv_rupees, rank_position)
  SELECT org_id, cum_rev, proj12, retention, ltv, rnk::int FROM ranked;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM log_founder_ltv_recompute_action(v_count);
  RETURN v_count;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_ltv_recompute() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ltv_recompute() TO authenticated;

-- 7. Promote to VIP (VOLATILE write)
CREATE OR REPLACE FUNCTION founder_ltv_promote_vip(p_hospital uuid, p_tier text, p_rationale text)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_tier NOT IN ('vip_gold','vip_platinum','vip_diamond') THEN
    RAISE EXCEPTION 'invalid_tier';
  END IF;
  INSERT INTO founder_hospital_vip_promotions_v2(hospital_org_id, promoted_to_tier, rationale, promoted_by)
  VALUES (p_hospital, p_tier, p_rationale, auth.uid())
  RETURNING id INTO v_id;
  PERFORM log_founder_ltv_promotion_action(p_hospital, p_tier);
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_ltv_promote_vip(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ltv_promote_vip(uuid,text,text) TO authenticated;

COMMIT;