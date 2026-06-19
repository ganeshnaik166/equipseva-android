BEGIN;

DROP FUNCTION IF EXISTS public.founder_amc_admin_escalations_summary();

CREATE OR REPLACE FUNCTION public.founder_amc_admin_escalations_summary()
RETURNS TABLE (
  total_escalations bigint,
  open_escalations bigint,
  resolved_escalations bigint,
  open_pct numeric,
  created_last_7d bigint,
  created_last_30d bigint,
  resolved_last_30d bigint,
  reason_no_engineers_available bigint,
  reason_rotation_exhausted bigint,
  reason_manual bigint,
  unique_contracts_affected bigint,
  oldest_open_age_days integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      e.id,
      e.amc_contract_id,
      e.reason,
      e.resolved_at,
      e.created_at
    FROM public.amc_admin_escalations e
  )
  SELECT
    COUNT(*)::bigint AS total_escalations,
    COUNT(*) FILTER (WHERE resolved_at IS NULL)::bigint AS open_escalations,
    COUNT(*) FILTER (WHERE resolved_at IS NOT NULL)::bigint AS resolved_escalations,
    CASE WHEN COUNT(*) > 0
         THEN ROUND((COUNT(*) FILTER (WHERE resolved_at IS NULL))::numeric * 100.0 / COUNT(*)::numeric, 1)
         ELSE 0
    END AS open_pct,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '7 days')::bigint AS created_last_7d,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::bigint AS created_last_30d,
    COUNT(*) FILTER (WHERE resolved_at IS NOT NULL AND resolved_at >= now() - interval '30 days')::bigint AS resolved_last_30d,
    COUNT(*) FILTER (WHERE reason = 'no_engineers_available')::bigint AS reason_no_engineers_available,
    COUNT(*) FILTER (WHERE reason = 'rotation_exhausted')::bigint AS reason_rotation_exhausted,
    COUNT(*) FILTER (WHERE reason = 'manual')::bigint AS reason_manual,
    COUNT(DISTINCT amc_contract_id)::bigint AS unique_contracts_affected,
    COALESCE(
      EXTRACT(DAY FROM (now() - MIN(created_at) FILTER (WHERE resolved_at IS NULL)))::integer,
      0
    ) AS oldest_open_age_days
  FROM base;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_admin_escalations_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_admin_escalations_summary() TO authenticated;

COMMIT;
