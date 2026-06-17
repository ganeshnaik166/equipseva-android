BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_pending_list();
CREATE OR REPLACE FUNCTION public.founder_payouts_pending_list()
RETURNS TABLE (
  payout_id          uuid,
  engineer_user_id   uuid,
  display_name       text,
  amount_rupees      numeric,
  queued_at          timestamptz,
  hours_old          numeric,
  has_method         boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.engineer_user_id,
    coalesce(pr.full_name, '(engineer)'),
    p.amount_rupees,
    p.queued_at,
    round(extract(epoch FROM (now() - p.queued_at)) / 3600.0, 1)::numeric,
    (p.payout_method_id IS NOT NULL)
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.status = 'pending'
  ORDER BY p.queued_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_pending_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_pending_list() TO authenticated;
COMMIT;
