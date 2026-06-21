BEGIN;

-- r1643 — Founder console: Engineer career escape velocity
-- Identify engineers ready for promotion via leading indicators:
--   NPS rise, tier climb cadence, peer mentions, payout velocity.
-- Produces a per-engineer readiness score (0..100).

-- 1. Snapshot table: nightly readiness score history (founder-only)
CREATE TABLE IF NOT EXISTS public.founder_engineer_velocity_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL,
  snapshot_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  readiness_score int NOT NULL DEFAULT 0,
  nps_trend numeric(6,2) NOT NULL DEFAULT 0,
  tier_climb_count int NOT NULL DEFAULT 0,
  peer_mention_count int NOT NULL DEFAULT 0,
  jobs_last_90d int NOT NULL DEFAULT 0,
  avg_rating_last_90d numeric(4,2),
  promotion_band text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_fev_snap_date ON public.founder_engineer_velocity_snapshots (snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_fev_snap_engineer ON public.founder_engineer_velocity_snapshots (engineer_user_id);

ALTER TABLE public.founder_engineer_velocity_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only — fev snapshots" ON public.founder_engineer_velocity_snapshots;
CREATE POLICY "founder only — fev snapshots"
  ON public.founder_engineer_velocity_snapshots
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 2. Peer mention ledger (engineers nominating teammates as ready)
CREATE TABLE IF NOT EXISTS public.founder_engineer_peer_mentions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentioner_user_id uuid NOT NULL,
  mentioned_user_id uuid NOT NULL,
  reason text NOT NULL,
  weight int NOT NULL DEFAULT 1 CHECK (weight BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fepm_mentioned ON public.founder_engineer_peer_mentions (mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_fepm_created ON public.founder_engineer_peer_mentions (created_at DESC);

ALTER TABLE public.founder_engineer_peer_mentions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only — peer mentions" ON public.founder_engineer_peer_mentions;
CREATE POLICY "founder only — peer mentions"
  ON public.founder_engineer_peer_mentions
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- LOG HELPERS
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_founder_fev_event(
  p_op text,
  p_after jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, COALESCE(p_after, '{}'::jsonb), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_fev_event(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_fev_event(text, jsonb) TO authenticated;

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

-- 1. Readiness leaderboard
CREATE OR REPLACE FUNCTION public.founder_fev_readiness_leaderboard(
  p_limit int DEFAULT 50
) RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  current_tier text,
  jobs_90d int,
  avg_rating numeric,
  nps_trend numeric,
  peer_mentions int,
  payouts_90d_rupees bigint,
  readiness_score int,
  promotion_band text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH job_stats AS (
    SELECT
      e.user_id AS eng_uid,
      (COUNT(*) FILTER (WHERE rj.created_at > now() - interval '90 days'))::int AS jobs_90d,
      AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '90 days') AS avg_rating,
      (AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '30 days')
        - AVG(rj.hospital_rating) FILTER (WHERE rj.created_at BETWEEN now() - interval '90 days' AND now() - interval '30 days')) AS nps_trend
    FROM public.engineers e
    LEFT JOIN public.repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.user_id
  ),
  mention_stats AS (
    SELECT mentioned_user_id, (COUNT(*) FILTER (WHERE created_at > now() - interval '90 days'))::int AS peer_mentions
    FROM public.founder_engineer_peer_mentions
    GROUP BY mentioned_user_id
  ),
  payout_stats AS (
    SELECT engineer_user_id, COALESCE(SUM(amount_rupees) FILTER (WHERE paid_at IS NOT NULL AND paid_at > now() - interval '90 days'), 0)::bigint AS payouts_90d_rupees
    FROM public.engineer_payouts
    GROUP BY engineer_user_id
  )
  SELECT
    e.user_id,
    COALESCE(p.full_name, p.email, 'Engineer') AS engineer_name,
    e.cached_highest_tier AS current_tier,
    COALESCE(js.jobs_90d, 0) AS jobs_90d,
    ROUND(COALESCE(js.avg_rating, 0)::numeric, 2) AS avg_rating,
    ROUND(COALESCE(js.nps_trend, 0)::numeric, 2) AS nps_trend,
    COALESCE(ms.peer_mentions, 0) AS peer_mentions,
    COALESCE(ps.payouts_90d_rupees, 0) AS payouts_90d_rupees,
    LEAST(100, GREATEST(0,
      (COALESCE(js.jobs_90d, 0) * 2)
      + (COALESCE(js.avg_rating, 0) * 8)::int
      + (COALESCE(js.nps_trend, 0) * 10)::int
      + (COALESCE(ms.peer_mentions, 0) * 5)
    ))::int AS readiness_score,
    CASE
      WHEN LEAST(100, GREATEST(0,
        (COALESCE(js.jobs_90d, 0) * 2)
        + (COALESCE(js.avg_rating, 0) * 8)::int
        + (COALESCE(js.nps_trend, 0) * 10)::int
        + (COALESCE(ms.peer_mentions, 0) * 5)
      )) >= 75 THEN 'ready_now'
      WHEN LEAST(100, GREATEST(0,
        (COALESCE(js.jobs_90d, 0) * 2)
        + (COALESCE(js.avg_rating, 0) * 8)::int
        + (COALESCE(js.nps_trend, 0) * 10)::int
        + (COALESCE(ms.peer_mentions, 0) * 5)
      )) >= 50 THEN 'near_ready'
      ELSE 'developing'
    END AS promotion_band
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  LEFT JOIN job_stats js ON js.eng_uid = e.user_id
  LEFT JOIN mention_stats ms ON ms.mentioned_user_id = e.user_id
  LEFT JOIN payout_stats ps ON ps.engineer_user_id = e.user_id
  ORDER BY readiness_score DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fev_readiness_leaderboard(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fev_readiness_leaderboard(int) TO authenticated;

-- 2. NPS rise trend by tier
CREATE OR REPLACE FUNCTION public.founder_fev_nps_trend_by_tier()
RETURNS TABLE (
  tier text,
  engineers_count int,
  avg_rating_30d numeric,
  avg_rating_90d numeric,
  delta numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(e.cached_highest_tier, 'unranked') AS tier,
    (COUNT(DISTINCT e.user_id))::int AS engineers_count,
    ROUND(AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '30 days')::numeric, 2) AS avg_rating_30d,
    ROUND(AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '90 days')::numeric, 2) AS avg_rating_90d,
    ROUND((AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '30 days')
      - AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '90 days'))::numeric, 2) AS delta
  FROM public.engineers e
  LEFT JOIN public.repair_jobs rj ON rj.engineer_id = e.id
  GROUP BY COALESCE(e.cached_highest_tier, 'unranked')
  ORDER BY tier;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fev_nps_trend_by_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fev_nps_trend_by_tier() TO authenticated;

-- 3. Peer mention top recipients
CREATE OR REPLACE FUNCTION public.founder_fev_peer_mention_top(
  p_days int DEFAULT 90
) RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  mentions_count int,
  total_weight int,
  last_mention_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.mentioned_user_id,
    COALESCE(p.full_name, p.email, 'Engineer') AS engineer_name,
    (COUNT(*))::int AS mentions_count,
    (COALESCE(SUM(m.weight), 0))::int AS total_weight,
    MAX(m.created_at) AS last_mention_at
  FROM public.founder_engineer_peer_mentions m
  LEFT JOIN public.profiles p ON p.id = m.mentioned_user_id
  WHERE m.created_at > now() - (GREATEST(1, COALESCE(p_days, 90)) || ' days')::interval
  GROUP BY m.mentioned_user_id, p.full_name, p.email
  ORDER BY total_weight DESC, mentions_count DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fev_peer_mention_top(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fev_peer_mention_top(int) TO authenticated;

-- 4. Tier climb cadence
CREATE OR REPLACE FUNCTION public.founder_fev_tier_climb_cadence()
RETURNS TABLE (
  band text,
  engineers_count int,
  median_jobs_to_promo int,
  avg_rating numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH bands AS (
    SELECT
      e.user_id,
      e.cached_highest_tier,
      (COUNT(*) FILTER (WHERE rj.id IS NOT NULL))::int AS jobs_count,
      AVG(rj.hospital_rating) AS avg_rating
    FROM public.engineers e
    LEFT JOIN public.repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.user_id, e.cached_highest_tier
  )
  SELECT
    COALESCE(b.cached_highest_tier, 'unranked') AS band,
    (COUNT(*))::int AS engineers_count,
    (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.jobs_count))::int AS median_jobs_to_promo,
    ROUND(AVG(b.avg_rating)::numeric, 2) AS avg_rating
  FROM bands b
  GROUP BY COALESCE(b.cached_highest_tier, 'unranked')
  ORDER BY band;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fev_tier_climb_cadence() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fev_tier_climb_cadence() TO authenticated;

-- 5. Recent snapshots history
CREATE OR REPLACE FUNCTION public.founder_fev_recent_snapshots(
  p_limit int DEFAULT 25
) RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  snapshot_date date,
  readiness_score int,
  promotion_band text,
  peer_mention_count int,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.engineer_user_id,
    COALESCE(p.full_name, p.email, 'Engineer') AS engineer_name,
    s.snapshot_date,
    s.readiness_score,
    s.promotion_band,
    s.peer_mention_count,
    s.notes
  FROM public.founder_engineer_velocity_snapshots s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.snapshot_date DESC, s.readiness_score DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 25));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fev_recent_snapshots(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fev_recent_snapshots(int) TO authenticated;

-- 6. Summary KPIs
CREATE OR REPLACE FUNCTION public.founder_fev_summary()
RETURNS TABLE (
  total_engineers int,
  ready_now_count int,
  near_ready_count int,
  developing_count int,
  peer_mentions_30d int,
  avg_readiness numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_user_id)
      s.engineer_user_id, s.readiness_score, s.promotion_band
    FROM public.founder_engineer_velocity_snapshots s
    ORDER BY s.engineer_user_id, s.snapshot_date DESC
  )
  SELECT
    (SELECT COUNT(*) FROM public.engineers)::int AS total_engineers,
    (COUNT(*) FILTER (WHERE l.promotion_band = 'ready_now'))::int AS ready_now_count,
    (COUNT(*) FILTER (WHERE l.promotion_band = 'near_ready'))::int AS near_ready_count,
    (COUNT(*) FILTER (WHERE l.promotion_band = 'developing'))::int AS developing_count,
    (SELECT COUNT(*) FROM public.founder_engineer_peer_mentions m WHERE m.created_at > now() - interval '30 days')::int AS peer_mentions_30d,
    ROUND(COALESCE(AVG(l.readiness_score), 0)::numeric, 2) AS avg_readiness
  FROM latest l;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fev_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fev_summary() TO authenticated;

