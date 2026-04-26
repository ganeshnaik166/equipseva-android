-- Engineer KYC ship-stopper migration:
--  1. SELECT RLS on kyc-docs so a guessed path can't leak another engineer's
--     Aadhaar; founders bypass the gate via is_founder().
--  2. Extend admin_pending_engineers RPC to include the certificates JSONB
--     so the founder review screen can render Open-doc buttons that mint
--     signed URLs from the client.

-- (1) Owner-or-founder SELECT policy on kyc-docs.
DROP POLICY IF EXISTS kyc_docs_owner_select ON storage.objects;
CREATE POLICY kyc_docs_owner_select
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'kyc-docs'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_founder()
    )
  );

-- (2) Update admin_pending_engineers to project the certificates jsonb +
-- aadhaar_verified flag. Wider return shape — add new columns; old callers
-- that ignore them keep working.
DROP FUNCTION IF EXISTS public.admin_pending_engineers();
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
  certificates jsonb,
  aadhaar_verified boolean,
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
    ORDER BY e.created_at DESC NULLS LAST;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_pending_engineers() TO authenticated;
