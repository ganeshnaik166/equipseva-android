BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_photo_quality_scores_r2346 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid,
  photo_url text NOT NULL,
  photo_kind text NOT NULL CHECK (photo_kind IN ('before','after','part_serial','nameplate','wiring','env_context')),
  blur_score numeric(5,2) NOT NULL CHECK (blur_score BETWEEN 0 AND 100),
  lighting_score numeric(5,2) NOT NULL CHECK (lighting_score BETWEEN 0 AND 100),
  coverage_score numeric(5,2) NOT NULL CHECK (coverage_score BETWEEN 0 AND 100),
  composite_score numeric(5,2) NOT NULL CHECK (composite_score BETWEEN 0 AND 100),
  verdict text NOT NULL CHECK (verdict IN ('pass','soft_warn','retake_required')),
  retake_reason text,
  scored_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_epqs_r2346_engineer ON public.engineer_photo_quality_scores_r2346(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_epqs_r2346_verdict ON public.engineer_photo_quality_scores_r2346(verdict);
CREATE INDEX IF NOT EXISTS idx_epqs_r2346_scored_at ON public.engineer_photo_quality_scores_r2346(scored_at DESC);

ALTER TABLE public.engineer_photo_quality_scores_r2346 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_epqs_r2346 ON public.engineer_photo_quality_scores_r2346;
CREATE POLICY founder_all_epqs_r2346 ON public.engineer_photo_quality_scores_r2346
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_photo_retake_nudges_r2346 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.engineer_photo_quality_scores_r2346(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  nudge_channel text NOT NULL CHECK (nudge_channel IN ('push','sms','in_app')),
  nudge_text text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  retake_completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eprn_r2346_engineer ON public.engineer_photo_retake_nudges_r2346(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eprn_r2346_sent ON public.engineer_photo_retake_nudges_r2346(sent_at DESC);

ALTER TABLE public.engineer_photo_retake_nudges_r2346 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eprn_r2346 ON public.engineer_photo_retake_nudges_r2346;
CREATE POLICY founder_all_eprn_r2346 ON public.engineer_photo_retake_nudges_r2346
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2346_summary()
RETURNS TABLE(
  total_scored bigint,
  pass_count bigint,
  soft_warn_count bigint,
  retake_required_count bigint,
  avg_composite numeric,
  avg_blur numeric,
  avg_lighting numeric,
  avg_coverage numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE verdict = 'pass')::bigint,
    COUNT(*) FILTER (WHERE verdict = 'soft_warn')::bigint,
    COUNT(*) FILTER (WHERE verdict = 'retake_required')::bigint,
    ROUND(AVG(composite_score)::numeric, 2),
    ROUND(AVG(blur_score)::numeric, 2),
    ROUND(AVG(lighting_score)::numeric, 2),
    ROUND(AVG(coverage_score)::numeric, 2)
  FROM public.engineer_photo_quality_scores_r2346
  WHERE scored_at >= now() - interval '30 days';
END;
$$;

REVOKE ALL ON FUNCTION public.r2346_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2346_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2346_recent_scores(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  engineer_email text,
  repair_job_id uuid,
  photo_kind text,
  blur_score numeric,
  lighting_score numeric,
  coverage_score numeric,
  composite_score numeric,
  verdict text,
  retake_reason text,
  scored_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.repair_job_id, s.photo_kind, s.blur_score, s.lighting_score,
         s.coverage_score, s.composite_score, s.verdict, s.retake_reason, s.scored_at
  FROM public.engineer_photo_quality_scores_r2346 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.scored_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.r2346_recent_scores(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2346_recent_scores(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.r2346_worst_offenders()
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  total_photos bigint,
  retake_count bigint,
  retake_rate numeric,
  avg_composite numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_user_id,
    p.email,
    COUNT(*)::bigint AS total_photos,
    COUNT(*) FILTER (WHERE s.verdict = 'retake_required')::bigint AS retake_count,
    ROUND((COUNT(*) FILTER (WHERE s.verdict = 'retake_required'))::numeric * 100.0 / NULLIF(COUNT(*),0), 2) AS retake_rate,
    ROUND(AVG(s.composite_score)::numeric, 2) AS avg_composite
  FROM public.engineer_photo_quality_scores_r2346 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.scored_at >= now() - interval '30 days'
  GROUP BY s.engineer_user_id, p.email
  HAVING COUNT(*) >= 5
  ORDER BY retake_rate DESC NULLS LAST
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.r2346_worst_offenders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2346_worst_offenders() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2346_kind_breakdown()
RETURNS TABLE(
  photo_kind text,
  total bigint,
  pass_count bigint,
  retake_count bigint,
  avg_composite numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.photo_kind,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE s.verdict = 'pass')::bigint,
    COUNT(*) FILTER (WHERE s.verdict = 'retake_required')::bigint,
    ROUND(AVG(s.composite_score)::numeric, 2)
  FROM public.engineer_photo_quality_scores_r2346 s
  WHERE s.scored_at >= now() - interval '30 days'
  GROUP BY s.photo_kind
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2346_kind_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2346_kind_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2346_recent_nudges(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_email text,
  nudge_channel text,
  nudge_text text,
  sent_at timestamptz,
  acknowledged_at timestamptz,
  retake_completed_at timestamptz,
  ack_latency_seconds numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.id,
    p.email,
    n.nudge_channel,
    n.nudge_text,
    n.sent_at,
    n.acknowledged_at,
    n.retake_completed_at,
    CASE WHEN n.acknowledged_at IS NOT NULL
         THEN ROUND(EXTRACT(EPOCH FROM (n.acknowledged_at - n.sent_at))::numeric, 1)
         ELSE NULL END AS ack_latency_seconds
  FROM public.engineer_photo_retake_nudges_r2346 n
  LEFT JOIN public.profiles p ON p.id = n.engineer_user_id
  ORDER BY n.sent_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.r2346_recent_nudges(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2346_recent_nudges(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.r2346_nudge_effectiveness()
RETURNS TABLE(
  nudge_channel text,
  sent_count bigint,
  ack_count bigint,
  retake_count bigint,
  ack_rate numeric,
  retake_rate numeric,
  avg_ack_seconds numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.nudge_channel,
    COUNT(*)::bigint,
    COUNT(n.acknowledged_at)::bigint,
    COUNT(n.retake_completed_at)::bigint,
    ROUND(COUNT(n.acknowledged_at)::numeric * 100.0 / NULLIF(COUNT(*),0), 2),
    ROUND(COUNT(n.retake_completed_at)::numeric * 100.0 / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(EXTRACT(EPOCH FROM (n.acknowledged_at - n.sent_at)))::numeric, 1)
  FROM public.engineer_photo_retake_nudges_r2346 n
  WHERE n.sent_at >= now() - interval '30 days'
  GROUP BY n.nudge_channel
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2346_nudge_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2346_nudge_effectiveness() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2346_daily_trend()
RETURNS TABLE(
  day date,
  total bigint,
  pass_count bigint,
  retake_count bigint,
  avg_composite numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.scored_at::date AS day,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE s.verdict = 'pass')::bigint,
    COUNT(*) FILTER (WHERE s.verdict = 'retake_required')::bigint,
    ROUND(AVG(s.composite_score)::numeric, 2)
  FROM public.engineer_photo_quality_scores_r2346 s
  WHERE s.scored_at >= now() - interval '14 days'
  GROUP BY s.scored_at::date
  ORDER BY day DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2346_daily_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2346_daily_trend() TO authenticated;

COMMIT;
