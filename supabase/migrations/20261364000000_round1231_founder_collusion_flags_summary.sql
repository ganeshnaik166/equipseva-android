BEGIN;

-- =====================================================================
-- Round 1231 — founder_collusion_flags_summary
-- =====================================================================
-- Single-row snapshot of public.collusion_flags for the founder console.
-- Pre-emptive fraud signals (engineer<->hospital collusion) — covers
-- open vs investigating vs confirmed vs false_positive, signal-kind mix,
-- distinct engineer/hospital reach, oldest unreviewed age, money exposure.
-- Reads only the dedicated collusion_flags table; no cross-table joins
-- (engineer/hospital identifiers live on auth.users via FK; not needed
-- for aggregates).
-- =====================================================================

DROP FUNCTION IF EXISTS public.founder_collusion_flags_summary();

CREATE OR REPLACE FUNCTION public.founder_collusion_flags_summary()
RETURNS TABLE(
  total_all_time              bigint,
  open_now                    bigint,
  investigating_now           bigint,
  confirmed_all_time          bigint,
  false_positive_all_time     bigint,
  resolved_all_time           bigint,
  unreviewed_over_7d          bigint,
  oldest_unreviewed_age_hours numeric,
  distinct_engineers_flagged  bigint,
  distinct_hospitals_flagged  bigint,
  closed_loop_pair_open       bigint,
  shared_ip_signature_open    bigint,
  bid_amount_clustering_open  bigint,
  open_money_at_stake_inr     numeric,
  created_today               bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::bigint AS total_all_time,
    COUNT(*) FILTER (WHERE c.status = 'open')::bigint AS open_now,
    COUNT(*) FILTER (WHERE c.status = 'investigating')::bigint AS investigating_now,
    COUNT(*) FILTER (WHERE c.status = 'confirmed')::bigint AS confirmed_all_time,
    COUNT(*) FILTER (WHERE c.status = 'false_positive')::bigint AS false_positive_all_time,
    COUNT(*) FILTER (WHERE c.status = 'resolved')::bigint AS resolved_all_time,
    COUNT(*) FILTER (
      WHERE c.status IN ('open','investigating')
        AND c.created_at < now() - interval '7 days'
    )::bigint AS unreviewed_over_7d,
    COALESCE(
      EXTRACT(EPOCH FROM (now() - MIN(c.created_at) FILTER (
        WHERE c.status IN ('open','investigating')
      ))) / 3600.0,
      0
    )::numeric AS oldest_unreviewed_age_hours,
    COUNT(DISTINCT c.engineer_user_id) FILTER (
      WHERE c.status IN ('open','investigating','confirmed')
    )::bigint AS distinct_engineers_flagged,
    COUNT(DISTINCT c.hospital_user_id) FILTER (
      WHERE c.status IN ('open','investigating','confirmed')
    )::bigint AS distinct_hospitals_flagged,
    COUNT(*) FILTER (
      WHERE c.status IN ('open','investigating')
        AND c.signal_kind = 'closed_loop_pair'
    )::bigint AS closed_loop_pair_open,
    COUNT(*) FILTER (
      WHERE c.status IN ('open','investigating')
        AND c.signal_kind = 'shared_ip_signature'
    )::bigint AS shared_ip_signature_open,
    COUNT(*) FILTER (
      WHERE c.status IN ('open','investigating')
        AND c.signal_kind = 'bid_amount_clustering'
    )::bigint AS bid_amount_clustering_open,
    COALESCE(SUM(c.total_value_rupees_30d) FILTER (
      WHERE c.status IN ('open','investigating')
    ), 0)::numeric AS open_money_at_stake_inr,
    COUNT(*) FILTER (
      WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date
          = (now()        AT TIME ZONE 'Asia/Kolkata')::date
    )::bigint AS created_today
  FROM public.collusion_flags c;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_collusion_flags_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_collusion_flags_summary()
  TO authenticated;

COMMENT ON FUNCTION public.founder_collusion_flags_summary() IS
  'Round 1231 — 15-KPI snapshot over public.collusion_flags for founder console.';

COMMIT;
