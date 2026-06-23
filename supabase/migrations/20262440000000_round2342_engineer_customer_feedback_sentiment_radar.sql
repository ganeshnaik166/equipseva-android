BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_feedback_signals_r2342 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  survey_response_id uuid,
  repair_job_id uuid,
  hospital_org_id uuid,
  raw_feedback_text text NOT NULL,
  feedback_language text NOT NULL DEFAULT 'en' CHECK (feedback_language IN ('en','hi','te','ta','kn','mr','bn','gu')),
  csat_score integer CHECK (csat_score BETWEEN 1 AND 5),
  nps_score integer CHECK (nps_score BETWEEN 0 AND 10),
  sentiment_label text NOT NULL CHECK (sentiment_label IN ('positive','neutral','negative','mixed')),
  sentiment_score numeric(4,3) NOT NULL CHECK (sentiment_score BETWEEN -1.000 AND 1.000),
  sentiment_confidence numeric(4,3) NOT NULL DEFAULT 0.000 CHECK (sentiment_confidence BETWEEN 0.000 AND 1.000),
  primary_theme text NOT NULL CHECK (primary_theme IN ('punctuality','technical_skill','communication','politeness','cleanliness','pricing','followup','spare_parts','documentation','escalation','other')),
  secondary_themes text[] NOT NULL DEFAULT '{}',
  emotion_tags text[] NOT NULL DEFAULT '{}',
  contains_complaint boolean NOT NULL DEFAULT false,
  contains_praise boolean NOT NULL DEFAULT false,
  mentions_name boolean NOT NULL DEFAULT false,
  mentions_competitor boolean NOT NULL DEFAULT false,
  contains_pii boolean NOT NULL DEFAULT false,
  pii_redacted_text text,
  word_count integer NOT NULL DEFAULT 0,
  collected_at timestamptz NOT NULL DEFAULT now(),
  analyzed_at timestamptz,
  analyzer_version text NOT NULL DEFAULT 'v1',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_signals_r2342_engineer ON public.engineer_feedback_signals_r2342(engineer_id, collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_signals_r2342_sentiment ON public.engineer_feedback_signals_r2342(sentiment_label, sentiment_score);
CREATE INDEX IF NOT EXISTS idx_feedback_signals_r2342_theme ON public.engineer_feedback_signals_r2342(primary_theme, collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_signals_r2342_complaint ON public.engineer_feedback_signals_r2342(contains_complaint, collected_at DESC) WHERE contains_complaint = true;

ALTER TABLE public.engineer_feedback_signals_r2342 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_feedback_signals_r2342;
CREATE POLICY founder_all ON public.engineer_feedback_signals_r2342 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_feedback_actions_r2342 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id uuid NOT NULL REFERENCES public.engineer_feedback_signals_r2342(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coach_call','written_warning','retraining_assigned','suspension','escalate_to_legal','customer_callback','recognition','no_action','close_resolved')),
  action_priority text NOT NULL DEFAULT 'medium' CHECK (action_priority IN ('low','medium','high','urgent')),
  action_status text NOT NULL DEFAULT 'open' CHECK (action_status IN ('open','in_progress','awaiting_engineer','completed','cancelled')),
  assigned_to_email text,
  due_at timestamptz,
  notes text,
  resolution_summary text,
  completed_at timestamptz,
  created_by_email text NOT NULL DEFAULT (auth.jwt()->>'email'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_actions_r2342_engineer ON public.engineer_feedback_actions_r2342(engineer_id, action_status);
CREATE INDEX IF NOT EXISTS idx_feedback_actions_r2342_status ON public.engineer_feedback_actions_r2342(action_status, due_at);
CREATE INDEX IF NOT EXISTS idx_feedback_actions_r2342_priority ON public.engineer_feedback_actions_r2342(action_priority, created_at DESC) WHERE action_status IN ('open','in_progress');

ALTER TABLE public.engineer_feedback_actions_r2342 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_feedback_actions_r2342;
CREATE POLICY founder_all ON public.engineer_feedback_actions_r2342 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2342_list_recent_signals(p_limit integer DEFAULT 100)
RETURNS TABLE (
  id uuid,
  engineer_email text,
  engineer_name text,
  collected_at timestamptz,
  sentiment_label text,
  sentiment_score numeric,
  primary_theme text,
  csat_score integer,
  nps_score integer,
  feedback_preview text,
  contains_complaint boolean,
  contains_praise boolean,
  has_action boolean
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id,
         p.email,
         p.full_name,
         s.collected_at,
         s.sentiment_label,
         s.sentiment_score,
         s.primary_theme,
         s.csat_score,
         s.nps_score,
         LEFT(COALESCE(s.pii_redacted_text, s.raw_feedback_text), 240),
         s.contains_complaint,
         s.contains_praise,
         EXISTS (SELECT 1 FROM public.engineer_feedback_actions_r2342 a WHERE a.signal_id = s.id)
  FROM public.engineer_feedback_signals_r2342 s
  JOIN public.profiles p ON p.id = s.engineer_id
  ORDER BY s.collected_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END $$;

CREATE OR REPLACE FUNCTION public.r2342_sentiment_radar_by_engineer(p_days integer DEFAULT 30)
RETURNS TABLE (
  engineer_id uuid,
  engineer_email text,
  engineer_name text,
  total_feedback integer,
  positive_pct numeric,
  negative_pct numeric,
  neutral_pct numeric,
  avg_sentiment numeric,
  avg_csat numeric,
  avg_nps numeric,
  complaint_count integer,
  praise_count integer,
  open_action_count integer
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH window_signals AS (
    SELECT s.* FROM public.engineer_feedback_signals_r2342 s
    WHERE s.collected_at >= now() - make_interval(days => GREATEST(1, p_days))
  )
  SELECT p.id,
         p.email,
         p.full_name,
         COUNT(*)::integer,
         ROUND(100.0 * COUNT(*) FILTER (WHERE w.sentiment_label = 'positive') / NULLIF(COUNT(*),0), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE w.sentiment_label = 'negative') / NULLIF(COUNT(*),0), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE w.sentiment_label = 'neutral') / NULLIF(COUNT(*),0), 1),
         ROUND(AVG(w.sentiment_score)::numeric, 3),
         ROUND(AVG(w.csat_score)::numeric, 2),
         ROUND(AVG(w.nps_score)::numeric, 2),
         COUNT(*) FILTER (WHERE w.contains_complaint)::integer,
         COUNT(*) FILTER (WHERE w.contains_praise)::integer,
         (SELECT COUNT(*)::integer FROM public.engineer_feedback_actions_r2342 a
            WHERE a.engineer_id = p.id AND a.action_status IN ('open','in_progress'))
  FROM window_signals w
  JOIN public.profiles p ON p.id = w.engineer_id
  GROUP BY p.id, p.email, p.full_name
  ORDER BY ROUND(AVG(w.sentiment_score)::numeric, 3) ASC NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION public.r2342_theme_cluster_breakdown(p_days integer DEFAULT 30)
RETURNS TABLE (
  theme text,
  total_count integer,
  negative_count integer,
  positive_count integer,
  avg_sentiment numeric,
  share_pct numeric
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.engineer_feedback_signals_r2342
    WHERE collected_at >= now() - make_interval(days => GREATEST(1, p_days));
  RETURN QUERY
  SELECT s.primary_theme,
         COUNT(*)::integer,
         COUNT(*) FILTER (WHERE s.sentiment_label = 'negative')::integer,
         COUNT(*) FILTER (WHERE s.sentiment_label = 'positive')::integer,
         ROUND(AVG(s.sentiment_score)::numeric, 3),
         CASE WHEN v_total = 0 THEN 0 ELSE ROUND(100.0 * COUNT(*) / v_total, 1) END
  FROM public.engineer_feedback_signals_r2342 s
  WHERE s.collected_at >= now() - make_interval(days => GREATEST(1, p_days))
  GROUP BY s.primary_theme
  ORDER BY COUNT(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2342_open_action_queue()
RETURNS TABLE (
  id uuid,
  signal_id uuid,
  engineer_email text,
  engineer_name text,
  action_type text,
  action_priority text,
  action_status text,
  assigned_to_email text,
  due_at timestamptz,
  age_days integer,
  feedback_preview text,
  sentiment_label text,
  primary_theme text
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id,
         a.signal_id,
         p.email,
         p.full_name,
         a.action_type,
         a.action_priority,
         a.action_status,
         a.assigned_to_email,
         a.due_at,
         GREATEST(0, EXTRACT(DAY FROM (now() - a.created_at))::integer),
         LEFT(COALESCE(s.pii_redacted_text, s.raw_feedback_text), 200),
         s.sentiment_label,
         s.primary_theme
  FROM public.engineer_feedback_actions_r2342 a
  JOIN public.profiles p ON p.id = a.engineer_id
  JOIN public.engineer_feedback_signals_r2342 s ON s.id = a.signal_id
  WHERE a.action_status IN ('open','in_progress','awaiting_engineer')
  ORDER BY CASE a.action_priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
           a.due_at NULLS LAST,
           a.created_at ASC;
END $$;

CREATE OR REPLACE FUNCTION public.r2342_signal_detail(p_signal_id uuid)
RETURNS TABLE (
  id uuid,
  engineer_email text,
  engineer_name text,
  collected_at timestamptz,
  raw_feedback_text text,
  pii_redacted_text text,
  feedback_language text,
  sentiment_label text,
  sentiment_score numeric,
  sentiment_confidence numeric,
  primary_theme text,
  secondary_themes text[],
  emotion_tags text[],
  csat_score integer,
  nps_score integer,
  contains_complaint boolean,
  contains_praise boolean,
  mentions_competitor boolean,
  contains_pii boolean,
  word_count integer,
  analyzer_version text,
  analyzed_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, p.full_name, s.collected_at,
         s.raw_feedback_text, s.pii_redacted_text, s.feedback_language,
         s.sentiment_label, s.sentiment_score, s.sentiment_confidence,
         s.primary_theme, s.secondary_themes, s.emotion_tags,
         s.csat_score, s.nps_score,
         s.contains_complaint, s.contains_praise, s.mentions_competitor, s.contains_pii,
         s.word_count, s.analyzer_version, s.analyzed_at
  FROM public.engineer_feedback_signals_r2342 s
  JOIN public.profiles p ON p.id = s.engineer_id
  WHERE s.id = p_signal_id;
END $$;

CREATE OR REPLACE FUNCTION public.r2342_emotion_tag_heatmap(p_days integer DEFAULT 30)
RETURNS TABLE (
  emotion_tag text,
  occurrences integer,
  negative_share_pct numeric
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH exploded AS (
    SELECT unnest(s.emotion_tags) AS tag, s.sentiment_label
    FROM public.engineer_feedback_signals_r2342 s
    WHERE s.collected_at >= now() - make_interval(days => GREATEST(1, p_days))
      AND array_length(s.emotion_tags, 1) > 0
  )
  SELECT e.tag,
         COUNT(*)::integer,
         ROUND(100.0 * COUNT(*) FILTER (WHERE e.sentiment_label = 'negative') / NULLIF(COUNT(*),0), 1)
  FROM exploded e
  GROUP BY e.tag
  ORDER BY COUNT(*) DESC
  LIMIT 25;
END $$;

CREATE OR REPLACE FUNCTION public.r2342_summary_kpis(p_days integer DEFAULT 30)
RETURNS TABLE (
  total_signals integer,
  analyzed_signals integer,
  pct_negative numeric,
  pct_positive numeric,
  avg_sentiment numeric,
  avg_csat numeric,
  avg_nps numeric,
  complaint_count integer,
  praise_count integer,
  competitor_mentions integer,
  pii_flagged integer,
  open_actions integer,
  urgent_open_actions integer
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH w AS (
    SELECT * FROM public.engineer_feedback_signals_r2342
    WHERE collected_at >= now() - make_interval(days => GREATEST(1, p_days))
  )
  SELECT (SELECT COUNT(*)::integer FROM w),
         (SELECT COUNT(*) FILTER (WHERE analyzed_at IS NOT NULL)::integer FROM w),
         (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE sentiment_label='negative') / NULLIF(COUNT(*),0), 1) FROM w),
         (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE sentiment_label='positive') / NULLIF(COUNT(*),0), 1) FROM w),
         (SELECT ROUND(AVG(sentiment_score)::numeric, 3) FROM w),
         (SELECT ROUND(AVG(csat_score)::numeric, 2) FROM w),
         (SELECT ROUND(AVG(nps_score)::numeric, 2) FROM w),
         (SELECT COUNT(*) FILTER (WHERE contains_complaint)::integer FROM w),
         (SELECT COUNT(*) FILTER (WHERE contains_praise)::integer FROM w),
         (SELECT COUNT(*) FILTER (WHERE mentions_competitor)::integer FROM w),
         (SELECT COUNT(*) FILTER (WHERE contains_pii)::integer FROM w),
         (SELECT COUNT(*)::integer FROM public.engineer_feedback_actions_r2342
            WHERE action_status IN ('open','in_progress','awaiting_engineer')),
         (SELECT COUNT(*)::integer FROM public.engineer_feedback_actions_r2342
            WHERE action_status IN ('open','in_progress','awaiting_engineer') AND action_priority = 'urgent');
END $$;

REVOKE ALL ON FUNCTION public.r2342_list_recent_signals(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2342_sentiment_radar_by_engineer(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2342_theme_cluster_breakdown(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2342_open_action_queue() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2342_signal_detail(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2342_emotion_tag_heatmap(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2342_summary_kpis(integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2342_list_recent_signals(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2342_sentiment_radar_by_engineer(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2342_theme_cluster_breakdown(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2342_open_action_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2342_signal_detail(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2342_emotion_tag_heatmap(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2342_summary_kpis(integer) TO authenticated;

COMMIT;
