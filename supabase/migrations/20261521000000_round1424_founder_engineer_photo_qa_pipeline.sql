BEGIN;
-- r1420 founder_engineer_photo_qa_pipeline

CREATE TABLE IF NOT EXISTS public.engineer_field_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  repair_job_id uuid,
  photo_kind text NOT NULL CHECK (photo_kind IN ('before','after','equipment_label','parts_used','calibration_chart','warranty_card','hospital_signoff','custom')),
  photo_uri text NOT NULL,
  captured_at timestamptz NOT NULL,
  captured_lat numeric(9,6),
  captured_lng numeric(9,6),
  exif_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  qa_status text NOT NULL DEFAULT 'uploaded' CHECK (qa_status IN ('uploaded','queued_for_review','passed','flagged','rejected','reviewed')),
  qa_score int CHECK (qa_score BETWEEN 0 AND 100),
  qa_reviewer_user_id uuid REFERENCES auth.users(id),
  qa_reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_efp_engineer ON public.engineer_field_photos(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_efp_job ON public.engineer_field_photos(repair_job_id);
CREATE INDEX IF NOT EXISTS idx_efp_status ON public.engineer_field_photos(qa_status);
CREATE INDEX IF NOT EXISTS idx_efp_captured ON public.engineer_field_photos(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_efp_kind ON public.engineer_field_photos(photo_kind);

CREATE TABLE IF NOT EXISTS public.engineer_field_photo_qa_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid NOT NULL REFERENCES public.engineer_field_photos(id) ON DELETE CASCADE,
  flag_kind text NOT NULL CHECK (flag_kind IN ('blurry','wrong_subject','tampered','missing_geotag','duplicate','low_light','unclear_signature','other')),
  flag_severity text NOT NULL CHECK (flag_severity IN ('info','minor','major','critical')),
  notes text,
  flagged_by uuid REFERENCES auth.users(id),
  flagged_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_efpqf_photo ON public.engineer_field_photo_qa_flags(photo_id);
CREATE INDEX IF NOT EXISTS idx_efpqf_kind ON public.engineer_field_photo_qa_flags(flag_kind);
CREATE INDEX IF NOT EXISTS idx_efpqf_severity ON public.engineer_field_photo_qa_flags(flag_severity);
CREATE INDEX IF NOT EXISTS idx_efpqf_flagged ON public.engineer_field_photo_qa_flags(flagged_at DESC);

ALTER TABLE public.engineer_field_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_field_photo_qa_flags ENABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS public.founder_engineer_photo_qa_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_photo_qa_summary()
RETURNS TABLE (
  total_photos int,
  photos_uploaded int,
  photos_queued int,
  photos_passed int,
  photos_flagged int,
  photos_rejected int,
  photos_reviewed int,
  pass_rate_pct numeric,
  flag_rate_pct numeric,
  unique_engineers int,
  unique_jobs int,
  total_flags int,
  critical_flags int,
  major_flags int,
  photos_24h int,
  avg_qa_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH p AS (SELECT * FROM public.engineer_field_photos),
  f AS (SELECT * FROM public.engineer_field_photo_qa_flags)
  SELECT
    (SELECT count(*)::int FROM p),
    (SELECT count(*)::int FROM p WHERE qa_status='uploaded'),
    (SELECT count(*)::int FROM p WHERE qa_status='queued_for_review'),
    (SELECT count(*)::int FROM p WHERE qa_status='passed'),
    (SELECT count(*)::int FROM p WHERE qa_status='flagged'),
    (SELECT count(*)::int FROM p WHERE qa_status='rejected'),
    (SELECT count(*)::int FROM p WHERE qa_status='reviewed'),
    CASE WHEN (SELECT count(*) FROM p WHERE qa_status IN ('passed','flagged','rejected','reviewed'))>0
      THEN round(100.0*(SELECT count(*) FROM p WHERE qa_status='passed')/NULLIF((SELECT count(*) FROM p WHERE qa_status IN ('passed','flagged','rejected','reviewed')),0),2)
      ELSE 0 END,
    CASE WHEN (SELECT count(*) FROM p)>0
      THEN round(100.0*(SELECT count(*) FROM p WHERE qa_status IN ('flagged','rejected'))/NULLIF((SELECT count(*) FROM p),0),2)
      ELSE 0 END,
    (SELECT count(DISTINCT engineer_user_id)::int FROM p),
    (SELECT count(DISTINCT repair_job_id)::int FROM p WHERE repair_job_id IS NOT NULL),
    (SELECT count(*)::int FROM f),
    (SELECT count(*)::int FROM f WHERE flag_severity='critical'),
    (SELECT count(*)::int FROM f WHERE flag_severity='major'),
    (SELECT count(*)::int FROM p WHERE captured_at > now() - interval '24 hours'),
    COALESCE((SELECT round(avg(qa_score)::numeric,2) FROM p WHERE qa_score IS NOT NULL),0);
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_photo_qa_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_photo_qa_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_photos_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_photos_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  photo_id uuid,
  engineer_user_id uuid,
  repair_job_id uuid,
  photo_kind text,
  photo_uri text,
  captured_at timestamptz,
  qa_status text,
  qa_score int,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT id, engineer_user_id, repair_job_id, photo_kind, photo_uri, captured_at, qa_status, qa_score, notes, created_at
  FROM public.engineer_field_photos
  ORDER BY captured_at DESC NULLS LAST, created_at DESC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit,50), 200));
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_photos_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_photos_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_photo_qa_flags_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_photo_qa_flags_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  flag_id uuid,
  photo_id uuid,
  flag_kind text,
  flag_severity text,
  notes text,
  flagged_by uuid,
  flagged_at timestamptz,
  photo_kind text,
  engineer_user_id uuid
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT f.id, f.photo_id, f.flag_kind, f.flag_severity, f.notes, f.flagged_by, f.flagged_at,
         p.photo_kind, p.engineer_user_id
  FROM public.engineer_field_photo_qa_flags f
  LEFT JOIN public.engineer_field_photos p ON p.id = f.photo_id
  ORDER BY f.flagged_at DESC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit,50), 200));
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_photo_qa_flags_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_photo_qa_flags_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_photo_qa_pending_review(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_photo_qa_pending_review(p_limit int DEFAULT 50)
RETURNS TABLE (
  photo_id uuid,
  engineer_user_id uuid,
  repair_job_id uuid,
  photo_kind text,
  captured_at timestamptz,
  age_hours numeric,
  qa_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT id, engineer_user_id, repair_job_id, photo_kind, captured_at,
         round(extract(epoch FROM (now() - captured_at))/3600.0, 2)::numeric AS age_hours,
         qa_status
  FROM public.engineer_field_photos
  WHERE qa_status IN ('uploaded','queued_for_review')
  ORDER BY captured_at ASC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit,50), 200));
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_photo_qa_pending_review(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_photo_qa_pending_review(int) TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_photo_qa_my_photos(int);
CREATE OR REPLACE FUNCTION public.engineer_photo_qa_my_photos(p_limit int DEFAULT 30)
RETURNS TABLE (
  photo_id uuid,
  repair_job_id uuid,
  photo_kind text,
  photo_uri text,
  captured_at timestamptz,
  qa_status text,
  qa_score int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT id, repair_job_id, photo_kind, photo_uri, captured_at, qa_status, qa_score
  FROM public.engineer_field_photos
  WHERE engineer_user_id = v_uid
  ORDER BY captured_at DESC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit,30), 100));