-- ============================================================
-- WRITE RPC (VOLATILE)
-- ============================================================

-- 7. Persist a readiness snapshot for an engineer
CREATE OR REPLACE FUNCTION public.founder_fev_record_snapshot(
  p_engineer_user_id uuid,
  p_readiness_score int,
  p_promotion_band text,
  p_peer_mention_count int,
  p_jobs_last_90d int,
  p_avg_rating_last_90d numeric,
  p_nps_trend numeric,
  p_tier_climb_count int,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_engineer_velocity_snapshots (
    engineer_user_id, readiness_score, promotion_band,
    peer_mention_count, jobs_last_90d, avg_rating_last_90d,
    nps_trend, tier_climb_count, notes
  ) VALUES (
    p_engineer_user_id,
    GREATEST(0, LEAST(100, COALESCE(p_readiness_score, 0))),
    COALESCE(p_promotion_band, 'developing'),
    COALESCE(p_peer_mention_count, 0),
    COALESCE(p_jobs_last_90d, 0),
    p_avg_rating_last_90d,
    COALESCE(p_nps_trend, 0),
    COALESCE(p_tier_climb_count, 0),
    p_notes
  )
  ON CONFLICT (engineer_user_id, snapshot_date) DO UPDATE
  SET readiness_score = EXCLUDED.readiness_score,
      promotion_band = EXCLUDED.promotion_band,
      peer_mention_count = EXCLUDED.peer_mention_count,
      jobs_last_90d = EXCLUDED.jobs_last_90d,
      avg_rating_last_90d = EXCLUDED.avg_rating_last_90d,
      nps_trend = EXCLUDED.nps_trend,
      tier_climb_count = EXCLUDED.tier_climb_count,
      notes = EXCLUDED.notes
  RETURNING id INTO v_id;

  PERFORM public.log_founder_fev_event(
    'founder_fev_record_snapshot',
    jsonb_build_object(
      'snapshot_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'readiness_score', p_readiness_score,
      'promotion_band', p_promotion_band
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fev_record_snapshot(uuid, int, text, int, int, numeric, numeric, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fev_record_snapshot(uuid, int, text, int, int, numeric, numeric, int, text) TO authenticated;

COMMIT;