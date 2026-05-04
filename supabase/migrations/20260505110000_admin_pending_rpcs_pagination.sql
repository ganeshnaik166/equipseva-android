-- Pagination pass on the founder admin RPCs.
--
-- The two pending-queue RPCs (admin_pending_engineers,
-- admin_pending_seller_verifications) ship today without LIMIT —
-- fine at 100 rows, but at 100K users the queue can hold thousands of
-- pending rows and the unbounded RETURN materialises all of them in
-- memory + serialises to JSON for one round-trip. The mobile client
-- then receives a multi-MB response and the screen ANRs.
--
-- Add `p_limit` (default 50, hard-clamped to [1,200]) + `p_offset`
-- (default 0). Existing call sites pass no args and get the
-- defaults. Future client work should pass explicit pagination so
-- each fetch is bounded.
--
-- DROP + CREATE because Postgres won't let CREATE OR REPLACE change
-- the parameter list. The functions are SECURITY DEFINER + founder-
-- gated so the brief drop window is harmless (only the founder can
-- call them anyway, and CI applies migrations during a maintenance
-- window).

DROP FUNCTION IF EXISTS public.admin_pending_engineers();
DROP FUNCTION IF EXISTS public.admin_pending_seller_verifications();

CREATE OR REPLACE FUNCTION public.admin_pending_engineers(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
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
DECLARE
  v_limit int := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
  v_offset int := GREATEST(0, COALESCE(p_offset, 0));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE = '42501';
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
    ORDER BY e.created_at DESC NULLS LAST
    LIMIT v_limit OFFSET v_offset;
END;
$$;

ALTER FUNCTION public.admin_pending_engineers(int, int) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_pending_engineers(int, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_pending_seller_verifications(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
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
DECLARE
  v_limit int := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
  v_offset int := GREATEST(0, COALESCE(p_offset, 0));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE = '42501';
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
    ORDER BY r.submitted_at DESC
    LIMIT v_limit OFFSET v_offset;
END;
$$;

ALTER FUNCTION public.admin_pending_seller_verifications(int, int) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_pending_seller_verifications(int, int) TO authenticated;
