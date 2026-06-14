-- Round 575 — Demand-signal trend intel: weekly snapshot + brand rollup
--
-- WHY: r571 dashboard shows only current-state aggregation by
-- (brand, model, part_number). Founder needs trend signal:
--   (a) Is demand growing or shrinking week-over-week?
--   (b) Which OEM brand has the most unfulfilled demand right now?
--
-- Ships TWO new SECDEF, founder-only, STABLE RPCs:
--   founder_demand_signal_weekly_snapshot()  — 4-metric WoW delta
--   founder_demand_signal_brand_rollup()      — top-20 brands, unresolved
--
-- Both are pure read RPCs. No table changes. No founder_action_log
-- writes (no state mutation).

BEGIN;

-- ----------------------------------------------------------------
-- RPC: founder_demand_signal_weekly_snapshot
-- Returns 4 rows, one per metric, with current-7d vs prior-7d delta.
-- Windows:
--   current = [now() - 7d, now())
--   prior   = [now() - 14d, now() - 7d)
-- delta_pct = ((current - prior) / nullif(prior, 0)) * 100, 1 dp.
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_demand_signal_weekly_snapshot();
CREATE OR REPLACE FUNCTION public.founder_demand_signal_weekly_snapshot()
RETURNS TABLE (
  metric             text,
  current_week_value bigint,
  prior_week_value   bigint,
  delta_pct          numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_now        timestamptz := now();
  v_cur_start  timestamptz := now() - interval '7 days';
  v_prior_start timestamptz := now() - interval '14 days';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH
  new_cur AS (
    SELECT count(*)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.occurred_at >= v_cur_start
       AND s.occurred_at <  v_now
  ),
  new_prior AS (
    SELECT count(*)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.occurred_at >= v_prior_start
       AND s.occurred_at <  v_cur_start
  ),
  res_cur AS (
    SELECT count(*)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.resolved_at IS NOT NULL
       AND s.resolved_at >= v_cur_start
       AND s.resolved_at <  v_now
  ),
  res_prior AS (
    SELECT count(*)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.resolved_at IS NOT NULL
       AND s.resolved_at >= v_prior_start
       AND s.resolved_at <  v_cur_start
  ),
  upn_cur AS (
    SELECT count(DISTINCT s.part_number)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.occurred_at >= v_cur_start
       AND s.occurred_at <  v_now
       AND s.part_number IS NOT NULL
  ),
  upn_prior AS (
    SELECT count(DISTINCT s.part_number)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.occurred_at >= v_prior_start
       AND s.occurred_at <  v_cur_start
       AND s.part_number IS NOT NULL
  ),
  crit_cur AS (
    SELECT count(*)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.urgency = 'critical'
       AND s.occurred_at >= v_cur_start
       AND s.occurred_at <  v_now
  ),
  crit_prior AS (
    SELECT count(*)::bigint AS v
      FROM public.spare_part_demand_signals s
     WHERE s.urgency = 'critical'
       AND s.occurred_at >= v_prior_start
       AND s.occurred_at <  v_cur_start
  ),
  rows(metric, current_week_value, prior_week_value) AS (
    SELECT 'new_signals'::text,         (SELECT v FROM new_cur),  (SELECT v FROM new_prior)
    UNION ALL
    SELECT 'resolved_signals'::text,    (SELECT v FROM res_cur),  (SELECT v FROM res_prior)
    UNION ALL
    SELECT 'unique_part_numbers'::text, (SELECT v FROM upn_cur),  (SELECT v FROM upn_prior)
    UNION ALL
    SELECT 'critical_signals'::text,    (SELECT v FROM crit_cur), (SELECT v FROM crit_prior)
  )
  SELECT
    r.metric,
    r.current_week_value,
    r.prior_week_value,
    round(
      ((r.current_week_value - r.prior_week_value)::numeric
        / nullif(r.prior_week_value, 0)::numeric) * 100.0,
      1
    ) AS delta_pct
  FROM rows r
  ORDER BY
    CASE r.metric
      WHEN 'new_signals'         THEN 1
      WHEN 'resolved_signals'    THEN 2
      WHEN 'unique_part_numbers' THEN 3
      WHEN 'critical_signals'    THEN 4
      ELSE 99
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_demand_signal_weekly_snapshot() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_demand_signal_weekly_snapshot() TO authenticated;

-- ----------------------------------------------------------------
-- RPC: founder_demand_signal_brand_rollup
-- One row per equipment_brand (case-insensitive group), unresolved only.
-- NULL brand collapses to a single '?' bucket (visible as brand=NULL).
-- Sort: signal_count DESC, last_seen DESC. LIMIT 20.
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_demand_signal_brand_rollup();
CREATE OR REPLACE FUNCTION public.founder_demand_signal_brand_rollup()
RETURNS TABLE (
  brand               text,
  signal_count        bigint,
  unique_part_numbers bigint,
  unique_reporters    bigint,
  last_seen           timestamptz,
  has_critical        boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH agg AS (
    SELECT
      coalesce(lower(s.equipment_brand), '?')           AS brand_key,
      max(s.equipment_brand)                            AS brand,
      count(*)::bigint                                  AS signal_count,
      (count(DISTINCT s.part_number)
        FILTER (WHERE s.part_number IS NOT NULL))::bigint AS unique_part_numbers,
      count(DISTINCT s.reporter_user_id)::bigint        AS unique_reporters,
      max(s.occurred_at)                                AS last_seen,
      bool_or(s.urgency = 'critical')                   AS has_critical
    FROM public.spare_part_demand_signals s
    WHERE s.resolved_at IS NULL
    GROUP BY 1
  )
  SELECT
    a.brand,
    a.signal_count,
    a.unique_part_numbers,
    a.unique_reporters,
    a.last_seen,
    a.has_critical
  FROM agg a
  ORDER BY a.signal_count DESC, a.last_seen DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_demand_signal_brand_rollup() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_demand_signal_brand_rollup() TO authenticated;

COMMIT;
