BEGIN;
DROP FUNCTION IF EXISTS public.founder_pending_kyc_list();
CREATE OR REPLACE FUNCTION public.founder_pending_kyc_list()
RETURNS TABLE (
  engineer_id     uuid,
  user_id         uuid,
  display_name    text,
  city            text,
  created_at      timestamptz,
  days_waiting    int,
  status          text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.user_id,
    coalesce(p.full_name, '(engineer)'),
    e.city,
    e.created_at,
    (extract(epoch FROM (now() - e.created_at))::int / 86400),
    e.verification_status
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.verification_status = 'pending'
  ORDER BY e.created_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pending_kyc_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pending_kyc_list() TO authenticated;
COMMIT;
