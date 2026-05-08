-- v2.1 PR-D53 — fix admin_pending_engineers enum cast.
--
-- engineers.verification_status was tightened to an enum type. The
-- pagination version of admin_pending_engineers (PR-D11, migration
-- 20260505110000) still selects:
--   coalesce(e.verification_status, 'pending')
-- and declares the return column as text, which Postgres rejects with
--   42804: structure of query does not match function result type
--   DETAIL: Returned type engineer_verification_status does not match
--           expected type text in column 5
-- The KYC queue surface therefore renders "Couldn't load — Something
-- went wrong" the moment a founder taps it. Verified on-device
-- 2026-05-08 e2e QA (founder ganesh1431.dhanavath@gmail.com).
--
-- Fix: cast the column to text before coalesce, mirroring the
-- engineer_public_profile array-cast fix (20260430120000). Function
-- body otherwise unchanged from PR-D11.

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
      coalesce(e.verification_status::text, 'pending'),
      e.experience_years,
      e.service_radius_km,
      e.city,
      e.state,
      e.created_at
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    WHERE coalesce(e.verification_status::text, 'pending') = 'pending'
    ORDER BY e.created_at DESC NULLS LAST
    LIMIT v_limit OFFSET v_offset;
END;
$$;

ALTER FUNCTION public.admin_pending_engineers(int, int) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_pending_engineers(int, int) TO authenticated;
