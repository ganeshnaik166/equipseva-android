-- Round 857 — Recon health surface: count of reconciliation_runs by
-- year/month and the most recent run. Lets the founder confirm whether
-- r489's daily reconciliation cron has actually been firing (the bug
-- r856 may have just fixed).
BEGIN;
DROP FUNCTION IF EXISTS public.founder_reconciliation_health();
CREATE OR REPLACE FUNCTION public.founder_reconciliation_health()
RETURNS TABLE (
  month_at        date,
  runs            bigint,
  anomalies_total bigint
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
    )::date AS month_at
  )
  SELECT
    m.month_at,
    coalesce((SELECT count(*)::bigint FROM public.reconciliation_runs r
              WHERE date_trunc('month', r.run_date)::date = m.month_at), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.reconciliation_anomalies a
              JOIN public.reconciliation_runs r ON r.id = a.run_id
              WHERE date_trunc('month', r.run_date)::date = m.month_at), 0)::bigint
  FROM months m
  ORDER BY m.month_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_reconciliation_health() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_reconciliation_health() TO authenticated;
COMMIT;
