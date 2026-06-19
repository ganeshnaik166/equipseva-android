BEGIN;
-- =====================================================================
-- Round 1273 — Engineer tier history summary (founder ops landing)
-- =====================================================================
--
-- The r593 engineer_tier_history ledger captures every tier transition
-- emitted by the compute_engineer_certification_tier cron + founder
-- overrides. Existing founder reads:
--
--   founder_tier_history_recent(int)   — last N rows (raw list)
--
-- That's good for forensics but not for at-a-glance pulse. r1273 lays
-- down a 14-KPI summary KPI block scoped to the tier-progression
-- timeline: volume by window (24h/7d/30d/180d), change-kind mix
-- (cron vs founder overrides), promotion-vs-demotion direction
-- counters, gold reaches, none→bronze first-promo counter, and last-
-- event-recency for cron-health.
--
-- Distinct from /engineer-certifications-snapshot (current-state mix)
-- and /engineer-loyalty-funnel (signup→active funnel). This one is
-- pure ledger arithmetic — what HAS HAPPENED on the ladder, not who's
-- where today.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_engineer_tier_history_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_tier_history_summary()
RETURNS TABLE (
  events_total            bigint,
  events_24h              bigint,
  events_7d               bigint,
  events_30d              bigint,
  events_180d             bigint,
  promotions_30d          bigint,
  demotions_30d           bigint,
  cron_compute_30d        bigint,
  founder_override_30d    bigint,
  reached_gold_total      bigint,
  reached_silver_total    bigint,
  first_promo_none_bronze bigint,
  distinct_engineers_30d  bigint,
  hours_since_last_event  numeric
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
  WITH base AS (
    SELECT
      h.prev_tier,
      h.new_tier,
      h.change_kind,
      h.engineer_user_id,
      h.changed_at
    FROM public.engineer_tier_history h
  ),
  tier_rank AS (
    -- Map tiers to ordinal rank so we can detect direction.
    SELECT 'none'   AS tier, 0 AS rk UNION ALL
    SELECT 'bronze',  1 UNION ALL
    SELECT 'silver',  2 UNION ALL
    SELECT 'gold',    3
  ),
  enriched AS (
    SELECT
      b.*,
      pr.rk AS prev_rk,
      nr.rk AS new_rk
    FROM base b
    LEFT JOIN tier_rank pr ON pr.tier = b.prev_tier
    LEFT JOIN tier_rank nr ON nr.tier = b.new_tier
  )
  SELECT
    (SELECT count(*) FROM enriched)::bigint                                                                        AS events_total,
    (SELECT count(*) FROM enriched WHERE changed_at > now() - interval '24 hours')::bigint                          AS events_24h,
    (SELECT count(*) FROM enriched WHERE changed_at > now() - interval '7 days')::bigint                            AS events_7d,
    (SELECT count(*) FROM enriched WHERE changed_at > now() - interval '30 days')::bigint                           AS events_30d,
    (SELECT count(*) FROM enriched WHERE changed_at > now() - interval '180 days')::bigint                          AS events_180d,
    (SELECT count(*) FROM enriched
       WHERE changed_at > now() - interval '30 days' AND new_rk > prev_rk)::bigint                                  AS promotions_30d,
    (SELECT count(*) FROM enriched
       WHERE changed_at > now() - interval '30 days' AND new_rk < prev_rk)::bigint                                  AS demotions_30d,
    (SELECT count(*) FROM enriched
       WHERE changed_at > now() - interval '30 days' AND change_kind = 'cron_compute')::bigint                      AS cron_compute_30d,
    (SELECT count(*) FROM enriched
       WHERE changed_at > now() - interval '30 days'
         AND change_kind IN ('founder_override','founder_promote','founder_demote'))::bigint                        AS founder_override_30d,
    (SELECT count(*) FROM enriched WHERE new_tier = 'gold')::bigint                                                 AS reached_gold_total,
    (SELECT count(*) FROM enriched WHERE new_tier = 'silver')::bigint                                               AS reached_silver_total,
    (SELECT count(*) FROM enriched WHERE prev_tier = 'none' AND new_tier = 'bronze')::bigint                        AS first_promo_none_bronze,
    (SELECT count(DISTINCT engineer_user_id) FROM enriched WHERE changed_at > now() - interval '30 days')::bigint   AS distinct_engineers_30d,
    coalesce(
      (SELECT EXTRACT(EPOCH FROM (now() - max(changed_at))) / 3600.0 FROM enriched),
      0
    )::numeric                                                                                                       AS hours_since_last_event;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_tier_history_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_tier_history_summary()
  TO authenticated;

COMMIT;
