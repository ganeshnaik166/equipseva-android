BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_changes_by_week();
CREATE OR REPLACE FUNCTION public.founder_tier_changes_by_week()
RETURNS TABLE (
  week_start   date,
  promotions   bigint,
  demotions    bigint,
  total_events bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '12 weeks'),
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 week'
    )::date AS week_start
  ),
  ranks AS (
    SELECT
      h.changed_at,
      CASE WHEN
        CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        > CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
      THEN 1 ELSE 0 END AS is_promo,
      CASE WHEN
        CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        < CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
      THEN 1 ELSE 0 END AS is_demo
    FROM public.engineer_tier_history h
  )
  SELECT
    w.week_start,
    coalesce(sum(r.is_promo) FILTER (WHERE date_trunc('week', (r.changed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce(sum(r.is_demo) FILTER (WHERE date_trunc('week', (r.changed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce(count(*) FILTER (WHERE date_trunc('week', (r.changed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint
  FROM weeks w LEFT JOIN ranks r ON TRUE
  GROUP BY w.week_start
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_changes_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_changes_by_week() TO authenticated;
COMMIT;
