BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_by_equipment_category();
CREATE OR REPLACE FUNCTION public.founder_amc_by_equipment_category()
RETURNS TABLE (
  equipment_category    text,
  total                 bigint,
  active                bigint,
  paused                bigint,
  expired               bigint,
  total_mrr_inr         numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH expanded AS (
    SELECT
      c.id, c.status, c.monthly_fee_rupees,
      coalesce(unnest(c.equipment_categories), '(unknown)')::text AS equipment_category
    FROM public.amc_contracts c
    WHERE c.equipment_categories IS NOT NULL
  )
  SELECT
    e.equipment_category,
    count(*)::bigint                                                  AS total,
    count(*) FILTER (WHERE e.status = 'active')::bigint               AS active,
    count(*) FILTER (WHERE e.status = 'paused')::bigint               AS paused,
    count(*) FILTER (WHERE e.status = 'expired')::bigint              AS expired,
    coalesce(sum(e.monthly_fee_rupees) FILTER (WHERE e.status IN ('active','paused')), 0)::numeric AS total_mrr_inr
  FROM expanded e
  GROUP BY e.equipment_category
  ORDER BY total_mrr_inr DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_by_equipment_category() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_by_equipment_category() TO authenticated;
COMMIT;
