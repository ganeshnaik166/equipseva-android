BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_by_state();
CREATE OR REPLACE FUNCTION public.founder_amc_by_state()
RETURNS TABLE (
  state               text,
  total_amcs          bigint,
  active              bigint,
  paused              bigint,
  expired             bigint,
  active_mrr_inr      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(p.state), ''), '(unknown)')::text                                    AS state,
    count(*)::bigint                                                                            AS total_amcs,
    count(*) FILTER (WHERE c.status = 'active')::bigint                                         AS active,
    count(*) FILTER (WHERE c.status = 'paused')::bigint                                         AS paused,
    count(*) FILTER (WHERE c.status = 'expired')::bigint                                        AS expired,
    coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.status = 'active'), 0)::numeric          AS active_mrr_inr
  FROM public.amc_contracts c
  JOIN public.profiles p ON p.id = c.hospital_user_id
  GROUP BY coalesce(nullif(trim(p.state), ''), '(unknown)')
  ORDER BY active_mrr_inr DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_by_state() TO authenticated;
COMMIT;
