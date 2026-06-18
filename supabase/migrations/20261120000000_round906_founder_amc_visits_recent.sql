BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_visits_recent();
CREATE OR REPLACE FUNCTION public.founder_amc_visits_recent()
RETURNS TABLE (
  repair_job_id      uuid,
  hospital_user_id   uuid,
  hospital_name      text,
  status             text,
  contract_amount    numeric,
  created_at         timestamptz,
  completed_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.id,
    rj.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    rj.status::text,
    rj.contracted_amount_rupees,
    rj.created_at,
    rj.completed_at
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.amc_contract_id IS NOT NULL
    AND rj.created_at >= now() - interval '30 days'
  ORDER BY rj.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_visits_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_visits_recent() TO authenticated;
COMMIT;
