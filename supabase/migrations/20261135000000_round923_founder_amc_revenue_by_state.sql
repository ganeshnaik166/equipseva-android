BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_revenue_by_state();
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_by_state()
RETURNS TABLE (
  state          text,
  hospital_cnt   bigint,
  paid_orders    bigint,
  paid_rupees    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH paid AS (
    SELECT o.amount_rupees, c.hospital_user_id
    FROM public.amc_payment_orders o
    JOIN public.amc_contracts c ON c.id = o.amc_contract_id
    WHERE o.status = 'paid' AND o.created_at >= now() - interval '90 days'
  ),
  with_state AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
           paid.hospital_user_id,
           paid.amount_rupees
    FROM paid
    LEFT JOIN public.profiles p ON p.id = paid.hospital_user_id
  )
  SELECT
    ws.state,
    count(DISTINCT ws.hospital_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(ws.amount_rupees), 0)::numeric
  FROM with_state ws
  GROUP BY ws.state
  ORDER BY paid_rupees DESC
  LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_revenue_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_revenue_by_state() TO authenticated;
COMMIT;
