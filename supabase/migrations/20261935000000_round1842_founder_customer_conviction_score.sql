BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_customer_conviction_scores_r1842 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conviction_score int NOT NULL CHECK (conviction_score BETWEEN 1 AND 10),
  conviction_reason_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_conviction_audit_log_r1842 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.founder_customer_conviction_scores_r1842(id) ON DELETE CASCADE,
  prior_score int,
  new_score int NOT NULL,
  change_reason text,
  changed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conviction_scores_r1842_hospital ON public.founder_customer_conviction_scores_r1842(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_conviction_scores_r1842_status ON public.founder_customer_conviction_scores_r1842(status);
CREATE INDEX IF NOT EXISTS idx_conviction_scores_r1842_recorded ON public.founder_customer_conviction_scores_r1842(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_conviction_audit_r1842_score ON public.founder_conviction_audit_log_r1842(score_id);
CREATE INDEX IF NOT EXISTS idx_conviction_audit_r1842_changed ON public.founder_conviction_audit_log_r1842(changed_at DESC);

ALTER TABLE public.founder_customer_conviction_scores_r1842 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_conviction_audit_log_r1842 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_conviction_scores_r1842 ON public.founder_customer_conviction_scores_r1842;
CREATE POLICY founder_all_conviction_scores_r1842 ON public.founder_customer_conviction_scores_r1842
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_conviction_audit_r1842 ON public.founder_conviction_audit_log_r1842;
CREATE POLICY founder_all_conviction_audit_r1842 ON public.founder_conviction_audit_log_r1842
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_scores
CREATE OR REPLACE FUNCTION public.list_conviction_scores_r1842()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  conviction_score int,
  conviction_reason_md text,
  recorded_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.hospital_user_id, p.email, s.conviction_score,
           s.conviction_reason_md, s.recorded_at, s.status
    FROM public.founder_customer_conviction_scores_r1842 s
    LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
    ORDER BY s.recorded_at DESC;
END $$;

-- 2. set_score
CREATE OR REPLACE FUNCTION public.set_conviction_score_r1842(
  p_hospital_user_id uuid,
  p_conviction_score int,
  p_conviction_reason_md text,
  p_change_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id uuid;
  v_prior_id uuid;
  v_prior_score int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_conviction_score < 1 OR p_conviction_score > 10 THEN
    RAISE EXCEPTION 'conviction_score must be 1-10';
  END IF;

  SELECT id, conviction_score INTO v_prior_id, v_prior_score
  FROM public.founder_customer_conviction_scores_r1842
  WHERE hospital_user_id = p_hospital_user_id AND status = 'current'
  ORDER BY recorded_at DESC LIMIT 1;

  IF v_prior_id IS NOT NULL THEN
    UPDATE public.founder_customer_conviction_scores_r1842
    SET status = 'superseded', updated_at = now()
    WHERE id = v_prior_id;
  END IF;

  INSERT INTO public.founder_customer_conviction_scores_r1842(
    hospital_user_id, conviction_score, conviction_reason_md, status
  ) VALUES (
    p_hospital_user_id, p_conviction_score, p_conviction_reason_md, 'current'
  ) RETURNING id INTO v_new_id;

  INSERT INTO public.founder_conviction_audit_log_r1842(
    score_id, prior_score, new_score, change_reason
  ) VALUES (
    v_new_id, v_prior_score, p_conviction_score, p_change_reason
  );

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'set_conviction_score_r1842',
    jsonb_build_object(
      'score_id', v_new_id,
      'hospital_user_id', p_hospital_user_id,
      'prior_score', v_prior_score,
      'new_score', p_conviction_score,
      'change_reason', p_change_reason
    )
  );

  RETURN v_new_id;
END $$;

-- 3. list_audit_log
CREATE OR REPLACE FUNCTION public.list_conviction_audit_log_r1842()
RETURNS TABLE(
  id uuid,
  score_id uuid,
  hospital_user_id uuid,
  hospital_email text,
  prior_score int,
  new_score int,
  change_reason text,
  changed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.score_id, s.hospital_user_id, p.email,
           a.prior_score, a.new_score, a.change_reason, a.changed_at
    FROM public.founder_conviction_audit_log_r1842 a
    LEFT JOIN public.founder_customer_conviction_scores_r1842 s ON s.id = a.score_id
    LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
    ORDER BY a.changed_at DESC
    LIMIT 200;
END $$;

-- 4. conviction_distribution
CREATE OR REPLACE FUNCTION public.conviction_distribution_r1842()
RETURNS TABLE(
  bucket text,
  hospital_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bucket,
           (COUNT(s.id) FILTER (
             WHERE s.status = 'current'
               AND CASE b.bucket
                     WHEN 'low (1-3)' THEN s.conviction_score BETWEEN 1 AND 3
                     WHEN 'medium (4-6)' THEN s.conviction_score BETWEEN 4 AND 6
                     WHEN 'high (7-8)' THEN s.conviction_score BETWEEN 7 AND 8
                     WHEN 'champion (9-10)' THEN s.conviction_score BETWEEN 9 AND 10
                   END
           ))::int AS hospital_count
    FROM (VALUES ('low (1-3)'),('medium (4-6)'),('high (7-8)'),('champion (9-10)')) AS b(bucket)
    LEFT JOIN public.founder_customer_conviction_scores_r1842 s ON true
    GROUP BY b.bucket
    ORDER BY b.bucket;
END $$;

-- 5. top_conviction_hospitals
CREATE OR REPLACE FUNCTION public.top_conviction_hospitals_r1842()
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_email text,
  conviction_score int,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.hospital_user_id, p.email, s.conviction_score, s.recorded_at
    FROM public.founder_customer_conviction_scores_r1842 s
    LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
    WHERE s.status = 'current'
    ORDER BY s.conviction_score DESC, s.recorded_at DESC
    LIMIT 20;
END $$;

-- 6. recent_changes
CREATE OR REPLACE FUNCTION public.recent_conviction_changes_r1842()
RETURNS TABLE(
  id uuid,
  hospital_email text,
  prior_score int,
  new_score int,
  delta int,
  change_reason text,
  changed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, p.email, a.prior_score, a.new_score,
           (a.new_score - COALESCE(a.prior_score, a.new_score))::int AS delta,
           a.change_reason, a.changed_at
    FROM public.founder_conviction_audit_log_r1842 a
    LEFT JOIN public.founder_customer_conviction_scores_r1842 s ON s.id = a.score_id
    LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
    ORDER BY a.changed_at DESC
    LIMIT 30;
END $$;

-- 7. founder_avg_conviction
CREATE OR REPLACE FUNCTION public.founder_avg_conviction_r1842()
RETURNS TABLE(
  avg_conviction numeric,
  total_hospitals_scored int,
  total_score_events int,
  high_conviction_count int,
  low_conviction_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      ROUND(AVG(s.conviction_score) FILTER (WHERE s.status = 'current')::numeric, 2) AS avg_conviction,
      (COUNT(DISTINCT s.hospital_user_id) FILTER (WHERE s.status = 'current'))::int AS total_hospitals_scored,
      (COUNT(s.id))::int AS total_score_events,
      (COUNT(*) FILTER (WHERE s.status = 'current' AND s.conviction_score >= 7))::int AS high_conviction_count,
      (COUNT(*) FILTER (WHERE s.status = 'current' AND s.conviction_score <= 3))::int AS low_conviction_count
    FROM public.founder_customer_conviction_scores_r1842 s;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_conviction_scores_r1842() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_conviction_score_r1842(uuid, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_conviction_audit_log_r1842() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.conviction_distribution_r1842() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_conviction_hospitals_r1842() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_conviction_changes_r1842() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_avg_conviction_r1842() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_conviction_scores_r1842() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_conviction_score_r1842(uuid, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_conviction_audit_log_r1842() TO authenticated;
GRANT EXECUTE ON FUNCTION public.conviction_distribution_r1842() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_conviction_hospitals_r1842() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_conviction_changes_r1842() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_avg_conviction_r1842() TO authenticated;

COMMIT;