END $$;
REVOKE ALL ON FUNCTION public.engineer_photo_qa_my_photos(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.engineer_photo_qa_my_photos(int) TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_photo_qa_submit_photo(uuid, text, text, timestamptz, numeric, numeric, jsonb, text);
CREATE OR REPLACE FUNCTION public.engineer_photo_qa_submit_photo(
  p_repair_job_id uuid,
  p_photo_kind text,
  p_photo_uri text,
  p_captured_at timestamptz,
  p_captured_lat numeric DEFAULT NULL,
  p_captured_lng numeric DEFAULT NULL,
  p_exif_summary jsonb DEFAULT '{}'::jsonb,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_uid uuid := auth.uid(); v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;
  IF p_photo_kind NOT IN ('before','after','equipment_label','parts_used','calibration_chart','warranty_card','hospital_signoff','custom') THEN
    RAISE EXCEPTION 'invalid photo_kind' USING ERRCODE='22023';
  END IF;
  IF p_photo_uri IS NULL OR length(trim(p_photo_uri))=0 THEN
    RAISE EXCEPTION 'photo_uri required' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.engineer_field_photos(engineer_user_id, repair_job_id, photo_kind, photo_uri, captured_at, captured_lat, captured_lng, exif_summary, qa_status, notes)
  VALUES (v_uid, p_repair_job_id, p_photo_kind, p_photo_uri, coalesce(p_captured_at, now()), p_captured_lat, p_captured_lng, coalesce(p_exif_summary,'{}'::jsonb), 'uploaded', p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.engineer_photo_qa_submit_photo(uuid, text, text, timestamptz, numeric, numeric, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.engineer_photo_qa_submit_photo(uuid, text, text, timestamptz, numeric, numeric, jsonb, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_photo_qa_review(uuid, text, int, text);
CREATE OR REPLACE FUNCTION public.log_founder_photo_qa_review(
  p_photo_id uuid,
  p_new_status text,
  p_qa_score int DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_new_status NOT IN ('passed','flagged','rejected','reviewed') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE='22023';
  END IF;
  IF p_qa_score IS NOT NULL AND (p_qa_score < 0 OR p_qa_score > 100) THEN
    RAISE EXCEPTION 'qa_score out of range' USING ERRCODE='22023';
  END IF;
  UPDATE public.engineer_field_photos
     SET qa_status = p_new_status,
         qa_score = COALESCE(p_qa_score, qa_score),
         qa_reviewer_user_id = v_uid,
         qa_reviewed_at = now(),
         notes = COALESCE(p_notes, notes)
   WHERE id = p_photo_id;
  RETURN p_photo_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_photo_qa_review(uuid, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_photo_qa_review(uuid, text, int, text) TO authenticated;

COMMIT;