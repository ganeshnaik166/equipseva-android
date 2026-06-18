BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_debits_by_engineer();
CREATE OR REPLACE FUNCTION public.founder_amc_debits_by_engineer()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  visit_count_90d   bigint,
  total_debit_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    b.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::bigint,
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric
  FROM public.repair_jobs rj
  JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status='accepted'
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  WHERE rj.amc_contract_id IS NOT NULL
    AND rj.status = 'completed'
    AND rj.completed_at >= now() - interval '90 days'
  GROUP BY b.engineer_user_id, p.full_name
  ORDER BY total_debit_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_debits_by_engineer() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_debits_by_engineer() TO authenticated;
COMMIT;
