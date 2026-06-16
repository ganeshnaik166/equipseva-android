BEGIN;
DROP FUNCTION IF EXISTS public.founder_bid_volume_trend();
CREATE OR REPLACE FUNCTION public.founder_bid_volume_trend()
RETURNS TABLE (
  day_ist     date,
  bids_placed bigint,
  bids_accepted bigint,
  distinct_engineers bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_job_bids b
       WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS bids_placed,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_job_bids b
       WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
         AND b.status = 'accepted'
      ), 0)::bigint AS bids_accepted,
    coalesce(
      (SELECT count(DISTINCT b.engineer_user_id)::bigint FROM public.repair_job_bids b
       WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS distinct_engineers
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bid_volume_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bid_volume_trend() TO authenticated;
COMMIT;
