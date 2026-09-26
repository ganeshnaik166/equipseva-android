-- Round 3821: authorize evidence before reading or deduplicating it.
--
-- The only shipped client writer is Android r3820: repair_job before/after
-- photos at repair-photos/<auth uid>/<job uuid>/<filename>. Restrict that
-- client contract without changing its RPC signature. Other evidence kinds
-- remain available to trusted service-role producers; r3818/r3819 internal
-- canonical GPS/signature writers are unchanged and remain uncallable by users.
--
-- Assignment is repair_jobs.engineer_id -> engineers.user_id, as in r3818's
-- attendance writer. An old accepted bid must not restore a cleared/reassigned
-- engineer's access. Registration locks the job and object until commit, so
-- assignment/object mutation cannot race the authorization check.
--
-- This fixes future access/writes; it neither validates historical ledger
-- rows nor verifies client-supplied hashes against remote bytes. Existing
-- records need a separately authorized integrity review. Object immutability,
-- capture authenticity and upload/attach reconciliation remain separate work.
BEGIN;

CREATE OR REPLACE FUNCTION public.register_evidence(
  p_evidence_kind text,
  p_source_kind text,
  p_source_id uuid,
  p_content_sha256 text,
  p_content_size_bytes bigint,
  p_storage_url text DEFAULT NULL,
  p_producer_kind text DEFAULT 'system',
  p_captured_at timestamptz DEFAULT now(),
  p_platform_version text DEFAULT 'unknown',
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_service boolean := coalesce(auth.role() = 'service_role', false);
  v_job public.repair_jobs%ROWTYPE;
  v_engineer_user uuid;
  v_parts text[];
  v_object_path text;
  v_object storage.objects%ROWTYPE;
  v_producer_kind text := p_producer_kind;
  v_metadata jsonb := p_metadata;
  v_existing public.evidence_ledger%ROWTYPE;
  v_id uuid;
BEGIN
  IF NOT v_service AND v_actor IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_content_sha256 IS NULL OR p_content_sha256 !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'content_sha256 must be 64-char lowercase hex' USING ERRCODE = '22023';
  END IF;
  IF p_content_size_bytes IS NULL OR p_content_size_bytes <= 0 THEN
    RAISE EXCEPTION 'content_size_bytes required + positive' USING ERRCODE = '22023';
  END IF;

  IF NOT v_service THEN
    -- Authenticate/authorize every retry BEFORE looking up an existing id.
    -- Reject forged server-only kinds rather than relabeling their contents.
    IF p_source_kind IS DISTINCT FROM 'repair_job'
       OR p_evidence_kind IS NULL
       OR p_evidence_kind NOT IN ('photo_before', 'photo_after')
       OR p_producer_kind IS DISTINCT FROM 'engineer' THEN
      RAISE EXCEPTION 'evidence_kind_not_authorized' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_job FROM public.repair_jobs
     WHERE id = p_source_id FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
    END IF;
    SELECT e.user_id INTO v_engineer_user FROM public.engineers e
     WHERE e.id = v_job.engineer_id FOR SHARE;
    IF v_engineer_user IS NULL OR v_engineer_user IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION 'not_assigned_engineer' USING ERRCODE = '42501';
    END IF;
    v_producer_kind := 'engineer';

    -- Match the current Android path, not a URL, alternate bucket, traversal,
    -- nested directory, other user's prefix or an object from a different job.
    v_parts := string_to_array(p_storage_url, '/');
    IF p_storage_url IS NULL OR array_length(v_parts, 1) IS DISTINCT FROM 4
       OR v_parts[1] IS DISTINCT FROM 'repair-photos'
       OR v_parts[2] IS DISTINCT FROM v_actor::text
       OR v_parts[3] IS DISTINCT FROM p_source_id::text
       OR v_parts[4] IS NULL OR v_parts[4] IN ('.', '..')
       OR v_parts[4] !~ '^[A-Za-z0-9._-]+$' THEN
      RAISE EXCEPTION 'evidence_object_not_authorized' USING ERRCODE = '42501';
    END IF;
    v_object_path := v_parts[2] || '/' || v_parts[3] || '/' || v_parts[4];
    IF NOT coalesce(
      CASE p_evidence_kind
        WHEN 'photo_before' THEN v_job.before_photos @> ARRAY[v_object_path]
        WHEN 'photo_after' THEN v_job.after_photos @> ARRAY[v_object_path]
      END, false
    ) THEN
      RAISE EXCEPTION 'evidence_photo_not_attached' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_object FROM storage.objects
     WHERE bucket_id = 'repair-photos' AND name = v_object_path FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'evidence_object_not_found' USING ERRCODE = '02000';
    END IF;
    -- owner_id is current Storage's owner; owner is its legacy equivalent.
    -- JSON field access supports both schema generations, without treating
    -- a missing owner as evidence of ownership. Prefer owner_id when present.
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
    -- These markers are server-owned; the digest and captured_at are still
    -- client assertions. Do not turn an upload receipt into a verified hash.
    IF p_metadata IS NOT NULL AND jsonb_typeof(p_metadata) <> 'object' THEN
      RAISE EXCEPTION 'evidence_metadata_must_be_object' USING ERRCODE = '22023';
    END IF;
    v_metadata := coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'registration_authority', 'assigned_engineer',
      'hash_verification', 'client_asserted',
      'storage_object_id', v_object.id
    );
  END IF;

  INSERT INTO public.evidence_ledger (
    evidence_kind, source_kind, source_id, content_sha256,
    content_size_bytes, storage_url, producer_user_id, producer_kind,
    captured_at, platform_version, metadata
  ) VALUES (
    p_evidence_kind, p_source_kind, p_source_id, p_content_sha256,
    p_content_size_bytes, p_storage_url, v_actor, v_producer_kind,
    coalesce(p_captured_at, now()), coalesce(p_platform_version, 'unknown'), v_metadata
  )
  ON CONFLICT ON CONSTRAINT evidence_ledger_uniq DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT * INTO v_existing FROM public.evidence_ledger
     WHERE evidence_kind = p_evidence_kind AND source_kind = p_source_kind
       AND source_id = p_source_id AND content_sha256 = p_content_sha256;
    -- The uniqueness key predates ownership. Never claim another producer's
    -- record (including an orphaned producer) as a successful client retry.
    IF NOT v_service AND (
      v_existing.producer_user_id IS DISTINCT FROM v_actor
      OR v_existing.producer_kind IS DISTINCT FROM v_producer_kind
      OR v_existing.storage_url IS DISTINCT FROM p_storage_url
      OR v_existing.content_size_bytes IS DISTINCT FROM p_content_size_bytes
    ) THEN
      RAISE EXCEPTION 'evidence_registration_conflict' USING ERRCODE = '42501';
    END IF;
    v_id := v_existing.id;
  END IF;
  IF v_id IS NULL THEN
    -- A concurrent administrative delete or unusual isolation level may hide
    -- the conflict row. Never emit a false success; caller can safely retry.
    RAISE EXCEPTION 'evidence_registration_retry' USING ERRCODE = '40001';
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_evidence_hash(
  p_evidence_id uuid,
  p_content_sha256 text
)
RETURNS TABLE(
  matches boolean, ledger_id uuid, evidence_kind text,
  captured_at timestamptz, producer_user_id uuid, producer_kind text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_service boolean := coalesce(auth.role() = 'service_role', false);
  v_row public.evidence_ledger%ROWTYPE;
BEGIN
  IF NOT v_service AND v_actor IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_content_sha256 IS NULL OR p_content_sha256 !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'content_sha256 must be 64-char hex' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_row FROM public.evidence_ledger WHERE id = p_evidence_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'evidence_not_found' USING ERRCODE = '02000';
  END IF;
  -- Preserve producer/founder reads and trusted service reads explicitly.
  -- NULL producer after account deletion is never ordinary-user authority.
  IF NOT v_service AND NOT coalesce(public.is_founder(), false)
     AND v_row.producer_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  matches := v_row.content_sha256 = p_content_sha256;
  ledger_id := v_row.id;
  evidence_kind := v_row.evidence_kind;
  captured_at := v_row.captured_at;
  producer_user_id := v_row.producer_user_id;
  producer_kind := v_row.producer_kind;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.evidence_for_repair_job(p_repair_job_id uuid)
RETURNS TABLE(
  id uuid, evidence_kind text, content_sha256 text,
  content_size_bytes bigint, storage_url text, producer_user_id uuid,
  producer_kind text, captured_at timestamptz, metadata jsonb, created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_hospital uuid;
  v_engineer uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  SELECT rj.hospital_user_id, e.user_id INTO v_hospital, v_engineer
    FROM public.repair_jobs rj
    LEFT JOIN public.engineers e ON e.id = rj.engineer_id
   WHERE rj.id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
  END IF;
  IF NOT coalesce(public.is_founder(), false)
     AND v_caller IS DISTINCT FROM v_hospital
     AND v_caller IS DISTINCT FROM v_engineer THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT e.id, e.evidence_kind, e.content_sha256, e.content_size_bytes,
         e.storage_url, e.producer_user_id, e.producer_kind,
         e.captured_at, e.metadata, e.created_at
    FROM public.evidence_ledger e
   WHERE e.source_kind = 'repair_job' AND e.source_id = p_repair_job_id
   ORDER BY e.captured_at ASC NULLS LAST, e.created_at ASC;
END;
$$;

-- Re-state explicit RPC ACLs; Supabase default EXECUTE privileges must never
-- expose these security-definer entrypoints to anonymous callers.
REVOKE ALL ON FUNCTION public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.verify_evidence_hash(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_evidence_hash(uuid,text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.evidence_for_repair_job(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.evidence_for_repair_job(uuid) TO authenticated, service_role;

COMMIT;
