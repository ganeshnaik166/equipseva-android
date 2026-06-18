BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_first_action_rate_by_week();
CREATE OR REPLACE FUNCTION public.founder_signups_first_action_rate_by_week()
RETURNS TABLE (
  week_start                   date,
  engineer_signups             bigint,
  engineers_with_bid_in_7d     bigint,
  hospital_signups             bigint,
  hospitals_with_job_in_7d     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'engineer'
                AND date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)             AS engineer_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'engineer'
                AND date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start
                AND EXISTS (SELECT 1 FROM public.repair_job_bids b
                            WHERE b.engineer_user_id = p.id
                              AND b.created_at BETWEEN p.created_at AND p.created_at + interval '7 days')), 0)            AS engineers_with_bid_in_7d,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)             AS hospital_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start
                AND EXISTS (SELECT 1 FROM public.repair_jobs j
                            WHERE j.hospital_user_id = p.id
                              AND j.created_at BETWEEN p.created_at AND p.created_at + interval '7 days')), 0)            AS hospitals_with_job_in_7d
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_first_action_rate_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_first_action_rate_by_week() TO authenticated;
COMMIT;
