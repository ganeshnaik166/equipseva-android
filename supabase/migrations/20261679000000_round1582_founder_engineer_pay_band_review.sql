BEGIN;

-- Round 1582 — Founder Engineer Pay-Band Review
-- Per-tier quarterly pay-band review, market benchmark vs our pay,
-- founder-approved adjustments.

CREATE TABLE IF NOT EXISTS founder_pay_band_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_quarter text NOT NULL,                       -- e.g. '2026-Q3'
  tier text NOT NULL CHECK (tier IN ('pro','bgc','gst','pan','aadhaar','none')),
  current_floor_rupees integer NOT NULL CHECK (current_floor_rupees >= 0),
  current_ceiling_rupees integer NOT NULL CHECK (current_ceiling_rupees >= 0),
  market_floor_rupees integer NOT NULL CHECK (market_floor_rupees >= 0),
  market_ceiling_rupees integer NOT NULL CHECK (market_ceiling_rupees >= 0),
  market_source text,
  recommended_floor_rupees integer NOT NULL CHECK (recommended_floor_rupees >= 0),
  recommended_ceiling_rupees integer NOT NULL CHECK (recommended_ceiling_rupees >= 0),
  variance_pct numeric(6,2),                          -- (market - ours)/ours * 100
  rationale text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','deferred')),
  approved_floor_rupees integer,
  approved_ceiling_rupees integer,
  decided_by uuid REFERENCES auth.users(id),
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  UNIQUE (review_quarter, tier)
);

CREATE INDEX IF NOT EXISTS idx_pay_band_reviews_quarter ON founder_pay_band_reviews(review_quarter);
CREATE INDEX IF NOT EXISTS idx_pay_band_reviews_status  ON founder_pay_band_reviews(status);
CREATE INDEX IF NOT EXISTS idx_pay_band_reviews_tier    ON founder_pay_band_reviews(tier);

ALTER TABLE founder_pay_band_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pay_band_reviews_founder_only ON founder_pay_band_reviews;
CREATE POLICY pay_band_reviews_founder_only
  ON founder_pay_band_reviews
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_pay_band_raise_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES founder_pay_band_reviews(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier IN ('pro','bgc','gst','pan','aadhaar','none')),
  old_rate_rupees integer NOT NULL CHECK (old_rate_rupees >= 0),
  new_rate_rupees integer NOT NULL CHECK (new_rate_rupees >= 0),
  effective_from date NOT NULL,
  granted_by uuid REFERENCES auth.users(id),
  granted_at timestamptz NOT NULL DEFAULT now(),
  note text
);

CREATE INDEX IF NOT EXISTS idx_pay_band_raise_grants_review   ON founder_pay_band_raise_grants(review_id);
CREATE INDEX IF NOT EXISTS idx_pay_band_raise_grants_engineer ON founder_pay_band_raise_grants(engineer_id);
CREATE INDEX IF NOT EXISTS idx_pay_band_raise_grants_eff      ON founder_pay_band_raise_grants(effective_from);

