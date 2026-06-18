BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_jobs_recent();
CREATE OR REPLACE FUNCTION public.founder_repair_jobs_recent()
RETURNS TABLE (
  id               uuid,
  hospital_name    text,
  equipment_type   text,
  status           text,
  contract_amount  numeric,
  created_at       timestamptz,
  completed_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.id,
    coalesce(p.full_name, '(hospital)'),
    coalesce(rj.equipment_type::text, '—'),
    rj.status::text,
    rj.contracted_amount_rupees,
    rj.created_at,
    rj.completed_at
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.created_at >= now() - interval '7 days'
  ORDER BY rj.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_jobs_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_jobs_recent() TO authenticated;
COMMIT;
