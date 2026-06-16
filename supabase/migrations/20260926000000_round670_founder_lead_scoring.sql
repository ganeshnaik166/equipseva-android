BEGIN;
DROP FUNCTION IF EXISTS public.founder_lead_scoring();
CREATE OR REPLACE FUNCTION public.founder_lead_scoring()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  bids_30d          bigint,
  accepted_30d      bigint,
  completed_30d     bigint,
  accept_rate_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      b.engineer_user_id,
      count(*)::bigint                                                          AS bids_30d,
      count(*) FILTER (WHERE b.status = 'accepted')::bigint                     AS accepted_30d,
      count(*) FILTER (WHERE b.status = 'accepted' AND rj.status = 'completed')::bigint AS completed_30d
    FROM public.repair_job_bids b
    LEFT JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
    WHERE b.created_at >= now() - interval '30 days'
    GROUP BY b.engineer_user_id
    HAVING count(*) >= 10
      AND count(*) FILTER (WHERE b.status = 'accepted' AND rj.status = 'completed') = 0
  )
  SELECT
    agg.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    agg.bids_30d,
    agg.accepted_30d,
    agg.completed_30d,
    round((agg.accepted_30d::numeric / agg.bids_30d::numeric) * 100.0, 1)
  FROM agg
  LEFT JOIN public.profiles p ON p.id = agg.engineer_user_id
  ORDER BY agg.bids_30d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_lead_scoring() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_lead_scoring() TO authenticated;
COMMIT;
