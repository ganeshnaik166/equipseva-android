-- Founder admin RPC for the Integrity Flags page.
-- Returns recent failed Play-Integrity attestations so the founder can
-- spot rooted devices, repackaged APKs, or excessive failure rates.

CREATE OR REPLACE FUNCTION public.admin_integrity_flags(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  check_id uuid,
  user_id uuid,
  user_email text,
  action text,
  device_verdict text,
  app_verdict text,
  licensing_verdict text,
  pass boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      d.id,
      d.user_id,
      p.email,
      d.action,
      d.device_verdict,
      d.app_verdict,
      d.licensing_verdict,
      d.pass,
      d.created_at
    FROM public.device_integrity_checks d
    LEFT JOIN public.profiles p ON p.id = d.user_id
    ORDER BY d.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_integrity_flags(int) TO authenticated;
