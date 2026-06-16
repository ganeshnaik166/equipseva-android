BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_categories_coverage();
CREATE OR REPLACE FUNCTION public.founder_amc_categories_coverage()
RETURNS TABLE (
  category         text,
  contract_count   bigint,
  monthly_mrr      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH unrolled AS (
    SELECT
      c.id,
      c.monthly_fee_rupees,
      unnest(c.equipment_categories) AS category
    FROM public.amc_contracts c
    WHERE c.status = 'active'
      AND array_length(c.equipment_categories, 1) IS NOT NULL
  )
  SELECT
    u.category,
    count(DISTINCT u.id)::bigint                    AS contract_count,
    coalesce(sum(u.monthly_fee_rupees), 0)::numeric AS monthly_mrr
  FROM unrolled u
  GROUP BY u.category
  ORDER BY contract_count DESC, monthly_mrr DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_categories_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_categories_coverage() TO authenticated;
COMMIT;
