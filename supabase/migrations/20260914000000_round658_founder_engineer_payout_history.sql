BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_payout_history();
CREATE OR REPLACE FUNCTION public.founder_engineer_payout_history()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  paid_30d_rupees   numeric,
  paid_90d_rupees   numeric,
  paid_lifetime     numeric,
  payouts_lifetime  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT p.engineer_user_id, p.amount_paise, p.queued_at, p.status
    FROM public.engineer_payouts p
    WHERE p.status = 'paid'
  )
  SELECT
    b.engineer_user_id,
    coalesce(pr.full_name, '(engineer)'),
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.queued_at >= now() - interval '30 days'), 0)::numeric / 100.0, 2) AS paid_30d_rupees,
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.queued_at >= now() - interval '90 days'), 0)::numeric / 100.0, 2) AS paid_90d_rupees,
    round(coalesce(sum(b.amount_paise), 0)::numeric / 100.0, 2)                                                            AS paid_lifetime,
    count(*)::bigint                                                                                                       AS payouts_lifetime
  FROM base b
  LEFT JOIN public.profiles pr ON pr.id = b.engineer_user_id
  GROUP BY b.engineer_user_id, pr.full_name
  ORDER BY paid_lifetime DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_payout_history() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_payout_history() TO authenticated;
COMMIT;
