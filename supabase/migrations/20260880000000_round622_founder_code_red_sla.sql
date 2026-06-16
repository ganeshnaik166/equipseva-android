BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_sla();
CREATE OR REPLACE FUNCTION public.founder_code_red_sla()
RETURNS TABLE (
  window_label    text,
  total_requests  bigint,
  accepted        bigint,
  resolved        bigint,
  timed_out       bigint,
  accept_rate_pct numeric,
  avg_accept_minutes numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      r.created_at,
      r.status,
      r.accepted_at,
      CASE WHEN r.accepted_at IS NOT NULL
           THEN extract(epoch FROM (r.accepted_at - r.created_at)) / 60.0
           ELSE NULL
      END AS accept_minutes
    FROM public.code_red_requests r
    WHERE r.created_at >= now() - interval '90 days'
  ),
  w7  AS (SELECT * FROM base WHERE created_at >= now() - interval '7 days'),
  w30 AS (SELECT * FROM base WHERE created_at >= now() - interval '30 days'),
  w90 AS (SELECT * FROM base)
  SELECT '7d'::text,
    (SELECT count(*) FROM w7)::bigint,
    (SELECT count(*) FROM w7 WHERE status IN ('engineer_accepted','resolved'))::bigint,
    (SELECT count(*) FROM w7 WHERE status = 'resolved')::bigint,
    (SELECT count(*) FROM w7 WHERE status = 'timed_out')::bigint,
    CASE WHEN (SELECT count(*) FROM w7) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w7 WHERE status IN ('engineer_accepted','resolved'))::numeric
                    / (SELECT count(*) FROM w7)::numeric) * 100.0, 1) END,
    (SELECT round(avg(accept_minutes)::numeric, 1) FROM w7 WHERE accept_minutes IS NOT NULL)
  UNION ALL
  SELECT '30d',
    (SELECT count(*) FROM w30)::bigint,
    (SELECT count(*) FROM w30 WHERE status IN ('engineer_accepted','resolved'))::bigint,
    (SELECT count(*) FROM w30 WHERE status = 'resolved')::bigint,
    (SELECT count(*) FROM w30 WHERE status = 'timed_out')::bigint,
    CASE WHEN (SELECT count(*) FROM w30) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w30 WHERE status IN ('engineer_accepted','resolved'))::numeric
                    / (SELECT count(*) FROM w30)::numeric) * 100.0, 1) END,
    (SELECT round(avg(accept_minutes)::numeric, 1) FROM w30 WHERE accept_minutes IS NOT NULL)
  UNION ALL
  SELECT '90d',
    (SELECT count(*) FROM w90)::bigint,
    (SELECT count(*) FROM w90 WHERE status IN ('engineer_accepted','resolved'))::bigint,
    (SELECT count(*) FROM w90 WHERE status = 'resolved')::bigint,
    (SELECT count(*) FROM w90 WHERE status = 'timed_out')::bigint,
    CASE WHEN (SELECT count(*) FROM w90) = 0 THEN 0::numeric
         ELSE round(((SELECT count(*) FROM w90 WHERE status IN ('engineer_accepted','resolved'))::numeric
                    / (SELECT count(*) FROM w90)::numeric) * 100.0, 1) END,
    (SELECT round(avg(accept_minutes)::numeric, 1) FROM w90 WHERE accept_minutes IS NOT NULL);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_sla() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_sla() TO authenticated;
COMMIT;
