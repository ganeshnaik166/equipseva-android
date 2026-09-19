-- The attachment and its evidence receipt must commit together. Client-side
-- array replacement can lose concurrent uploads, and a separate registration
-- request can leave an attached photo without a durable evidence record.
BEGIN;
SET LOCAL search_path = pg_catalog, pg_temp;

-- The delegated writer must retain its authorization-before-deduplication
-- contract. Refuse an older or unreviewed implementation rather than silently
-- accepting its different conflict or provenance semantics.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    WHERE p.oid = to_regprocedure('public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb)')
      AND p.prosecdef AND p.provolatile = 'v'
      AND p.prokind = 'f' AND NOT p.proretset
      AND p.prorettype = 'uuid'::regtype
      AND p.proargtypes::text = '25 25 2950 25 20 25 25 1184 25 3802'
      AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
      AND p.proowner = current_user::regrole::oid
      AND p.proconfig = ARRAY['search_path=public, pg_temp']::text[]
      AND md5(replace(p.prosrc, E'\r\n', E'\n')) = 'f615f86834111686c7d089ca82db0990'
      AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
      AND has_function_privilege('service_role', p.oid, 'EXECUTE')
      AND NOT EXISTS (
        SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
        WHERE a.grantee NOT IN (p.proowner, 'authenticated'::regrole::oid, 'service_role'::regrole::oid)
           OR a.privilege_type <> 'EXECUTE'
           OR (a.is_grantable AND a.grantee <> p.proowner)
      )
  ) THEN
    RAISE EXCEPTION 'repair_photo_registration_dependency_mismatch'
      USING ERRCODE = '55000';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    WHERE p.oid = to_regprocedure('public.finalize_repair_photo(uuid,text,text,text,bigint,timestamptz,text,jsonb)')
      AND (p.proowner <> current_user::regrole::oid OR EXISTS (
        SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
        WHERE a.grantee NOT IN (p.proowner, 'authenticated'::regrole::oid)
           OR a.privilege_type <> 'EXECUTE'
           OR (a.is_grantable AND a.grantee <> p.proowner)
      ))
  ) THEN
    RAISE EXCEPTION 'repair_photo_finalizer_existing_contract_mismatch'
      USING ERRCODE = '55000';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_repair_photo(
  p_job_id uuid,
  p_evidence_kind text,
  p_storage_url text,
  p_content_sha256 text,
  p_content_size_bytes bigint,
  p_captured_at timestamptz DEFAULT now(),
  p_platform_version text DEFAULT 'unknown',
  p_metadata jsonb DEFAULT NULL
)
RETURNS TABLE(ledger_id uuid, attachment_path text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_job public.repair_jobs%ROWTYPE;
  v_engineer_user uuid;
  v_parts text[];
  v_object_path text;
  v_object storage.objects%ROWTYPE;
BEGIN
  -- This is an engineer-client operation, with no trusted-producer bypass.
  IF v_actor IS NULL OR auth.role() IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_evidence_kind IS NULL OR p_evidence_kind NOT IN ('photo_before', 'photo_after') THEN
    RAISE EXCEPTION 'evidence_kind_not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_content_sha256 IS NULL OR p_content_sha256 !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'content_sha256 must be 64-char lowercase hex' USING ERRCODE = '22023';
  END IF;
  IF p_content_size_bytes IS NULL OR p_content_size_bytes <= 0 THEN
    RAISE EXCEPTION 'content_size_bytes required + positive' USING ERRCODE = '22023';
  END IF;

  -- Acquire the strongest job lock first. Taking SHARE in the delegated
  -- writer and upgrading later would allow competing finalizers to deadlock.
  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_job_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
  END IF;
  SELECT e.user_id INTO v_engineer_user FROM public.engineers e
    WHERE e.id = v_job.engineer_id FOR SHARE;
  IF v_engineer_user IS NULL OR v_engineer_user IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'not_assigned_engineer' USING ERRCODE = '42501';
  END IF;

  v_parts := string_to_array(p_storage_url, '/');
  IF p_storage_url IS NULL OR array_length(v_parts, 1) IS DISTINCT FROM 4
     OR v_parts[1] IS DISTINCT FROM 'repair-photos'
     OR v_parts[2] IS DISTINCT FROM v_actor::text
     OR v_parts[3] IS DISTINCT FROM p_job_id::text
     OR v_parts[4] IS NULL OR v_parts[4] IN ('.', '..')
     OR v_parts[4] !~ '^[A-Za-z0-9._-]+$' THEN
    RAISE EXCEPTION 'evidence_object_not_authorized' USING ERRCODE = '42501';
  END IF;
  v_object_path := v_parts[2] || '/' || v_parts[3] || '/' || v_parts[4];
  SELECT * INTO v_object FROM storage.objects
    WHERE bucket_id = 'repair-photos' AND name = v_object_path FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'evidence_object_not_found' USING ERRCODE = '02000';
  END IF;
  IF coalesce(to_jsonb(v_object)->>'owner_id', to_jsonb(v_object)->>'owner')
     IS DISTINCT FROM v_actor::text THEN
    RAISE EXCEPTION 'evidence_object_not_authorized' USING ERRCODE = '42501';
  END IF;
  IF NOT coalesce(
    CASE WHEN v_object.metadata->>'size' ~ '^[0-9]+$'
      THEN (v_object.metadata->>'size')::numeric = p_content_size_bytes
      ELSE false
    END, false
  ) THEN
    RAISE EXCEPTION 'evidence_object_size_mismatch' USING ERRCODE = '22023';
  END IF;

  -- Use the locked row's current array and preserve every other attachment.
  -- An authorized retry can restore a removed attachment; assignment and
  -- object authority are still checked before returning an existing ledger ID.
  IF p_evidence_kind = 'photo_before' THEN
    IF NOT coalesce(v_job.before_photos @> ARRAY[v_object_path], false) THEN
      UPDATE public.repair_jobs
        SET before_photos = coalesce(before_photos, '{}'::text[]) || ARRAY[v_object_path]
        WHERE id = p_job_id;
    END IF;
  ELSE
    IF NOT coalesce(v_job.after_photos @> ARRAY[v_object_path], false) THEN
      UPDATE public.repair_jobs
        SET after_photos = coalesce(after_photos, '{}'::text[]) || ARRAY[v_object_path]
        WHERE id = p_job_id;
    END IF;
  END IF;

  -- Do not catch registration errors: conflict/validation failures must roll
  -- back the append too. The digest and capture time remain client assertions.
  RETURN QUERY SELECT public.register_evidence(
    p_evidence_kind, 'repair_job', p_job_id, p_content_sha256,
    p_content_size_bytes, p_storage_url, 'engineer', p_captured_at,
    p_platform_version, p_metadata
  ), v_object_path;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_repair_photo(uuid,text,text,text,bigint,timestamptz,text,jsonb)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.finalize_repair_photo(uuid,text,text,text,bigint,timestamptz,text,jsonb)
  TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    WHERE p.oid = to_regprocedure('public.finalize_repair_photo(uuid,text,text,text,bigint,timestamptz,text,jsonb)')
      AND p.proowner = current_user::regrole::oid
      AND p.prosecdef AND p.provolatile = 'v' AND p.proretset AND p.prokind = 'f'
      AND p.proargtypes::text = '2950 25 25 25 20 1184 25 3802'
      AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
      AND pg_get_function_result(p.oid) = 'TABLE(ledger_id uuid, attachment_path text)'
      AND p.proconfig = ARRAY['search_path=public, pg_temp']::text[]
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
      AND NOT has_function_privilege('service_role', p.oid, 'EXECUTE')
      AND NOT EXISTS (
        SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
        WHERE a.grantee NOT IN (p.proowner, 'authenticated'::regrole::oid)
           OR a.privilege_type <> 'EXECUTE'
           OR (a.is_grantable AND a.grantee <> p.proowner)
      )
  ) THEN
    RAISE EXCEPTION 'repair_photo_finalizer_contract_mismatch' USING ERRCODE = '55000';
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
