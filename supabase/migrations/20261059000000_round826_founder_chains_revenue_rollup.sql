BEGIN;
DROP FUNCTION IF EXISTS public.founder_chains_revenue_rollup();
CREATE OR REPLACE FUNCTION public.founder_chains_revenue_rollup()
RETURNS TABLE (
  chain_id            uuid,
  name                text,
  member_count        bigint,
  amc_paid_90d        numeric,
  jobs_gross_90d      numeric,
  total_rupees_90d    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH members AS (
    SELECT m.chain_id, m.hospital_user_id
    FROM public.hospital_chain_memberships m
  )
  SELECT
    c.id,
    c.name,
    coalesce((SELECT count(*)::bigint FROM members m WHERE m.chain_id = c.id), 0)::bigint,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              JOIN public.amc_contracts a ON a.id = o.amc_contract_id
              JOIN members m2 ON m2.hospital_user_id = a.hospital_user_id
             WHERE m2.chain_id = c.id
               AND o.status = 'paid'
               AND o.created_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              JOIN members m3 ON m3.hospital_user_id = rj.hospital_user_id
             WHERE m3.chain_id = c.id
               AND rj.status = 'completed'
               AND rj.completed_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              JOIN public.amc_contracts a ON a.id = o.amc_contract_id
              JOIN members m2 ON m2.hospital_user_id = a.hospital_user_id
             WHERE m2.chain_id = c.id
               AND o.status = 'paid'
               AND o.created_at >= now() - interval '90 days'), 0)::numeric
    +
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              JOIN members m3 ON m3.hospital_user_id = rj.hospital_user_id
             WHERE m3.chain_id = c.id
               AND rj.status = 'completed'
               AND rj.completed_at >= now() - interval '90 days'), 0)::numeric
  FROM public.hospital_chains c
  ORDER BY total_rupees_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_chains_revenue_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_chains_revenue_rollup() TO authenticated;
COMMIT;
