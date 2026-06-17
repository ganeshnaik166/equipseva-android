BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pending_by_hospital();
CREATE OR REPLACE FUNCTION public.founder_amc_pending_by_hospital()
RETURNS TABLE (
  hospital_user_id   uuid,
  display_name       text,
  city               text,
  pending_orders     bigint,
  pending_rupees     numeric,
  oldest_days        numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT c.hospital_user_id,
           count(*)::bigint AS pending_orders,
           coalesce(sum(o.amount_rupees), 0)::numeric AS pending_rupees,
           coalesce(max(extract(epoch FROM (now() - o.created_at)) / 86400.0), 0)::numeric AS oldest_days
    FROM public.amc_payment_orders o
    JOIN public.amc_contracts c ON c.id = o.amc_contract_id
    WHERE o.status = 'pending'
    GROUP BY c.hospital_user_id
  )
  SELECT
    b.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    coalesce(nullif(trim(p.city), ''), '(unknown)'),
    b.pending_orders,
    b.pending_rupees,
    round(b.oldest_days, 1)
  FROM base b
  LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
  ORDER BY b.pending_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pending_by_hospital() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pending_by_hospital() TO authenticated;
COMMIT;
