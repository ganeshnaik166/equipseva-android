BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_by_bank();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_bank()
RETURNS TABLE (
  bank_name      text,
  processed      bigint,
  failed         bigint,
  paid_rupees    numeric,
  fail_pct       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(m.bank_name, ''), '(no bank / VPA)') AS bank_name,
      p.status,
      p.amount_rupees
    FROM public.engineer_payouts p
    LEFT JOIN public.engineer_payout_methods m ON m.id = p.payout_method_id
    WHERE p.queued_at >= now() - interval '90 days'
      AND p.status IN ('processed','failed')
  )
  SELECT
    b.bank_name,
    count(*) FILTER (WHERE b.status = 'processed')::bigint,
    count(*) FILTER (WHERE b.status = 'failed')::bigint,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status = 'processed'), 0)::numeric,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE b.status = 'failed')::numeric
                    / count(*)::numeric * 100.0, 1)
    END
  FROM base b
  GROUP BY b.bank_name
  ORDER BY (count(*) FILTER (WHERE b.status = 'processed') + count(*) FILTER (WHERE b.status = 'failed')) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_bank() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_bank() TO authenticated;
COMMIT;
