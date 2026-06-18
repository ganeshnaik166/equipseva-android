BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_recent_list();
CREATE OR REPLACE FUNCTION public.founder_payouts_recent_list()
RETURNS TABLE (
  payout_id        uuid,
  engineer_name    text,
  amount_rupees    numeric,
  status           text,
  mode             text,
  utr              text,
  queued_at        timestamptz,
  processed_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    coalesce(pr.full_name, '(engineer)'),
    round(p.amount_paise::numeric / 100.0, 2),
    p.status,
    coalesce(p.mode, '(unknown)'),
    p.utr,
    p.queued_at,
    p.processed_at
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.queued_at >= now() - interval '7 days'
  ORDER BY p.queued_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_recent_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_recent_list() TO authenticated;
COMMIT;
