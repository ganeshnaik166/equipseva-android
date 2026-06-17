BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_changes_cumulative();
CREATE OR REPLACE FUNCTION public.founder_tier_changes_cumulative()
RETURNS TABLE (
  month_ist date,
  promotions bigint,
  cum_promotions bigint,
  demotions bigint,
  cum_demotions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  ranks AS (
    SELECT h.changed_at,
      CASE WHEN
        CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        > CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
      THEN 1 ELSE 0 END AS is_promo,
      CASE WHEN
        CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        < CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
      THEN 1 ELSE 0 END AS is_demo
    FROM public.engineer_tier_history h
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce(sum(r.is_promo) FILTER (WHERE date_trunc('month', (r.changed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint AS p,
      coalesce(sum(r.is_demo) FILTER (WHERE date_trunc('month', (r.changed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint AS d
    FROM months m LEFT JOIN ranks r ON TRUE
    GROUP BY m.month_ist
  )
  SELECT
    monthly.month_ist,
    monthly.p,
    sum(monthly.p) OVER (ORDER BY monthly.month_ist),
    monthly.d,
    sum(monthly.d) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_changes_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_changes_cumulative() TO authenticated;
COMMIT;
