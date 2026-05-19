-- Round 383 — restore certificates + aadhaar_verified on admin_pending_engineers.
--
-- The original admin_pending_engineers (20260427020000_kyc_docs_signed_urls_and_rls.sql)
-- returned certificates jsonb + aadhaar_verified boolean so the founder
-- KYC queue could surface document signed-URLs via the Kotlin
-- FounderRepository.PendingEngineer.docPaths() helper.
--
-- The v2.1 PR-D11 pagination rewrite (20260505110000) dropped both
-- columns from the RETURNS TABLE while keeping the same function
-- name. The PR-D53 enum-cast fix (20260625120000) preserved the
-- stripped shape. Net effect: the Kotlin dataclass declares the
-- fields with default values (null / false), so the founder's KYC
-- review screen sees zero docs for every pending engineer — the
-- whole verification workflow is gated on documents the UI cannot
-- access.
--
-- Restore the columns. Kotlin dataclass already expects them; this
-- is a strict-additive fix.

DROP FUNCTION IF EXISTS public.admin_pending_engineers(int, int);

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
  certificates jsonb,
  aadhaar_verified boolean,
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
      coalesce(e.experience_years, e.years_experience, 0),
      e.service_radius_km,
      e.city,
      e.state,
      e.certificates,
      coalesce(e.aadhaar_verified, false),
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
