BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_by_mode();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_mode()
RETURNS TABLE (
  mode          text,
  processed_90d bigint,
  failed_90d    bigint,
  paid_rupees   numeric,
  fail_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(p.mode, '(unknown)') AS mode,
      p.status,
      p.amount_paise
    FROM public.engineer_payouts p
    WHERE p.queued_at >= now() - interval '90 days'
      AND p.status IN ('processed','failed')
  )
  SELECT
    b.mode,
    count(*) FILTER (WHERE b.status = 'processed')::bigint,
    count(*) FILTER (WHERE b.status = 'failed')::bigint,
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.status = 'processed'), 0)::numeric / 100.0, 2),
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE b.status = 'failed')::numeric
                    / count(*)::numeric * 100.0, 1)
    END
  FROM base b
  GROUP BY b.mode
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_mode() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_mode() TO authenticated;
COMMIT;
