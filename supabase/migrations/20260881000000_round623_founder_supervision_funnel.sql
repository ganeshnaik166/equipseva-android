BEGIN;
DROP FUNCTION IF EXISTS public.founder_supervision_funnel();
CREATE OR REPLACE FUNCTION public.founder_supervision_funnel()
RETURNS TABLE (
  window_label    text,
  requested       bigint,
  accepted        bigint,
  signed_off      bigint,
  successful      bigint,
  accept_rate_pct numeric,
  success_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      requested_at,
      status,
      signoff_outcome
    FROM public.supervised_job_assignments
    WHERE requested_at >= now() - interval '90 days'
  ),
  w7  AS (SELECT * FROM base WHERE requested_at >= now() - interval '7 days'),
  w30 AS (SELECT * FROM base WHERE requested_at >= now() - interval '30 days'),
  w90 AS (SELECT * FROM base)
  SELECT '7d'::text,
    (SELECT count(*) FROM w7)::bigint,
    (SELECT count(*) FROM w7 WHERE status NOT IN ('pending_supervisor_accept','declined'))::bigint,
    (SELECT count(*) FROM w7 WHERE status IN ('completed_successful','completed_failed'))::bigint,
    (SELECT count(*) FROM w7 WHERE status = 'completed_successful')::bigint,
    CASE WHEN (SELECT count(*) FROM w7) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w7 WHERE status NOT IN ('pending_supervisor_accept','declined'))::numeric / (SELECT count(*) FROM w7)::numeric) * 100.0, 1) END,
    CASE WHEN (SELECT count(*) FROM w7 WHERE status IN ('completed_successful','completed_failed')) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w7 WHERE status = 'completed_successful')::numeric / (SELECT count(*) FROM w7 WHERE status IN ('completed_successful','completed_failed'))::numeric) * 100.0, 1) END
  UNION ALL
  SELECT '30d',
    (SELECT count(*) FROM w30)::bigint,
    (SELECT count(*) FROM w30 WHERE status NOT IN ('pending_supervisor_accept','declined'))::bigint,
    (SELECT count(*) FROM w30 WHERE status IN ('completed_successful','completed_failed'))::bigint,
    (SELECT count(*) FROM w30 WHERE status = 'completed_successful')::bigint,
    CASE WHEN (SELECT count(*) FROM w30) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w30 WHERE status NOT IN ('pending_supervisor_accept','declined'))::numeric / (SELECT count(*) FROM w30)::numeric) * 100.0, 1) END,
    CASE WHEN (SELECT count(*) FROM w30 WHERE status IN ('completed_successful','completed_failed')) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w30 WHERE status = 'completed_successful')::numeric / (SELECT count(*) FROM w30 WHERE status IN ('completed_successful','completed_failed'))::numeric) * 100.0, 1) END
  UNION ALL
  SELECT '90d',
    (SELECT count(*) FROM w90)::bigint,
    (SELECT count(*) FROM w90 WHERE status NOT IN ('pending_supervisor_accept','declined'))::bigint,
    (SELECT count(*) FROM w90 WHERE status IN ('completed_successful','completed_failed'))::bigint,
    (SELECT count(*) FROM w90 WHERE status = 'completed_successful')::bigint,
    CASE WHEN (SELECT count(*) FROM w90) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w90 WHERE status NOT IN ('pending_supervisor_accept','declined'))::numeric / (SELECT count(*) FROM w90)::numeric) * 100.0, 1) END,
    CASE WHEN (SELECT count(*) FROM w90 WHERE status IN ('completed_successful','completed_failed')) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w90 WHERE status = 'completed_successful')::numeric / (SELECT count(*) FROM w90 WHERE status IN ('completed_successful','completed_failed'))::numeric) * 100.0, 1) END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supervision_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervision_funnel() TO authenticated;
COMMIT;
