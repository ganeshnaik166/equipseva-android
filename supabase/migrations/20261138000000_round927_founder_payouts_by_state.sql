BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_by_state();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_state()
RETURNS TABLE (
  state          text,
  engineers      bigint,
  processed_90d  bigint,
  paid_rupees_90d numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(pr.state), ''), '(unknown)') AS state,
      p.engineer_user_id,
      p.amount_paise,
      p.status
    FROM public.engineer_payouts p
    LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
    WHERE p.queued_at >= now() - interval '90 days'
  )
  SELECT
    b.state,
    count(DISTINCT b.engineer_user_id)::bigint,
    count(*) FILTER (WHERE b.status = 'processed')::bigint,
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.status='processed'), 0)::numeric / 100.0, 2)
  FROM base b
  GROUP BY b.state
  ORDER BY paid_rupees_90d DESC
  LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_state() TO authenticated;
COMMIT;
