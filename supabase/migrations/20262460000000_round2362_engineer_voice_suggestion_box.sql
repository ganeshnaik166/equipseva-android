BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_voice_suggestions_r2362 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('tool','process','app','training','safety','parts','customer','other')),
  title text NOT NULL,
  description text NOT NULL,
  pain_score int NOT NULL CHECK (pain_score BETWEEN 1 AND 10),
  frequency text NOT NULL CHECK (frequency IN ('daily','weekly','monthly','rare')),
  triage_state text NOT NULL DEFAULT 'new' CHECK (triage_state IN ('new','reviewing','accepted','in_progress','shipped','rejected','duplicate')),
  founder_note text,
  impact_score int CHECK (impact_score BETWEEN 1 AND 10),
  effort_score int CHECK (effort_score BETWEEN 1 AND 10),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  triaged_at timestamptz,
  shipped_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.engineer_voice_upvotes_r2362 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  suggestion_id uuid NOT NULL REFERENCES public.engineer_voice_suggestions_r2362(id) ON DELETE CASCADE,
  voter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  voted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (suggestion_id, voter_id)
);

ALTER TABLE public.engineer_voice_suggestions_r2362 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_voice_upvotes_r2362 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_voice_suggestions_r2362;
CREATE POLICY founder_all ON public.engineer_voice_suggestions_r2362 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_voice_upvotes_r2362;
CREATE POLICY founder_all ON public.engineer_voice_upvotes_r2362 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.founder_voice_inbox_r2362()
RETURNS TABLE (id uuid, title text, category text, pain_score int, frequency text, engineer_email text, upvotes bigint, submitted_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.title, s.category, s.pain_score, s.frequency,
         (SELECT au.email FROM auth.users au WHERE au.id = s.engineer_id),
         (SELECT COUNT(*) FROM public.engineer_voice_upvotes_r2362 u WHERE u.suggestion_id = s.id),
         s.submitted_at
  FROM public.engineer_voice_suggestions_r2362 s
  WHERE s.triage_state = 'new'
  ORDER BY s.pain_score DESC, s.submitted_at ASC
  LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_voice_top_pain_r2362()
RETURNS TABLE (category text, suggestions_count bigint, avg_pain numeric, total_upvotes bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.category, COUNT(*)::bigint,
         ROUND(AVG(s.pain_score)::numeric, 2),
         (SELECT COUNT(*) FROM public.engineer_voice_upvotes_r2362 u
          JOIN public.engineer_voice_suggestions_r2362 s2 ON s2.id = u.suggestion_id
          WHERE s2.category = s.category)::bigint
  FROM public.engineer_voice_suggestions_r2362 s
  GROUP BY s.category
  ORDER BY AVG(s.pain_score) DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_voice_pipeline_r2362()
RETURNS TABLE (triage_state text, ct bigint, avg_age_days numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.triage_state, COUNT(*)::bigint,
         ROUND(AVG(EXTRACT(EPOCH FROM (now() - s.submitted_at))/86400)::numeric, 1)
  FROM public.engineer_voice_suggestions_r2362 s
  GROUP BY s.triage_state
  ORDER BY COUNT(*) DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_voice_impl_rate_r2362()
RETURNS TABLE (total bigint, shipped bigint, rejected bigint, in_flight bigint, impl_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_total bigint; v_shipped bigint; v_rejected bigint; v_inflight bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.engineer_voice_suggestions_r2362;
  SELECT COUNT(*) INTO v_shipped FROM public.engineer_voice_suggestions_r2362 WHERE triage_state = 'shipped';
  SELECT COUNT(*) INTO v_rejected FROM public.engineer_voice_suggestions_r2362 WHERE triage_state = 'rejected';
  SELECT COUNT(*) INTO v_inflight FROM public.engineer_voice_suggestions_r2362 WHERE triage_state IN ('accepted','in_progress','reviewing');
  RETURN QUERY SELECT v_total, v_shipped, v_rejected, v_inflight,
    CASE WHEN v_total > 0 THEN ROUND(100.0 * v_shipped / v_total, 2) ELSE 0 END;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_voice_top_voters_r2362()
RETURNS TABLE (engineer_email text, submissions bigint, votes_cast bigint, shipped_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (SELECT au.email FROM auth.users au WHERE au.id = p.id),
         (SELECT COUNT(*) FROM public.engineer_voice_suggestions_r2362 s WHERE s.engineer_id = p.id)::bigint,
         (SELECT COUNT(*) FROM public.engineer_voice_upvotes_r2362 u WHERE u.voter_id = p.id)::bigint,
         (SELECT COUNT(*) FROM public.engineer_voice_suggestions_r2362 s WHERE s.engineer_id = p.id AND s.triage_state = 'shipped')::bigint
  FROM public.profiles p
  WHERE p.role = 'engineer'
    AND (EXISTS (SELECT 1 FROM public.engineer_voice_suggestions_r2362 s WHERE s.engineer_id = p.id)
      OR EXISTS (SELECT 1 FROM public.engineer_voice_upvotes_r2362 u WHERE u.voter_id = p.id))
  ORDER BY 2 DESC, 3 DESC
  LIMIT 25;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_voice_impact_effort_r2362()
RETURNS TABLE (id uuid, title text, category text, impact_score int, effort_score int, ratio numeric, triage_state text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.title, s.category, s.impact_score, s.effort_score,
         CASE WHEN s.effort_score > 0 THEN ROUND((s.impact_score::numeric / s.effort_score::numeric), 2) ELSE NULL END,
         s.triage_state
  FROM public.engineer_voice_suggestions_r2362 s
  WHERE s.impact_score IS NOT NULL AND s.effort_score IS NOT NULL
  ORDER BY (s.impact_score::numeric / NULLIF(s.effort_score,0)::numeric) DESC NULLS LAST
  LIMIT 50;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_voice_ship_velocity_r2362()
RETURNS TABLE (week_start date, shipped_ct bigint, avg_days_to_ship numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', s.shipped_at)::date,
         COUNT(*)::bigint,
         ROUND(AVG(EXTRACT(EPOCH FROM (s.shipped_at - s.submitted_at))/86400)::numeric, 1)
  FROM public.engineer_voice_suggestions_r2362 s
  WHERE s.shipped_at IS NOT NULL
    AND s.shipped_at >= now() - interval '12 weeks'
  GROUP BY 1
  ORDER BY 1 DESC;
END; $$;

REVOKE ALL ON FUNCTION public.founder_voice_inbox_r2362() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_voice_top_pain_r2362() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_voice_pipeline_r2362() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_voice_impl_rate_r2362() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_voice_top_voters_r2362() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_voice_impact_effort_r2362() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_voice_ship_velocity_r2362() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_voice_inbox_r2362() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_voice_top_pain_r2362() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_voice_pipeline_r2362() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_voice_impl_rate_r2362() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_voice_top_voters_r2362() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_voice_impact_effort_r2362() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_voice_ship_velocity_r2362() TO authenticated;

COMMIT;
