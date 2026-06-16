BEGIN;
DROP FUNCTION IF EXISTS public.founder_dispute_outcomes();
CREATE OR REPLACE FUNCTION public.founder_dispute_outcomes()
RETURNS TABLE (
  outcome    text,
  cnt        bigint,
  share_pct  numeric,
  avg_money  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.dispute_evidence_packs WHERE status IN ('accepted','rejected');
  RETURN QUERY
  SELECT
    d.status,
    count(*)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric ELSE round(count(*)::numeric / v_total::numeric * 100.0, 1) END,
    coalesce(round(avg(d.total_money_at_stake_rupees)::numeric, 2), 0)
  FROM public.dispute_evidence_packs d
  WHERE d.status IN ('accepted','rejected')
  GROUP BY d.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dispute_outcomes() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dispute_outcomes() TO authenticated;
COMMIT;
