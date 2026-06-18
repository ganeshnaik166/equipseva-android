BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_state();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_state()
RETURNS TABLE (
  state           text,
  hospital_cnt    bigint,
  jobs_90d        bigint,
  gross_rupees    numeric,
  active_amc_cnt  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      p.id AS hospital_id
    FROM public.profiles p
    WHERE p.role = 'hospital'
  )
  SELECT
    b.state,
    count(DISTINCT b.hospital_id)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE rj.hospital_user_id IN (SELECT hospital_id FROM base b2 WHERE b2.state = b.state)
                AND rj.created_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.hospital_user_id IN (SELECT hospital_id FROM base b2 WHERE b2.state = b.state)
                AND rj.status = 'completed'
                AND rj.completed_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT count(DISTINCT c.id)::bigint FROM public.amc_contracts c
              WHERE c.hospital_user_id IN (SELECT hospital_id FROM base b2 WHERE b2.state = b.state)
                AND c.status = 'active'), 0)::bigint
  FROM base b
  GROUP BY b.state
  ORDER BY jobs_90d DESC
  LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_state() TO authenticated;
COMMIT;