ALTER TABLE founder_pay_band_raise_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pay_band_raise_grants_founder_only ON founder_pay_band_raise_grants;
CREATE POLICY pay_band_raise_grants_founder_only
  ON founder_pay_band_raise_grants
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- ============================================================
-- log_founder_* helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_pay_band_review_created(
  p_review_id uuid,
  p_quarter text,
  p_tier text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'pay_band_review_created',
    jsonb_build_object('review_id', p_review_id, 'quarter', p_quarter, 'tier', p_tier)
  );
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pay_band_review_created(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pay_band_review_created(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pay_band_review_decided(
  p_review_id uuid,
  p_status text,
  p_floor integer,
  p_ceiling integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'pay_band_review_decided',
    jsonb_build_object('review_id', p_review_id, 'status', p_status, 'floor', p_floor, 'ceiling', p_ceiling)
  );
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pay_band_review_decided(uuid, text, integer, integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pay_band_review_decided(uuid, text, integer, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pay_band_raise_granted(
  p_grant_id uuid,
  p_engineer_id uuid,
  p_old integer,
  p_new integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'pay_band_raise_granted',
    jsonb_build_object('grant_id', p_grant_id, 'engineer_id', p_engineer_id, 'old', p_old, 'new', p_new)
  );
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pay_band_raise_granted(uuid, uuid, integer, integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pay_band_raise_granted(uuid, uuid, integer, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pay_band_view(
  p_view text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'pay_band_view',
    jsonb_build_object('view', p_view, 'ts', now())
  );
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pay_band_view(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pay_band_view(text) TO authenticated;


-- ============================================================
-- Read RPCs (STABLE SECDEF, founder-gated)
-- ============================================================

-- 1) KPI summary
CREATE OR REPLACE FUNCTION founder_pay_band_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT jsonb_build_object(
    'total_reviews',           (SELECT count(*) FROM founder_pay_band_reviews),
    'pending_reviews',         (SELECT count(*) FROM founder_pay_band_reviews WHERE status='pending'),
    'approved_reviews',        (SELECT count(*) FROM founder_pay_band_reviews WHERE status='approved'),
    'rejected_reviews',        (SELECT count(*) FROM founder_pay_band_reviews WHERE status='rejected'),
    'deferred_reviews',        (SELECT count(*) FROM founder_pay_band_reviews WHERE status='deferred'),
    'current_quarter',         to_char(now(),'YYYY') || '-Q' || to_char(extract(quarter from now())::int, 'FM9'),
    'tiers_under_review',      (SELECT count(DISTINCT tier) FROM founder_pay_band_reviews WHERE status='pending'),
    'avg_variance_pct',        COALESCE((SELECT round(avg(variance_pct)::numeric,2) FROM founder_pay_band_reviews), 0),
    'max_variance_pct',        COALESCE((SELECT max(variance_pct) FROM founder_pay_band_reviews), 0),
    'min_variance_pct',        COALESCE((SELECT min(variance_pct) FROM founder_pay_band_reviews), 0),
    'total_raises_granted',    (SELECT count(*) FROM founder_pay_band_raise_grants),
    'raises_this_quarter',     (SELECT count(*) FROM founder_pay_band_raise_grants WHERE granted_at > date_trunc('quarter', now())),
    'avg_raise_rupees',        COALESCE((SELECT round(avg(new_rate_rupees - old_rate_rupees)) FROM founder_pay_band_raise_grants), 0),
    'total_raise_spend_rupees',COALESCE((SELECT sum(new_rate_rupees - old_rate_rupees) FROM founder_pay_band_raise_grants), 0),
    'engineers_with_raise',    (SELECT count(DISTINCT engineer_id) FROM founder_pay_band_raise_grants),
    'total_engineers',         (SELECT count(*) FROM engineers)
  )
  INTO v;

  RETURN v;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pay_band_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pay_band_kpis() TO authenticated;

-- 2) Current quarter reviews
CREATE OR REPLACE FUNCTION founder_pay_band_current_reviews()
RETURNS TABLE(
  id uuid,
  review_quarter text,
  tier text,
  current_floor_rupees integer,
  current_ceiling_rupees integer,
  market_floor_rupees integer,
  market_ceiling_rupees integer,
  recommended_floor_rupees integer,
  recommended_ceiling_rupees integer,
  variance_pct numeric,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.review_quarter, r.tier,
         r.current_floor_rupees, r.current_ceiling_rupees,
         r.market_floor_rupees, r.market_ceiling_rupees,
         r.recommended_floor_rupees, r.recommended_ceiling_rupees,
         r.variance_pct, r.status, r.created_at
  FROM founder_pay_band_reviews r
  ORDER BY r.created_at DESC
  LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pay_band_current_reviews() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pay_band_current_reviews() TO authenticated;

-- 3) Tier benchmark snapshot
CREATE OR REPLACE FUNCTION founder_pay_band_tier_benchmark()
RETURNS TABLE(
  tier text,
  engineers_count bigint,
  current_floor_rupees integer,
  current_ceiling_rupees integer,
  market_floor_rupees integer,
  market_ceiling_rupees integer,
  variance_pct numeric,
  last_reviewed timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (r.tier) r.tier, r.current_floor_rupees, r.current_ceiling_rupees,
           r.market_floor_rupees, r.market_ceiling_rupees, r.variance_pct, r.created_at
    FROM founder_pay_band_reviews r
    ORDER BY r.tier, r.created_at DESC
  )
  SELECT l.tier,
         (SELECT count(*) FROM engineers e WHERE e.cached_highest_tier = l.tier),
         l.current_floor_rupees, l.current_ceiling_rupees,
         l.market_floor_rupees, l.market_ceiling_rupees,
         l.variance_pct, l.created_at
  FROM latest l
  ORDER BY l.tier;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pay_band_tier_benchmark() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pay_band_tier_benchmark() TO authenticated;

-- 4) Recent raise grants
CREATE OR REPLACE FUNCTION founder_pay_band_recent_grants()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  tier text,
  old_rate_rupees integer,
  new_rate_rupees integer,
  delta_rupees integer,
  effective_from date,
  granted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.engineer_id, g.tier,
         g.old_rate_rupees, g.new_rate_rupees,
         (g.new_rate_rupees - g.old_rate_rupees) AS delta_rupees,
         g.effective_from, g.granted_at
  FROM founder_pay_band_raise_grants g
  ORDER BY g.granted_at DESC
  LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pay_band_recent_grants() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pay_band_recent_grants() TO authenticated;

-- 5) Pending review queue (decision needed)
CREATE OR REPLACE FUNCTION founder_pay_band_pending_queue()
RETURNS TABLE(
  id uuid,
  review_quarter text,
  tier text,
  variance_pct numeric,
  recommended_floor_rupees integer,
  recommended_ceiling_rupees integer,
  rationale text,
  created_at timestamptz,
  age_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.review_quarter, r.tier, r.variance_pct,
         r.recommended_floor_rupees, r.recommended_ceiling_rupees,
         r.rationale, r.created_at,
         EXTRACT(EPOCH FROM (now() - r.created_at))/86400.0 AS age_days
  FROM founder_pay_band_reviews r
  WHERE r.status='pending'
  ORDER BY r.created_at ASC
  LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pay_band_pending_queue() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pay_band_pending_queue() TO authenticated;


-- ============================================================
-- Write RPCs (VOLATILE SECDEF, founder-gated)
-- ============================================================

-- 6) Create review row
CREATE OR REPLACE FUNCTION founder_pay_band_create_review(
  p_quarter text,
  p_tier text,
  p_current_floor integer,
  p_current_ceiling integer,
  p_market_floor integer,
  p_market_ceiling integer,
  p_market_source text,
  p_recommended_floor integer,
  p_recommended_ceiling integer,
  p_rationale text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_variance numeric(6,2);
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_current_ceiling > 0 THEN
    v_variance := round(((p_market_ceiling - p_current_ceiling)::numeric / p_current_ceiling) * 100, 2);
  ELSE
    v_variance := 0;
  END IF;

  INSERT INTO founder_pay_band_reviews(
    review_quarter, tier,
    current_floor_rupees, current_ceiling_rupees,
    market_floor_rupees, market_ceiling_rupees, market_source,
    recommended_floor_rupees, recommended_ceiling_rupees,
    variance_pct, rationale, created_by
  ) VALUES (
    p_quarter, p_tier,
    p_current_floor, p_current_ceiling,
    p_market_floor, p_market_ceiling, p_market_source,
    p_recommended_floor, p_recommended_ceiling,
    v_variance, p_rationale, auth.uid()
  )
  RETURNING id INTO v_id;

  PERFORM log_founder_pay_band_review_created(v_id, p_quarter, p_tier);
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pay_band_create_review(text, text, integer, integer, integer, integer, text, integer, integer, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pay_band_create_review(text, text, integer, integer, integer, integer, text, integer, integer, text) TO authenticated;

-- 7) Decide review (approve/reject/defer)
CREATE OR REPLACE FUNCTION founder_pay_band_decide_review(
  p_review_id uuid,
  p_status text,
  p_approved_floor integer,
  p_approved_ceiling integer,
  p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_status NOT IN ('approved','rejected','deferred') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  UPDATE founder_pay_band_reviews
  SET status = p_status,
      approved_floor_rupees = CASE WHEN p_status='approved' THEN p_approved_floor ELSE approved_floor_rupees END,
      approved_ceiling_rupees = CASE WHEN p_status='approved' THEN p_approved_ceiling ELSE approved_ceiling_rupees END,
      decided_by = auth.uid(),
      decided_at = now(),
      decision_note = p_note
  WHERE id = p_review_id;

  PERFORM log_founder_pay_band_review_decided(p_review_id, p_status, p_approved_floor, p_approved_ceiling);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pay_band_decide_review(uuid, text, integer, integer, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pay_band_decide_review(uuid, text, integer, integer, text) TO authenticated;

COMMIT;