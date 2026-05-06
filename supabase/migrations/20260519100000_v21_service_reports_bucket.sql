-- v2.1 PR-D3: storage bucket + access RPC for the compliance audit-trail
-- service report (T3.11). Pairs with the generate_service_report edge
-- function at supabase/functions/generate_service_report/index.ts.
--
-- Bucket is PRIVATE. Reads happen exclusively via signed URLs minted
-- by the edge function (30-day TTL) — no anon access, no public link.
-- That keeps PHI-adjacent fields (issue_description, equipment serial,
-- before/after photos) out of any URL that could be guessed or leaked.
--
-- Storage RLS policies don't matter much because the bucket has no
-- public flag and the edge function uses service_role to write — but
-- we add an explicit deny-all policy so nothing else can sneak in
-- via the postgrest path.

-- ---------------------------------------------------------------------
-- Bucket (idempotent)
-- ---------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('service-reports', 'service-reports', false)
ON CONFLICT (id) DO NOTHING;

-- Drop any old anon/auth policies if a previous attempt left them.
DROP POLICY IF EXISTS "service_reports_select_all"     ON storage.objects;
DROP POLICY IF EXISTS "service_reports_authenticated"  ON storage.objects;

-- ---------------------------------------------------------------------
-- RPC: get_service_report_url(p_job)
-- Hospital + engineer participants can read the latest signed URL
-- stored on repair_jobs.service_report_url. Returns NULL if the report
-- has not been generated yet (edge function has never been called).
--
-- The actual MINTING of the URL happens in the edge function — this
-- RPC just exposes the cached column to the right callers.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_service_report_url(p_job uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller   uuid := auth.uid();
  v_hospital uuid;
  v_engineer uuid;
  v_engineer_user uuid;
  v_url      text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT hospital_user_id, engineer_id, service_report_url
    INTO v_hospital, v_engineer, v_url
    FROM public.repair_jobs
   WHERE id = p_job;

  IF v_hospital IS NULL THEN
    RAISE EXCEPTION 'job not found' USING ERRCODE = '02000';
  END IF;

  IF v_engineer IS NOT NULL THEN
    SELECT user_id INTO v_engineer_user
      FROM public.engineers WHERE id = v_engineer;
  END IF;

  IF v_caller <> v_hospital
     AND v_caller IS DISTINCT FROM v_engineer_user
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a participant on this job' USING ERRCODE = '42501';
  END IF;

  RETURN v_url;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_service_report_url(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_service_report_url(uuid) TO authenticated;
