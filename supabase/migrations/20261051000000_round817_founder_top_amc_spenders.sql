BEGIN;
DROP FUNCTION IF EXISTS public.founder_top_amc_spenders();
CREATE OR REPLACE FUNCTION public.founder_top_amc_spenders()
RETURNS TABLE (
  hospital_user_id   uuid,
  display_name       text,
  city               text,
  credit_rupees_90d  numeric,
  active_contracts   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH credits AS (
    SELECT c.hospital_user_id, sum(pl.amount_rupees) AS credit_rupees
    FROM public.amc_payment_pool pl
    JOIN public.amc_contracts   c ON c.id = pl.amc_contract_id
    WHERE pl.ledger_kind = 'credit'
      AND pl.created_at >= now() - interval '90 days'
    GROUP BY c.hospital_user_id
  )
  SELECT
    cr.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    coalesce(nullif(trim(p.city), ''), '(unknown)'),
    cr.credit_rupees::numeric,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c2
              WHERE c2.hospital_user_id = cr.hospital_user_id AND c2.status='active'), 0)::bigint
  FROM credits cr
  LEFT JOIN public.profiles p ON p.id = cr.hospital_user_id
  ORDER BY cr.credit_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_top_amc_spenders() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_top_amc_spenders() TO authenticated;
COMMIT;
