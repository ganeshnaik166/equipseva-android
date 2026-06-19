BEGIN;
DROP FUNCTION IF EXISTS public.founder_evidence_ledger_65b_summary();
CREATE OR REPLACE FUNCTION public.founder_evidence_ledger_65b_summary()
RETURNS TABLE (
  total_evidence_rows         bigint,
  rows_today                  bigint,
  rows_7d                     bigint,
  rows_30d                    bigint,
  distinct_evidence_kinds     bigint,
  distinct_source_jobs        bigint,
  top_kind                    text,
  top_kind_count              bigint,
  pved_pdf_count              bigint,
  dsr_pdf_count               bigint,
  photo_before_count          bigint,
  photo_after_count           bigint,
  photo_during_count          bigint,
  signature_engineer_count    bigint,
  signature_hospital_count    bigint,
  chat_archive_count          bigint,
  amc_affidavit_count         bigint,
  gst_invoice_pdf_count       bigint,
  tds_certificate_count       bigint,
  voice_note_count            bigint,
  job_completion_otp_count    bigint,
  parts_receipt_count         bigint,
  producer_engineer_count     bigint,
  producer_hospital_count     bigint,
  producer_system_count       bigint,
  producer_founder_count      bigint,
  total_bytes_stored          bigint,
  avg_bytes_per_row           bigint,
  duplicate_hash_collisions   bigint,
  unknown_platform_count      bigint,
  jobs_missing_photo_before   bigint,
  jobs_missing_photo_after    bigint,
  jobs_with_full_photo_set    bigint,
  newest_row_at               timestamptz,
  oldest_row_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_top_kind  text;
  v_top_count bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT evidence_kind, cnt INTO v_top_kind, v_top_count
  FROM (
    SELECT evidence_kind, count(*) AS cnt
      FROM public.evidence_ledger
     GROUP BY evidence_kind
     ORDER BY cnt DESC
     LIMIT 1
  ) t;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.evidence_ledger
  ),
  closed_jobs AS (
    SELECT id FROM public.repair_jobs
     WHERE status IN ('completed','closed','resolved')
  ),
  jobs_with_before AS (
    SELECT DISTINCT source_id FROM base
     WHERE source_kind = 'repair_job' AND evidence_kind = 'photo_before'
  ),
  jobs_with_after AS (
    SELECT DISTINCT source_id FROM base
     WHERE source_kind = 'repair_job' AND evidence_kind = 'photo_after'
  ),
  dup AS (
    SELECT content_sha256 FROM base
     GROUP BY content_sha256
    HAVING count(*) > 1
  )
  SELECT
    (SELECT count(*) FROM base)::bigint,
    (SELECT count(*) FROM base WHERE (created_at AT TIME ZONE 'Asia/Kolkata')::date = (now() AT TIME ZONE 'Asia/Kolkata')::date)::bigint,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '7 days')::bigint,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '30 days')::bigint,
    (SELECT count(DISTINCT evidence_kind) FROM base)::bigint,
    (SELECT count(DISTINCT source_id) FROM base WHERE source_kind = 'repair_job')::bigint,
    COALESCE(v_top_kind, 'none')::text,
    COALESCE(v_top_count, 0)::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'pved_pdf')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'dsr_pdf')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'photo_before')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'photo_after')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'photo_during')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'signature_engineer')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'signature_hospital')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'chat_archive')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'amc_affidavit')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'gst_invoice_pdf')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'tds_certificate')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'voice_note')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'job_completion_otp')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'parts_receipt')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'engineer')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'hospital')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'system')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'founder')::bigint,
    COALESCE((SELECT sum(content_size_bytes) FROM base), 0)::bigint,
    COALESCE((SELECT (sum(content_size_bytes) / NULLIF(count(*),0))::bigint FROM base), 0)::bigint,
    (SELECT count(*) FROM dup)::bigint,
    (SELECT count(*) FROM base WHERE platform_version = 'unknown' OR platform_version IS NULL)::bigint,
    (SELECT count(*) FROM closed_jobs cj
       WHERE cj.id NOT IN (SELECT source_id FROM jobs_with_before))::bigint,
    (SELECT count(*) FROM closed_jobs cj
       WHERE cj.id NOT IN (SELECT source_id FROM jobs_with_after))::bigint,
    (SELECT count(*) FROM closed_jobs cj
       WHERE cj.id IN (SELECT source_id FROM jobs_with_before)
         AND cj.id IN (SELECT source_id FROM jobs_with_after))::bigint,
    (SELECT max(created_at) FROM base),
    (SELECT min(created_at) FROM base);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_evidence_ledger_65b_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_evidence_ledger_65b_summary() TO authenticated;
COMMIT;
