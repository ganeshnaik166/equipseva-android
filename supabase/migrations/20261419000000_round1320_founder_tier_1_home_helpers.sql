BEGIN;

-- r1320: lightweight headline aggregator for /founder-tier-1-home
-- Single SECDEF helper that rolls up the 4 numbers shown in the top hero cards.
-- All heavy lifting stays in the existing 6 RPCs the page calls in parallel.

DROP FUNCTION IF EXISTS public.founder_tier_1_home_metadata();

CREATE OR REPLACE FUNCTION public.founder_tier_1_home_metadata()
RETURNS TABLE (
  last_action_at timestamptz,
  total_open_incidents bigint,
  total_critical_alerts bigint,
  cron_failure_rate_24h_pct numeric,
  generated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH last_act AS (
    SELECT MAX(created_at) AS last_action_at
    FROM public.founder_priority_actions
    WHERE status = 'open'
  ),
  inc AS (
    SELECT COUNT(*) FILTER (WHERE status = 'open') AS open_count,
           COUNT(*) FILTER (WHERE status = 'open' AND severity = 'critical') AS crit_count
    FROM public.founder_incidents
    WHERE created_at > now() - interval '30 days'
  ),
  cron AS (
    SELECT
      CASE WHEN COUNT(*) = 0 THEN 0::numeric
           ELSE ROUND( (COUNT(*) FILTER (WHERE status = 'failed'))::numeric
                       / COUNT(*)::numeric * 100, 2)
      END AS fail_pct
    FROM cron.job_run_details
    WHERE start_time > now() - interval '24 hours'
  )
  SELECT
    last_act.last_action_at,
    COALESCE(inc.open_count, 0)::bigint,
    COALESCE(inc.crit_count, 0)::bigint,
    COALESCE(cron.fail_pct, 0)::numeric,
    now()
  FROM last_act, inc, cron;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tier_1_home_metadata() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tier_1_home_metadata() TO authenticated;

COMMIT;