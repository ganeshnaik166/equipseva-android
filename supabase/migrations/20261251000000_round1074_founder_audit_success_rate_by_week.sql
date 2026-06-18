BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_success_rate_by_week();
CREATE OR REPLACE FUNCTION public.founder_audit_success_rate_by_week()
RETURNS TABLE (
  week_start    date,
  total_ops     bigint,
  success_cnt   bigint,
  failed_cnt    bigint,
  success_pct   numeric
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
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
              WHERE date_trunc('week', (a.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
                                                              AS total_ops,
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
              WHERE a.outcome = 'success'
                AND date_trunc('week', (a.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
                                                              AS success_cnt,
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
              WHERE a.outcome = 'failed'
                AND date_trunc('week', (a.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
                                                              AS failed_cnt,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
                     WHERE date_trunc('week', (a.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * coalesce((SELECT count(*)::numeric FROM public.founder_action_log a
                          WHERE a.outcome = 'success'
                            AND date_trunc('week', (a.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
        / coalesce((SELECT count(*)::numeric FROM public.founder_action_log a
                    WHERE date_trunc('week', (a.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 1),
        1)
    END                                                       AS success_pct
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_success_rate_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_success_rate_by_week() TO authenticated;
COMMIT;
