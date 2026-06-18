BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_by_engineer_90d();
CREATE OR REPLACE FUNCTION public.founder_code_red_by_engineer_90d()
RETURNS TABLE (
  engineer_name      text,
  paged_cnt          bigint,
  accepted_cnt       bigint,
  resolved_cnt       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH engs AS (
    SELECT
      d.engineer_user_id,
      count(*) FILTER (WHERE d.paged_at >= now() - interval '90 days')::bigint AS paged_cnt,
      count(*) FILTER (WHERE d.paged_at >= now() - interval '90 days' AND d.outcome = 'accepted')::bigint AS accepted_cnt
    FROM public.code_red_dispatch_events d
    GROUP BY d.engineer_user_id
  ),
  resolved AS (
    SELECT r.accepted_engineer_user_id AS engineer_user_id,
           count(*)::bigint AS resolved_cnt
    FROM public.code_red_requests r
    WHERE r.status = 'resolved'
      AND r.accepted_engineer_user_id IS NOT NULL
      AND r.created_at >= now() - interval '90 days'
    GROUP BY r.accepted_engineer_user_id
  )
  SELECT
    coalesce(p.full_name, '(no name)')::text                              AS engineer_name,
    e.paged_cnt,
    e.accepted_cnt,
    coalesce(rs.resolved_cnt, 0)::bigint                                   AS resolved_cnt
  FROM engs e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  LEFT JOIN resolved rs ON rs.engineer_user_id = e.engineer_user_id
  WHERE e.paged_cnt > 0
  ORDER BY resolved_cnt DESC NULLS LAST, accepted_cnt DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_by_engineer_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_by_engineer_90d() TO authenticated;
COMMIT;
