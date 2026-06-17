BEGIN;
DROP FUNCTION IF EXISTS public.founder_spot_audit_by_engineer();
CREATE OR REPLACE FUNCTION public.founder_spot_audit_by_engineer()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  responses_180d    bigint,
  avg_rating        numeric,
  low_2less         bigint,
  high_4plus        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      b.engineer_user_id,
      r.rating
    FROM public.spot_audit_responses r
    JOIN public.spot_audit_invitations i ON i.id = r.invitation_id
    JOIN public.repair_job_bids b ON b.repair_job_id = i.repair_job_id AND b.status = 'accepted'
    WHERE r.responded_at >= now() - interval '180 days'
  )
  SELECT
    b.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::bigint,
    coalesce(round(avg(b.rating)::numeric, 2), 0)::numeric,
    count(*) FILTER (WHERE b.rating <= 2)::bigint,
    count(*) FILTER (WHERE b.rating >= 4)::bigint
  FROM base b
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  GROUP BY b.engineer_user_id, p.full_name
  HAVING count(*) >= 3
  ORDER BY avg_rating ASC, responses_180d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spot_audit_by_engineer() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audit_by_engineer() TO authenticated;
COMMIT;
