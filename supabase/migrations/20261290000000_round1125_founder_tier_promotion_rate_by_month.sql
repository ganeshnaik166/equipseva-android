BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_promotion_rate_by_month();
CREATE OR REPLACE FUNCTION public.founder_tier_promotion_rate_by_month()
RETURNS TABLE (
  month_ist          date,
  promotions         bigint,
  demotions          bigint,
  active_engineers   bigint,
  promotion_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  ),
  tier_rank AS (
    SELECT 'none'::text AS tier, 0 AS r
    UNION ALL SELECT 'bronze', 1
    UNION ALL SELECT 'silver', 2
    UNION ALL SELECT 'gold',   3
  ),
  events AS (
    SELECT
      date_trunc('month', (h.changed_at AT TIME ZONE 'Asia/Kolkata'))::date AS month_ist,
      CASE WHEN rn.r > rp.r THEN 'promotion' ELSE 'demotion' END AS direction
    FROM public.engineer_tier_history h
    JOIN tier_rank rp ON rp.tier = h.prev_tier
    JOIN tier_rank rn ON rn.tier = h.new_tier
  ),
  base AS (
    SELECT count(*)::bigint AS n FROM public.engineers WHERE verification_status = 'verified'
  )
  SELECT
    m.month_ist,
    coalesce((SELECT count(*)::bigint FROM events e
              WHERE e.month_ist = m.month_ist AND e.direction = 'promotion'), 0)              AS promotions,
    coalesce((SELECT count(*)::bigint FROM events e
              WHERE e.month_ist = m.month_ist AND e.direction = 'demotion'), 0)               AS demotions,
    (SELECT n FROM base)::bigint                                                              AS active_engineers,
    CASE WHEN (SELECT n FROM base) = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM events e
                                      WHERE e.month_ist = m.month_ist AND e.direction = 'promotion'), 0)
                    / (SELECT n FROM base), 2)
    END                                                                                       AS promotion_pct
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_promotion_rate_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_promotion_rate_by_month() TO authenticated;
COMMIT;
