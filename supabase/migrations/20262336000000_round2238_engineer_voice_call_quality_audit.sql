BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_voice_call_audits_r2238 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  repair_job_id uuid,
  call_started_at timestamptz NOT NULL DEFAULT now(),
  call_duration_seconds int NOT NULL DEFAULT 0,
  recording_url text,
  customer_phone_masked text,
  call_direction text NOT NULL DEFAULT 'outbound' CHECK (call_direction IN ('inbound','outbound')),
  sampling_pool text NOT NULL DEFAULT 'random' CHECK (sampling_pool IN ('random','escalation','low_csat','high_value')),
  audit_status text NOT NULL DEFAULT 'pending' CHECK (audit_status IN ('pending','in_review','scored','flagged','dismissed')),
  sampled_at timestamptz NOT NULL DEFAULT now(),
  scored_at timestamptz,
  scored_by_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_voice_call_audits_r2238 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_voice_call_audits_r2238;
CREATE POLICY founder_all ON public.engineer_voice_call_audits_r2238
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_voice_call_scores_r2238 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.engineer_voice_call_audits_r2238(id) ON DELETE CASCADE,
  tone_score int NOT NULL CHECK (tone_score BETWEEN 1 AND 5),
  clarity_score int NOT NULL CHECK (clarity_score BETWEEN 1 AND 5),
  empathy_score int NOT NULL CHECK (empathy_score BETWEEN 1 AND 5),
  resolution_score int NOT NULL CHECK (resolution_score BETWEEN 1 AND 5),
  composite_score numeric(4,2) GENERATED ALWAYS AS ((tone_score + clarity_score + empathy_score + resolution_score)::numeric / 4.0) STORED,
  coaching_note text,
  requires_followup boolean NOT NULL DEFAULT false,
  scored_by_email text NOT NULL,
  scored_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_voice_call_scores_r2238 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_voice_call_scores_r2238;
CREATE POLICY founder_all ON public.engineer_voice_call_scores_r2238
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_evca_status_r2238 ON public.engineer_voice_call_audits_r2238(audit_status, sampled_at DESC);
CREATE INDEX IF NOT EXISTS idx_evca_engineer_r2238 ON public.engineer_voice_call_audits_r2238(engineer_id, sampled_at DESC);
CREATE INDEX IF NOT EXISTS idx_evcs_audit_r2238 ON public.engineer_voice_call_scores_r2238(audit_id);

DROP FUNCTION IF EXISTS public.fn_evca_summary_r2238();
CREATE FUNCTION public.fn_evca_summary_r2238()
RETURNS TABLE(total_calls int, pending_calls int, scored_calls int, flagged_calls int, avg_composite numeric, calls_last_7d int, followup_required int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.engineer_voice_call_audits_r2238)::int,
    (SELECT COUNT(*) FILTER (WHERE audit_status = 'pending') FROM public.engineer_voice_call_audits_r2238)::int,
    (SELECT COUNT(*) FILTER (WHERE audit_status = 'scored') FROM public.engineer_voice_call_audits_r2238)::int,
    (SELECT COUNT(*) FILTER (WHERE audit_status = 'flagged') FROM public.engineer_voice_call_audits_r2238)::int,
    COALESCE((SELECT ROUND(AVG(composite_score)::numeric, 2) FROM public.engineer_voice_call_scores_r2238), 0)::numeric,
    (SELECT COUNT(*) FILTER (WHERE sampled_at >= now() - interval '7 days') FROM public.engineer_voice_call_audits_r2238)::int,
    (SELECT COUNT(*) FILTER (WHERE requires_followup) FROM public.engineer_voice_call_scores_r2238)::int;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_summary_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_summary_r2238() TO authenticated;

