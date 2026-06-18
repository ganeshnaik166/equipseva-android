BEGIN;
DROP FUNCTION IF EXISTS public.founder_undeposited_tds();
CREATE OR REPLACE FUNCTION public.founder_undeposited_tds()
RETURNS TABLE (
  fiscal_year       text,
  fy_quarter        text,
  rows              bigint,
  total_tds_rupees  numeric,
  oldest_days       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    t.fiscal_year,
    t.fy_quarter,
    count(*)::bigint,
    coalesce(sum(t.tds_rupees), 0)::numeric,
    coalesce(round(extract(epoch FROM (now() - min(t.created_at))) / 86400.0, 1)::numeric, 0)::numeric
  FROM public.tds_deductions t
  WHERE t.deducted = true
    AND t.deposited_to_govt_at IS NULL
  GROUP BY t.fiscal_year, t.fy_quarter
  ORDER BY t.fiscal_year DESC, t.fy_quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_undeposited_tds() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_undeposited_tds() TO authenticated;
COMMIT;
