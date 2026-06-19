BEGIN;
DROP FUNCTION IF EXISTS public.founder_system_throughput_hourly_summary();
CREATE OR REPLACE FUNCTION public.founder_system_throughput_hourly_summary()
RETURNS TABLE (
  jobs_posted_24h            bigint,
  jobs_completed_24h         bigint,
  peak_hour_posts_24h        integer,
  peak_hour_count_24h        bigint,
  trough_hour_posts_24h      integer,
  trough_hour_count_24h      bigint,
  business_hours_share_pct   numeric,
  night_hours_share_pct      numeric,
  avg_posts_per_hour_24h     numeric,
  avg_completes_per_hour_24h numeric,
  busiest_dow_7d             integer,
  busiest_dow_count_7d       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_posts_24h   bigint;
  v_completes_24h bigint;
  v_peak_hour   integer;
  v_peak_count  bigint;
  v_trough_hour integer;
  v_trough_count bigint;
  v_business    bigint;
  v_night       bigint;
  v_dow         integer;
  v_dow_count   bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_posts_24h
  FROM public.repair_jobs
  WHERE created_at >= now() - interval '24 hours';

  SELECT count(*)::bigint INTO v_completes_24h
  FROM public.repair_jobs
  WHERE status = 'completed'
    AND completed_at IS NOT NULL
    AND completed_at >= now() - interval '24 hours';

  SELECT
    extract(hour FROM (created_at AT TIME ZONE 'Asia/Kolkata'))::integer AS h,
    count(*)::bigint AS c
  INTO v_peak_hour, v_peak_count
  FROM public.repair_jobs
  WHERE created_at >= now() - interval '24 hours'
  GROUP BY 1
  ORDER BY c DESC NULLS LAST, h ASC
  LIMIT 1;

  SELECT
    extract(hour FROM (created_at AT TIME ZONE 'Asia/Kolkata'))::integer AS h,
    count(*)::bigint AS c
  INTO v_trough_hour, v_trough_count
  FROM public.repair_jobs
  WHERE created_at >= now() - interval '24 hours'
  GROUP BY 1
  ORDER BY c ASC NULLS LAST, h ASC
  LIMIT 1;

  SELECT count(*)::bigint INTO v_business
  FROM public.repair_jobs
  WHERE created_at >= now() - interval '24 hours'
    AND extract(hour FROM (created_at AT TIME ZONE 'Asia/Kolkata'))::integer BETWEEN 9 AND 17;

  SELECT count(*)::bigint INTO v_night
  FROM public.repair_jobs
  WHERE created_at >= now() - interval '24 hours'
    AND (
      extract(hour FROM (created_at AT TIME ZONE 'Asia/Kolkata'))::integer >= 22
      OR extract(hour FROM (created_at AT TIME ZONE 'Asia/Kolkata'))::integer < 6
    );

  SELECT
    extract(dow FROM (created_at AT TIME ZONE 'Asia/Kolkata'))::integer AS d,
    count(*)::bigint AS c
  INTO v_dow, v_dow_count
  FROM public.repair_jobs
  WHERE created_at >= now() - interval '7 days'
  GROUP BY 1
  ORDER BY c DESC NULLS LAST, d ASC
  LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce(v_posts_24h, 0),
    coalesce(v_completes_24h, 0),
    coalesce(v_peak_hour, 0),
    coalesce(v_peak_count, 0),
    coalesce(v_trough_hour, 0),
    coalesce(v_trough_count, 0),
    CASE WHEN coalesce(v_posts_24h, 0) = 0 THEN 0::numeric
         ELSE round((v_business::numeric * 100.0) / v_posts_24h::numeric, 1)
    END,
    CASE WHEN coalesce(v_posts_24h, 0) = 0 THEN 0::numeric
         ELSE round((v_night::numeric * 100.0) / v_posts_24h::numeric, 1)
    END,
    round(coalesce(v_posts_24h, 0)::numeric / 24.0, 2),
    round(coalesce(v_completes_24h, 0)::numeric / 24.0, 2),
    coalesce(v_dow, 0),
    coalesce(v_dow_count, 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_system_throughput_hourly_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_system_throughput_hourly_summary() TO authenticated;
COMMIT;
