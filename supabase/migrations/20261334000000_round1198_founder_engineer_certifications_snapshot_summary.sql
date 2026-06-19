BEGIN;

-- =====================================================================
-- Round 1188 — founder_engineer_certifications_snapshot_summary
-- =====================================================================
-- Domain: engineer-certifications-snapshot
-- Primary tables:
--   public.engineer_certification_progress  (r550 + r578 + r593)
--   public.engineer_certification_tiers     (r550 + r578 supervised gate)
--   public.engineer_tier_history            (r593 append-only ledger)
--
-- WHY:
--   r550 plants the Bronze/Silver/Gold ladder, r578 wires the supervised
--   gate, r593 plants the history ledger. Founder has /supervised-training
--   -snapshot (job-assignments side) but no single snapshot of the LADDER
--   itself: how many engineers per tier, who's stalled, who's eligible to
--   promote, how fast the ladder turns. r1198 fills the gap.
--
-- COLUMNS USED (verified against r550 + r578 + r593 migrations):
--   engineer_certification_progress: engineer_user_id, current_tier,
--     jobs_completed, dispute_rate_pct, verified_tier_at_eval,
--     supervised_completions_at_eval, manual_override, last_computed_at,
--     updated_at
--   engineer_certification_tiers: tier, display_order,
--     min_completed_jobs, max_dispute_rate_pct, min_verified_tier,
--     min_supervised_completions
--   engineer_tier_history: prev_tier, new_tier, changed_at, change_kind
--
-- IST-day boundary used for promotions_today.
-- Calendar month (IST) used for promo/demo this-month.

DROP FUNCTION IF EXISTS public.founder_engineer_certifications_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_engineer_certifications_snapshot_summary()
RETURNS TABLE (
  active_engineers_total          bigint,
  tier_none_count                 bigint,
  tier_bronze_count               bigint,
  tier_silver_count               bigint,
  tier_gold_count                 bigint,
  manual_override_count           bigint,
  promotions_this_month           bigint,
  demotions_this_month            bigint,
  promotions_today                bigint,
  stalled_over_30d                bigint,
  promotion_eligible_queue        bigint,
  avg_days_to_promotion           numeric,
  history_events_30d              bigint,
  hours_since_last_compute        numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_month_start timestamptz := date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata'))::timestamptz AT TIME ZONE 'Asia/Kolkata';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- 1. Active engineers (any row in progress table)
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress), 0),

    -- 2-5. Tier mix
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress
               WHERE current_tier = 'none'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress
               WHERE current_tier = 'bronze'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress
               WHERE current_tier = 'silver'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress
               WHERE current_tier = 'gold'), 0),

    -- 6. Manual founder overrides currently pinned
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress
               WHERE manual_override = true), 0),

    -- 7. Promotions this calendar month (IST): new_tier ranks higher
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_tier_history h
                JOIN public.engineer_certification_tiers tp ON tp.tier = h.prev_tier
                JOIN public.engineer_certification_tiers tn ON tn.tier = h.new_tier
               WHERE h.changed_at >= v_month_start
                 AND tn.display_order > tp.display_order), 0),

    -- 8. Demotions this calendar month (IST): new_tier ranks lower
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_tier_history h
                JOIN public.engineer_certification_tiers tp ON tp.tier = h.prev_tier
                JOIN public.engineer_certification_tiers tn ON tn.tier = h.new_tier
               WHERE h.changed_at >= v_month_start
                 AND tn.display_order < tp.display_order), 0),

    -- 9. Promotions today (IST-day)
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_tier_history h
                JOIN public.engineer_certification_tiers tp ON tp.tier = h.prev_tier
                JOIN public.engineer_certification_tiers tn ON tn.tier = h.new_tier
               WHERE h.changed_at >= v_today_start
                 AND h.changed_at <  v_today_end
                 AND tn.display_order > tp.display_order), 0),

    -- 10. Stalled: non-gold, non-override, untouched >30d
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress
               WHERE current_tier <> 'gold'
                 AND manual_override = false
                 AND updated_at < now() - interval '30 days'), 0),

    -- 11. Promotion-eligible queue: meets ALL gates for a strictly
    --     higher tier but cron hasn't run / override holds them back.
    --     Walks each non-gold progress row, checks if ANY tier with
    --     higher display_order than current passes all four gates.
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_certification_progress p
               WHERE p.manual_override = false
                 AND EXISTS (
                   SELECT 1
                     FROM public.engineer_certification_tiers t
                     JOIN public.engineer_certification_tiers cur
                       ON cur.tier = p.current_tier
                    WHERE t.display_order > cur.display_order
                      AND p.jobs_completed                  >= t.min_completed_jobs
                      AND p.dispute_rate_pct                <= t.max_dispute_rate_pct
                      AND p.supervised_completions_at_eval  >= t.min_supervised_completions
                      AND public._verified_tier_at_or_above(
                            coalesce(p.verified_tier_at_eval, 'none'),
                            t.min_verified_tier)
                 )), 0),

    -- 12. Avg days between consecutive promotions per engineer (last
    --     180d window): pairs each promotion event with the immediately
    --     prior promotion event for the same engineer, averages the gap.
    coalesce((
      WITH promos AS (
        SELECT h.engineer_user_id,
               h.changed_at,
               lag(h.changed_at) OVER (
                 PARTITION BY h.engineer_user_id
                 ORDER BY h.changed_at
               ) AS prev_changed_at
          FROM public.engineer_tier_history h
          JOIN public.engineer_certification_tiers tp ON tp.tier = h.prev_tier
          JOIN public.engineer_certification_tiers tn ON tn.tier = h.new_tier
         WHERE tn.display_order > tp.display_order
           AND h.changed_at >= now() - interval '180 days'
      )
      SELECT round(avg(extract(epoch FROM (changed_at - prev_changed_at)) / 86400.0)::numeric, 1)
        FROM promos
       WHERE prev_changed_at IS NOT NULL
    ), 0)::numeric,

    -- 13. Total history events (any change_kind) last 30d — ladder churn
    coalesce((SELECT count(*)::bigint
                FROM public.engineer_tier_history
               WHERE changed_at >= now() - interval '30 days'), 0),

    -- 14. Hours since most recent compute pass (freshness signal)
    coalesce((SELECT round(extract(epoch FROM (now() - max(last_computed_at))) / 3600.0::numeric, 1)
                FROM public.engineer_certification_progress), 0)::numeric;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_certifications_snapshot_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_certifications_snapshot_summary()
  TO authenticated;

COMMIT;