DROP FUNCTION IF EXISTS public.fn_evca_pending_queue_r2238();
CREATE FUNCTION public.fn_evca_pending_queue_r2238()
RETURNS TABLE(audit_id uuid, engineer_email text, call_started_at timestamptz, duration_seconds int, direction text, sampling_pool text, customer_phone_masked text, days_waiting int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, p.email, a.call_started_at, a.call_duration_seconds, a.call_direction, a.sampling_pool, a.customer_phone_masked,
    EXTRACT(DAY FROM (now() - a.sampled_at))::int
  FROM public.engineer_voice_call_audits_r2238 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_id
  WHERE a.audit_status IN ('pending','in_review')
  ORDER BY a.sampled_at ASC
  LIMIT 100;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_pending_queue_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_pending_queue_r2238() TO authenticated;

DROP FUNCTION IF EXISTS public.fn_evca_recent_scores_r2238();
CREATE FUNCTION public.fn_evca_recent_scores_r2238()
RETURNS TABLE(engineer_email text, call_started_at timestamptz, tone int, clarity int, empathy int, resolution int, composite numeric, followup boolean, scored_at timestamptz, scored_by text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email, a.call_started_at, s.tone_score, s.clarity_score, s.empathy_score, s.resolution_score,
    s.composite_score, s.requires_followup, s.scored_at, s.scored_by_email
  FROM public.engineer_voice_call_scores_r2238 s
  JOIN public.engineer_voice_call_audits_r2238 a ON a.id = s.audit_id
  LEFT JOIN public.profiles p ON p.id = a.engineer_id
  ORDER BY s.scored_at DESC
  LIMIT 100;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_recent_scores_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_recent_scores_r2238() TO authenticated;

DROP FUNCTION IF EXISTS public.fn_evca_engineer_leaderboard_r2238();
CREATE FUNCTION public.fn_evca_engineer_leaderboard_r2238()
RETURNS TABLE(engineer_email text, calls_audited int, calls_scored int, avg_tone numeric, avg_clarity numeric, avg_empathy numeric, avg_resolution numeric, avg_composite numeric, flag_rate_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email,
    COUNT(a.id)::int,
    (COUNT(*) FILTER (WHERE s.id IS NOT NULL))::int,
    COALESCE(ROUND(AVG(s.tone_score)::numeric, 2), 0)::numeric,
    COALESCE(ROUND(AVG(s.clarity_score)::numeric, 2), 0)::numeric,
    COALESCE(ROUND(AVG(s.empathy_score)::numeric, 2), 0)::numeric,
    COALESCE(ROUND(AVG(s.resolution_score)::numeric, 2), 0)::numeric,
    COALESCE(ROUND(AVG(s.composite_score)::numeric, 2), 0)::numeric,
    CASE WHEN COUNT(a.id) = 0 THEN 0::numeric
      ELSE ROUND((COUNT(*) FILTER (WHERE a.audit_status = 'flagged')::numeric * 100.0 / COUNT(a.id)::numeric), 1)
    END
  FROM public.engineer_voice_call_audits_r2238 a
  LEFT JOIN public.engineer_voice_call_scores_r2238 s ON s.audit_id = a.id
  LEFT JOIN public.profiles p ON p.id = a.engineer_id
  GROUP BY p.email
  HAVING COUNT(a.id) > 0
  ORDER BY AVG(s.composite_score) DESC NULLS LAST
  LIMIT 50;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_engineer_leaderboard_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_engineer_leaderboard_r2238() TO authenticated;

DROP FUNCTION IF EXISTS public.fn_evca_pool_breakdown_r2238();
CREATE FUNCTION public.fn_evca_pool_breakdown_r2238()
RETURNS TABLE(sampling_pool text, total int, scored int, flagged int, avg_composite numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.sampling_pool,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE a.audit_status = 'scored'))::int,
    (COUNT(*) FILTER (WHERE a.audit_status = 'flagged'))::int,
    COALESCE(ROUND(AVG(s.composite_score)::numeric, 2), 0)::numeric
  FROM public.engineer_voice_call_audits_r2238 a
  LEFT JOIN public.engineer_voice_call_scores_r2238 s ON s.audit_id = a.id
  GROUP BY a.sampling_pool
  ORDER BY COUNT(*) DESC;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_pool_breakdown_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_pool_breakdown_r2238() TO authenticated;

DROP FUNCTION IF EXISTS public.fn_evca_flagged_calls_r2238();
CREATE FUNCTION public.fn_evca_flagged_calls_r2238()
RETURNS TABLE(engineer_email text, call_started_at timestamptz, composite numeric, coaching_note text, scored_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email, a.call_started_at, s.composite_score, s.coaching_note, s.scored_at
  FROM public.engineer_voice_call_audits_r2238 a
  JOIN public.engineer_voice_call_scores_r2238 s ON s.audit_id = a.id
  LEFT JOIN public.profiles p ON p.id = a.engineer_id
  WHERE a.audit_status = 'flagged' OR s.requires_followup = true
  ORDER BY s.scored_at DESC
  LIMIT 50;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_flagged_calls_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_flagged_calls_r2238() TO authenticated;

DROP FUNCTION IF EXISTS public.fn_evca_score_distribution_r2238();
CREATE FUNCTION public.fn_evca_score_distribution_r2238()
RETURNS TABLE(dimension text, score_1 int, score_2 int, score_3 int, score_4 int, score_5 int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'tone'::text,
    (COUNT(*) FILTER (WHERE tone_score = 1))::int,
    (COUNT(*) FILTER (WHERE tone_score = 2))::int,
    (COUNT(*) FILTER (WHERE tone_score = 3))::int,
    (COUNT(*) FILTER (WHERE tone_score = 4))::int,
    (COUNT(*) FILTER (WHERE tone_score = 5))::int
  FROM public.engineer_voice_call_scores_r2238
  UNION ALL
  SELECT 'clarity'::text,
    (COUNT(*) FILTER (WHERE clarity_score = 1))::int,
    (COUNT(*) FILTER (WHERE clarity_score = 2))::int,
    (COUNT(*) FILTER (WHERE clarity_score = 3))::int,
    (COUNT(*) FILTER (WHERE clarity_score = 4))::int,
    (COUNT(*) FILTER (WHERE clarity_score = 5))::int
  FROM public.engineer_voice_call_scores_r2238
  UNION ALL
  SELECT 'empathy'::text,
    (COUNT(*) FILTER (WHERE empathy_score = 1))::int,
    (COUNT(*) FILTER (WHERE empathy_score = 2))::int,
    (COUNT(*) FILTER (WHERE empathy_score = 3))::int,
    (COUNT(*) FILTER (WHERE empathy_score = 4))::int,
    (COUNT(*) FILTER (WHERE empathy_score = 5))::int
  FROM public.engineer_voice_call_scores_r2238
  UNION ALL
  SELECT 'resolution'::text,
    (COUNT(*) FILTER (WHERE resolution_score = 1))::int,
    (COUNT(*) FILTER (WHERE resolution_score = 2))::int,
    (COUNT(*) FILTER (WHERE resolution_score = 3))::int,
    (COUNT(*) FILTER (WHERE resolution_score = 4))::int,
    (COUNT(*) FILTER (WHERE resolution_score = 5))::int
  FROM public.engineer_voice_call_scores_r2238;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_score_distribution_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_score_distribution_r2238() TO authenticated;

DROP FUNCTION IF EXISTS public.fn_evca_weekly_trend_r2238();
CREATE FUNCTION public.fn_evca_weekly_trend_r2238()
RETURNS TABLE(week_start date, calls_sampled int, calls_scored int, calls_flagged int, avg_composite numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DATE_TRUNC('week', a.sampled_at)::date,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE a.audit_status = 'scored'))::int,
    (COUNT(*) FILTER (WHERE a.audit_status = 'flagged'))::int,
    COALESCE(ROUND(AVG(s.composite_score)::numeric, 2), 0)::numeric
  FROM public.engineer_voice_call_audits_r2238 a
  LEFT JOIN public.engineer_voice_call_scores_r2238 s ON s.audit_id = a.id
  WHERE a.sampled_at >= now() - interval '12 weeks'
  GROUP BY DATE_TRUNC('week', a.sampled_at)
  ORDER BY 1 DESC;
END $$;

REVOKE ALL ON FUNCTION public.fn_evca_weekly_trend_r2238() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_evca_weekly_trend_r2238() TO authenticated;

COMMIT;