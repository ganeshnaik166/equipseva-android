BEGIN;

-- Round 1620 — Founder Hospital Portfolio ARR Cumulative
-- Total ARR across active AMC contracts, per-tier ARR, growth rate,
-- churn-adjusted forecast, founder weekly review.

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_arr_snapshots_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  total_active_contracts integer NOT NULL DEFAULT 0,
  total_arr_rupees numeric(18,2) NOT NULL DEFAULT 0,
  tier_breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_arr_snapshots_v2_date
  ON founder_arr_snapshots_v2(snapshot_date DESC);

ALTER TABLE founder_arr_snapshots_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_arr_snapshots_v2_founder_all ON founder_arr_snapshots_v2;
CREATE POLICY founder_arr_snapshots_v2_founder_all
  ON founder_arr_snapshots_v2 FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_arr_weekly_reviews_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  arr_opening_rupees numeric(18,2) NOT NULL DEFAULT 0,
  arr_closing_rupees numeric(18,2) NOT NULL DEFAULT 0,
  new_contracts integer NOT NULL DEFAULT 0,
  churned_contracts integer NOT NULL DEFAULT 0,
  review_notes text,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(week_start)
);

CREATE INDEX IF NOT EXISTS idx_founder_arr_weekly_reviews_v2_week
  ON founder_arr_weekly_reviews_v2(week_start DESC);

ALTER TABLE founder_arr_weekly_reviews_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_arr_weekly_reviews_v2_founder_all ON founder_arr_weekly_reviews_v2;
CREATE POLICY founder_arr_weekly_reviews_v2_founder_all
  ON founder_arr_weekly_reviews_v2 FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_arr_portfolio_summary()
RETURNS TABLE (
  total_active_contracts bigint,
  total_arr_rupees numeric,
  avg_contract_rupees numeric,
  contracts_started_30d bigint,
  contracts_started_90d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT id, monthly_fee_rupees, created_at
    FROM amc_contracts
    WHERE status = 'active'
  )
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(monthly_fee_rupees * 12), 0)::numeric,
    COALESCE(AVG(monthly_fee_rupees * 12), 0)::numeric,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::bigint,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '90 days')::bigint
  FROM active;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arr_portfolio_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arr_portfolio_summary() TO authenticated;


CREATE OR REPLACE FUNCTION founder_arr_by_tier()
RETURNS TABLE (
  amc_tier text,
  contract_count bigint,
  tier_arr_rupees numeric,
  avg_monthly_fee numeric,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT amc_tier, monthly_fee_rupees
    FROM amc_contracts
    WHERE status = 'active'
  ),
  totals AS (
    SELECT COALESCE(SUM(monthly_fee_rupees * 12), 0)::numeric AS total_arr
    FROM active
  )
  SELECT
    a.amc_tier::text,
    COUNT(*)::bigint,
    COALESCE(SUM(a.monthly_fee_rupees * 12), 0)::numeric,
    COALESCE(AVG(a.monthly_fee_rupees), 0)::numeric,
    CASE WHEN t.total_arr > 0
      THEN ROUND((SUM(a.monthly_fee_rupees * 12) / t.total_arr) * 100, 2)
      ELSE 0 END::numeric
  FROM active a
  CROSS JOIN totals t
  GROUP BY a.amc_tier, t.total_arr
  ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arr_by_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arr_by_tier() TO authenticated;


