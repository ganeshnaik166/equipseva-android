BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_changes_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_tier_changes_by_day_30d()
RETURNS TABLE (
  day_ist     date,
  promotions  bigint,
  demotions   bigint,
  total       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  ),
  tier_rank AS (
    SELECT 'none'::text AS tier, 0 AS r
    UNION ALL SELECT 'bronze', 1
    UNION ALL SELECT 'silver', 2
    UNION ALL SELECT 'gold',   3
  ),
  events AS (
    SELECT
      (h.changed_at AT TIME ZONE 'Asia/Kolkata')::date AS day_ist,
      CASE WHEN rn.r > rp.r THEN 'promotion' ELSE 'demotion' END AS direction
    FROM public.engineer_tier_history h
    JOIN tier_rank rp ON rp.tier = h.prev_tier
    JOIN tier_rank rn ON rn.tier = h.new_tier
    WHERE h.changed_at >= now() - interval '30 days'
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM events e
              WHERE e.day_ist = d.day_ist AND e.direction = 'promotion'), 0)              AS promotions,
    coalesce((SELECT count(*)::bigint FROM events e
              WHERE e.day_ist = d.day_ist AND e.direction = 'demotion'), 0)               AS demotions,
    coalesce((SELECT count(*)::bigint FROM events e
              WHERE e.day_ist = d.day_ist), 0)                                              AS total
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_changes_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_changes_by_day_30d() TO authenticated;
COMMIT;
