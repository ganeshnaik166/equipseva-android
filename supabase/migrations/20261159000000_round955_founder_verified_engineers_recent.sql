BEGIN;
DROP FUNCTION IF EXISTS public.founder_verified_engineers_recent();
CREATE OR REPLACE FUNCTION public.founder_verified_engineers_recent()
RETURNS TABLE (
  user_id          uuid,
  display_name     text,
  state            text,
  city             text,
  verified_at      timestamptz,
  signup_to_verified_days numeric
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
    e.verified_at,
    CASE WHEN e.verified_at IS NULL THEN 0::numeric
         ELSE round(extract(epoch FROM (e.verified_at - e.created_at)) / 86400.0, 1)::numeric
    END
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.verification_status = 'verified'
    AND e.verified_at >= now() - interval '30 days'
  ORDER BY e.verified_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_verified_engineers_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_verified_engineers_recent() TO authenticated;
COMMIT;
