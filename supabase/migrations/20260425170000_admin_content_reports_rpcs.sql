-- Founder admin RPCs for the content_reports queue.
--
-- Reuses public.is_founder(); each RPC is SECURITY DEFINER and raises
-- 'not_founder' (SQLSTATE 42501) when the caller is not the pinned founder
-- email. Mirrors the pattern in 20260425100000_founder_admin_rpcs.sql.

CREATE OR REPLACE FUNCTION public.admin_pending_reports()
RETURNS TABLE (
  report_id uuid,
  reporter_user_id uuid,
  reporter_name text,
  target_type text,
  target_id text,
  reason text,
  notes text,
  status text,
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
      r.id,
      r.reporter_user_id,
      coalesce(p.full_name, p.email, '(unnamed)'),
      r.target_type,
      r.target_id,
      r.reason,
      r.notes,
      r.status,
      r.created_at
    FROM public.content_reports r
    LEFT JOIN public.profiles p ON p.id = r.reporter_user_id
    WHERE r.status = 'pending'
    ORDER BY r.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_pending_reports() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  IF p_status NOT IN ('reviewed','actioned','dismissed') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023';
  END IF;
  UPDATE public.content_reports
  SET status = p_status,
      reviewed_at = now(),
      reviewed_by = auth.uid()
  WHERE id = p_report_id
    AND status = 'pending';
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text) TO authenticated;