CREATE OR REPLACE FUNCTION founder_arr_growth_rate()
RETURNS TABLE (
  period_label text,
  contracts_added bigint,
  arr_added_rupees numeric,
  growth_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT COALESCE(SUM(monthly_fee_rupees * 12), 0)::numeric AS base_arr
    FROM amc_contracts
    WHERE status = 'active' AND created_at < now() - interval '90 days'
  ),
  buckets AS (
    SELECT '0-30d' AS period_label,
      COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::bigint AS cnt,
      COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE created_at >= now() - interval '30 days'), 0)::numeric AS arr
    FROM amc_contracts WHERE status = 'active'
    UNION ALL
    SELECT '31-60d',
      COUNT(*) FILTER (WHERE created_at >= now() - interval '60 days' AND created_at < now() - interval '30 days')::bigint,
      COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE created_at >= now() - interval '60 days' AND created_at < now() - interval '30 days'), 0)::numeric
    FROM amc_contracts WHERE status = 'active'
    UNION ALL
    SELECT '61-90d',
      COUNT(*) FILTER (WHERE created_at >= now() - interval '90 days' AND created_at < now() - interval '60 days')::bigint,
      COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE created_at >= now() - interval '90 days' AND created_at < now() - interval '60 days'), 0)::numeric
    FROM amc_contracts WHERE status = 'active'
  )
  SELECT b.period_label, b.cnt, b.arr,
    CASE WHEN base.base_arr > 0 THEN ROUND((b.arr / base.base_arr) * 100, 2) ELSE 0 END::numeric
  FROM buckets b CROSS JOIN base
  ORDER BY b.period_label;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arr_growth_rate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arr_growth_rate() TO authenticated;


CREATE OR REPLACE FUNCTION founder_arr_churn_forecast()
RETURNS TABLE (
  active_arr_rupees numeric,
  churned_last_90d bigint,
  churn_rate_pct numeric,
  forecast_arr_12mo_rupees numeric,
  forecast_arr_loss_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_active_arr numeric;
  v_churn_count bigint;
  v_active_count bigint;
  v_churn_rate numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees * 12), 0)::numeric, COUNT(*)::bigint
    INTO v_active_arr, v_active_count
  FROM amc_contracts WHERE status = 'active';

  SELECT COUNT(*)::bigint INTO v_churn_count
  FROM amc_contracts
  WHERE status IN ('cancelled','expired','terminated')
    AND updated_at >= now() - interval '90 days';

  v_churn_rate := CASE WHEN (v_active_count + v_churn_count) > 0
    THEN ROUND((v_churn_count::numeric / (v_active_count + v_churn_count)) * 100, 2)
    ELSE 0 END;

  RETURN QUERY SELECT
    v_active_arr,
    v_churn_count,
    v_churn_rate,
    ROUND(v_active_arr * (1 - (v_churn_rate / 100) * 4), 2),
    ROUND(v_active_arr * (v_churn_rate / 100) * 4, 2);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arr_churn_forecast() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arr_churn_forecast() TO authenticated;


