-- Founder admin RPCs.
--
-- Reuses public.is_founder() (added in 20260425090000). Each RPC is
-- SECURITY DEFINER and raises 'not_founder' (SQLSTATE 42501) when the
-- caller is not the pinned founder email. The client maps that error to
-- a "you're not authorised" message.

CREATE OR REPLACE FUNCTION public.admin_pending_engineers()
RETURNS TABLE (
  user_id uuid,
  full_name text,
  email text,
  phone text,
  verification_status text,
  experience_years int,
  service_radius_km int,
  city text,
  state text,
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
      e.user_id,
      coalesce(p.full_name, '(unnamed)'),
      p.email,
      p.phone,
      coalesce(e.verification_status, 'pending'),
      e.experience_years,
      e.service_radius_km,
      e.city,
      e.state,
      e.created_at
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    WHERE coalesce(e.verification_status, 'pending') = 'pending'
    ORDER BY e.created_at DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_pending_engineers() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_engineer_verification(
  p_user_id uuid,
  p_status text,
  p_reason text DEFAULT NULL
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
  IF p_status NOT IN ('pending','verified','rejected') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023';
  END IF;
  UPDATE public.engineers
  SET verification_status = p_status,
      verification_notes = CASE WHEN p_status='rejected' THEN p_reason ELSE NULL END
  WHERE user_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_engineer_verification(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_pending_seller_verifications()
RETURNS TABLE (
  request_id uuid,
  organization_id uuid,
  organization_name text,
  submitted_by uuid,
  submitter_name text,
  gst_number text,
  trade_licence_url text,
  submitted_at timestamptz
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
      r.organization_id,
      o.name,
      r.submitted_by,
      coalesce(p.full_name, p.email, '(unnamed)'),
      r.gst_number,
      r.trade_licence_url,
      r.submitted_at
    FROM public.seller_verification_requests r
    LEFT JOIN public.organizations o ON o.id = r.organization_id
    LEFT JOIN public.profiles p ON p.id = r.submitted_by
    WHERE r.status = 'pending'
    ORDER BY r.submitted_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_pending_seller_verifications() TO authenticated;
