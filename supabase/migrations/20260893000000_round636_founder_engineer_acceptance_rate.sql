BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_acceptance_rate();
CREATE OR REPLACE FUNCTION public.founder_engineer_acceptance_rate()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  bids_placed       bigint,
  bids_accepted     bigint,
  acceptance_pct    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH bids AS (
    SELECT
      b.engineer_user_id,
      count(*)::bigint                                AS placed,
      count(*) FILTER (WHERE b.status = 'accepted')::bigint AS accepted
    FROM public.repair_job_bids b
    WHERE b.created_at >= now() - interval '30 days'
    GROUP BY b.engineer_user_id
    HAVING count(*) >= 5
  )
  SELECT
    bids.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    bids.placed,
    bids.accepted,
    round((bids.accepted::numeric / bids.placed::numeric) * 100.0, 1) AS acceptance_pct
  FROM bids
  LEFT JOIN public.profiles p ON p.id = bids.engineer_user_id
  ORDER BY acceptance_pct DESC, bids.placed DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_acceptance_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_acceptance_rate() TO authenticated;
COMMIT;
