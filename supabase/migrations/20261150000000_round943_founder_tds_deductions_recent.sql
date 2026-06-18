BEGIN;
DROP FUNCTION IF EXISTS public.founder_tds_deductions_recent();
CREATE OR REPLACE FUNCTION public.founder_tds_deductions_recent()
RETURNS TABLE (
  id                 uuid,
  engineer_name      text,
  fiscal_year        text,
  fy_quarter         text,
  gross_rupees       numeric,
  tds_rate_pct       numeric,
  tds_rupees         numeric,
  net_payable_rupees numeric,
  deducted           boolean,
  deposited          boolean,
  created_at         timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    coalesce(p.full_name, '(engineer)'),
    t.fiscal_year,
    t.fy_quarter,
    t.gross_rupees,
    t.tds_rate_pct,
    t.tds_rupees,
    t.net_payable_rupees,
    coalesce(t.deducted, false),
    (t.deposited_to_govt_at IS NOT NULL),
    t.created_at
  FROM public.tds_deductions t
  LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
  WHERE t.created_at >= now() - interval '90 days'
  ORDER BY t.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tds_deductions_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tds_deductions_recent() TO authenticated;
COMMIT;
