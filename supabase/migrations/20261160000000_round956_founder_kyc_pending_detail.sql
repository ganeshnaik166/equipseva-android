BEGIN;
DROP FUNCTION IF EXISTS public.founder_kyc_pending_detail();
CREATE OR REPLACE FUNCTION public.founder_kyc_pending_detail()
RETURNS TABLE (
  user_id          uuid,
  display_name     text,
  state            text,
  city             text,
  verification_status text,
  signup_at        timestamptz,
  days_pending     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    e.user_id,
    coalesce(p.full_name, '(engineer)'),
    coalesce(nullif(trim(p.state), ''), '—'),
    coalesce(nullif(trim(p.city), ''), '—'),
    e.verification_status,
    e.created_at,
    round(extract(epoch FROM (now() - e.created_at)) / 86400.0, 1)::numeric
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.verification_status IN ('pending', 'in_review', 'rejected')
  ORDER BY e.created_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_kyc_pending_detail() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_kyc_pending_detail() TO authenticated;
COMMIT;