CREATE OR REPLACE FUNCTION founder_arr_top_hospitals(p_limit integer DEFAULT 20)
RETURNS TABLE (
  contract_id uuid,
  hospital_user_id uuid,
  hospital_org_name text,
  amc_tier text,
  monthly_fee_rupees numeric,
  annual_arr_rupees numeric,
  contract_started_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH c AS (
    SELECT ac.id, ac.hospital_user_id, ac.amc_tier::text AS tier_txt,
           ac.monthly_fee_rupees, ac.created_at
    FROM amc_contracts ac
    WHERE ac.status = 'active'
  )
  SELECT c.id, c.hospital_user_id,
    COALESCE(o.name, 'Unknown'),
    c.tier_txt,
    c.monthly_fee_rupees::numeric,
    (c.monthly_fee_rupees * 12)::numeric,
    c.created_at
  FROM c
  LEFT JOIN profiles p ON p.id = c.hospital_user_id
  LEFT JOIN organizations o ON o.id = p.organization_id
  ORDER BY c.monthly_fee_rupees DESC NULLS LAST
  LIMIT GREATEST(COALESCE(p_limit, 20), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arr_top_hospitals(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arr_top_hospitals(integer) TO authenticated;


CREATE OR REPLACE FUNCTION founder_arr_recent_snapshots(p_limit integer DEFAULT 12)
RETURNS TABLE (
  id uuid,
  snapshot_date date,
  total_active_contracts integer,
  total_arr_rupees numeric,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.snapshot_date, s.total_active_contracts,
         s.total_arr_rupees, s.notes, s.created_at
  FROM founder_arr_snapshots_v2 s
  ORDER BY s.snapshot_date DESC, s.created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 12), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arr_recent_snapshots(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arr_recent_snapshots(integer) TO authenticated;


CREATE OR REPLACE FUNCTION founder_arr_recent_weekly_reviews(p_limit integer DEFAULT 12)
RETURNS TABLE (
  id uuid,
  week_start date,
  arr_opening_rupees numeric,
  arr_closing_rupees numeric,
  new_contracts integer,
  churned_contracts integer,
  review_notes text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.week_start, r.arr_opening_rupees, r.arr_closing_rupees,
         r.new_contracts, r.churned_contracts, r.review_notes, r.reviewed_at
  FROM founder_arr_weekly_reviews_v2 r
  ORDER BY r.week_start DESC
  LIMIT GREATEST(COALESCE(p_limit, 12), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arr_recent_weekly_reviews(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arr_recent_weekly_reviews(integer) TO authenticated;


-- ============================================================
-- WRITE RPCs (VOLATILE) — log_founder_*
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_arr_snapshot(
  p_total_active_contracts integer,
  p_total_arr_rupees numeric,
  p_tier_breakdown jsonb,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_arr_snapshots_v2 (
    total_active_contracts, total_arr_rupees, tier_breakdown, notes, created_by
  ) VALUES (
    COALESCE(p_total_active_contracts, 0),
    COALESCE(p_total_arr_rupees, 0),
    COALESCE(p_tier_breakdown, '{}'::jsonb),
    p_notes,
    auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_arr_snapshot',
          jsonb_build_object('id', v_id, 'total_arr_rupees', p_total_arr_rupees),
          now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_arr_snapshot(integer, numeric, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_arr_snapshot(integer, numeric, jsonb, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_arr_weekly_review(
  p_week_start date,
  p_arr_opening_rupees numeric,
  p_arr_closing_rupees numeric,
  p_new_contracts integer,
  p_churned_contracts integer,
  p_review_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_arr_weekly_reviews_v2 (
    week_start, arr_opening_rupees, arr_closing_rupees,
    new_contracts, churned_contracts, review_notes, reviewed_by
  ) VALUES (
    p_week_start,
    COALESCE(p_arr_opening_rupees, 0),
    COALESCE(p_arr_closing_rupees, 0),
    COALESCE(p_new_contracts, 0),
    COALESCE(p_churned_contracts, 0),
    p_review_notes,
    auth.uid()
  )
  ON CONFLICT (week_start) DO UPDATE SET
    arr_opening_rupees = EXCLUDED.arr_opening_rupees,
    arr_closing_rupees = EXCLUDED.arr_closing_rupees,
    new_contracts = EXCLUDED.new_contracts,
    churned_contracts = EXCLUDED.churned_contracts,
    review_notes = EXCLUDED.review_notes,
    reviewed_by = auth.uid(),
    reviewed_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_arr_weekly_review',
          jsonb_build_object('id', v_id, 'week_start', p_week_start,
                             'arr_closing_rupees', p_arr_closing_rupees),
          now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_arr_weekly_review(date, numeric, numeric, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_arr_weekly_review(date, numeric, numeric, integer, integer, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_arr_review_note(
  p_review_id uuid,
  p_review_notes text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_arr_weekly_reviews_v2
    SET review_notes = p_review_notes,
        reviewed_by = auth.uid(),
        reviewed_at = now()
  WHERE id = p_review_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_arr_review_note',
          jsonb_build_object('review_id', p_review_id), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_arr_review_note(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_arr_review_note(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_arr_snapshot_note(
  p_snapshot_id uuid,
  p_notes text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_arr_snapshots_v2
    SET notes = p_notes
  WHERE id = p_snapshot_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_arr_snapshot_note',
          jsonb_build_object('snapshot_id', p_snapshot_id), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_arr_snapshot_note(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_arr_snapshot_note(uuid, text) TO authenticated;

COMMIT;