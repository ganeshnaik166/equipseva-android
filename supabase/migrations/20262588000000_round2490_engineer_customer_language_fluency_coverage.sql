-- Round 2490: engineer-customer-language-fluency-coverage
-- Track engineer language proficiency, hospital coverage gaps, translator usage, and coverage actions

CREATE TABLE IF NOT EXISTS public.engineer_language_fluency_r2490 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  language_name text NOT NULL,
  proficiency_level text NOT NULL CHECK (proficiency_level IN ('none','basic','conversational','fluent','native')),
  assessed_at timestamptz NOT NULL DEFAULT now(),
  assessor_email text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  gap_kind text NOT NULL CHECK (gap_kind IN ('no_coverage','single_engineer','translator_required','balanced')),
  translator_used boolean NOT NULL DEFAULT false,
  translator_cost_rupees int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.language_coverage_actions_r2490 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language_name text NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('hire','training','translator_contract','no_action')),
  action_at timestamptz NOT NULL DEFAULT now(),
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_language_fluency_r2490 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_coverage_actions_r2490 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_language_fluency_r2490;
CREATE POLICY founder_all ON public.engineer_language_fluency_r2490
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.language_coverage_actions_r2490;
CREATE POLICY founder_all ON public.language_coverage_actions_r2490
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed engineer language fluency (one row per insert; references first engineer)
INSERT INTO public.engineer_language_fluency_r2490 (engineer_user_id, language_name, proficiency_level, assessed_at, assessor_email, hospital_user_id, gap_kind, translator_used, translator_cost_rupees, notes)
SELECT e.id, 'Telugu', 'native', (now() - interval '14 days'), 'ops@equipseva.com', NULL, 'balanced', false, 0, 'native speaker - Hyderabad region coverage solid'
FROM public.engineers e ORDER BY e.created_at LIMIT 1;

INSERT INTO public.engineer_language_fluency_r2490 (engineer_user_id, language_name, proficiency_level, assessed_at, assessor_email, hospital_user_id, gap_kind, translator_used, translator_cost_rupees, notes)
SELECT e.id, 'Tamil', 'conversational', (now() - interval '10 days'), 'ops@equipseva.com', NULL, 'single_engineer', false, 0, 'only engineer covering Chennai - hire backup'
FROM public.engineers e ORDER BY e.created_at LIMIT 1;

INSERT INTO public.engineer_language_fluency_r2490 (engineer_user_id, language_name, proficiency_level, assessed_at, assessor_email, hospital_user_id, gap_kind, translator_used, translator_cost_rupees, notes)
SELECT e.id, 'Malayalam', 'basic', (now() - interval '7 days'), 'ops@equipseva.com', NULL, 'translator_required', true, 1800, 'Kochi visit needed translator for full procedure walkthrough'
FROM public.engineers e ORDER BY e.created_at LIMIT 1;

INSERT INTO public.engineer_language_fluency_r2490 (engineer_user_id, language_name, proficiency_level, assessed_at, assessor_email, hospital_user_id, gap_kind, translator_used, translator_cost_rupees, notes)
SELECT e.id, 'Bengali', 'none', (now() - interval '5 days'), 'ops@equipseva.com', NULL, 'no_coverage', true, 2400, 'Kolkata expansion - no engineer fluent - blocker'
FROM public.engineers e ORDER BY e.created_at LIMIT 1;

INSERT INTO public.engineer_language_fluency_r2490 (engineer_user_id, language_name, proficiency_level, assessed_at, assessor_email, hospital_user_id, gap_kind, translator_used, translator_cost_rupees, notes)
SELECT e.id, 'Hindi', 'fluent', (now() - interval '3 days'), 'ops@equipseva.com', NULL, 'balanced', false, 0, 'multiple engineers fluent - national coverage strong'
FROM public.engineers e ORDER BY e.created_at LIMIT 1;

-- Seed coverage actions
INSERT INTO public.language_coverage_actions_r2490 (language_name, action_kind, action_at, owner_email, status, outcome, follow_up_at, notes) VALUES
('Bengali', 'hire', (now() - interval '4 days'), 'hiring@equipseva.com', 'in_progress', 'pending', (now() + interval '14 days'), 'JD posted - 2 candidates shortlisted'),
('Tamil', 'training', (now() - interval '6 days'), 'training@equipseva.com', 'open', 'pending', (now() + interval '21 days'), 'cross-train 2 Hindi engineers on Tamil basics'),
('Malayalam', 'translator_contract', (now() - interval '3 days'), 'ops@equipseva.com', 'done', 'positive', NULL, 'signed monthly retainer with Kochi translator agency'),
('Bengali', 'translator_contract', (now() - interval '2 days'), 'ops@equipseva.com', 'in_progress', 'neutral', (now() + interval '7 days'), 'stopgap until Bengali hire closes'),
('Kannada', 'no_action', (now() - interval '1 day'), 'ops@equipseva.com', 'done', 'neutral', NULL, 'low Bangalore volume - no action needed yet');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_fluency_r2490()
RETURNS TABLE(id uuid, engineer_user_id uuid, language_name text, proficiency_level text, assessed_at timestamptz, assessor_email text, hospital_user_id uuid, gap_kind text, translator_used boolean, translator_cost_rupees int, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.engineer_user_id, f.language_name, f.proficiency_level, f.assessed_at, f.assessor_email, f.hospital_user_id, f.gap_kind, f.translator_used, f.translator_cost_rupees, f.notes
  FROM public.engineer_language_fluency_r2490 f
  ORDER BY f.assessed_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_fluency_r2490() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_fluency_r2490() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_coverage_actions_r2490()
RETURNS TABLE(id uuid, language_name text, action_kind text, action_at timestamptz, owner_email text, status text, outcome text, follow_up_at timestamptz, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.language_name, a.action_kind, a.action_at, a.owner_email, a.status, a.outcome, a.follow_up_at, a.notes
  FROM public.language_coverage_actions_r2490 a
  ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_coverage_actions_r2490() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coverage_actions_r2490() TO authenticated;

CREATE OR REPLACE FUNCTION public.no_coverage_focus_r2490()
RETURNS TABLE(language_name text, fluency_records bigint, translator_sessions bigint, total_translator_cost bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.language_name,
         count(*)::bigint AS fluency_records,
         count(*) FILTER (WHERE f.translator_used)::bigint AS translator_sessions,
         coalesce(sum(f.translator_cost_rupees), 0)::bigint AS total_translator_cost
  FROM public.engineer_language_fluency_r2490 f
  WHERE f.gap_kind = 'no_coverage'
  GROUP BY f.language_name
  ORDER BY total_translator_cost DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.no_coverage_focus_r2490() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.no_coverage_focus_r2490() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_translator_cost_r2490()
RETURNS TABLE(language_name text, total_cost_rupees bigint, sessions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.language_name,
         coalesce(sum(f.translator_cost_rupees), 0)::bigint AS total_cost_rupees,
         count(*) FILTER (WHERE f.translator_used)::bigint AS sessions
  FROM public.engineer_language_fluency_r2490 f
  WHERE f.translator_used = true
  GROUP BY f.language_name
  ORDER BY total_cost_rupees DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_translator_cost_r2490() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_translator_cost_r2490() TO authenticated;

CREATE OR REPLACE FUNCTION public.language_distribution_r2490()
RETURNS TABLE(language_name text, proficiency_level text, engineer_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.language_name, f.proficiency_level, count(DISTINCT f.engineer_user_id)::bigint
  FROM public.engineer_language_fluency_r2490 f
  GROUP BY f.language_name, f.proficiency_level
  ORDER BY f.language_name, f.proficiency_level;
END $$;
REVOKE EXECUTE ON FUNCTION public.language_distribution_r2490() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.language_distribution_r2490() TO authenticated;

CREATE OR REPLACE FUNCTION public.hospital_language_summary_r2490()
RETURNS TABLE(hospital_user_id uuid, gap_kind text, language_count bigint, translator_sessions bigint, translator_cost bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.hospital_user_id, f.gap_kind,
         count(DISTINCT f.language_name)::bigint AS language_count,
         count(*) FILTER (WHERE f.translator_used)::bigint AS translator_sessions,
         coalesce(sum(f.translator_cost_rupees), 0)::bigint AS translator_cost
  FROM public.engineer_language_fluency_r2490 f
  GROUP BY f.hospital_user_id, f.gap_kind
  ORDER BY translator_cost DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.hospital_language_summary_r2490() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hospital_language_summary_r2490() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_translator_trend_r2490()
RETURNS TABLE(week_start timestamptz, translator_sessions bigint, translator_cost bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', f.assessed_at) AS week_start,
         count(*) FILTER (WHERE f.translator_used)::bigint AS translator_sessions,
         coalesce(sum(f.translator_cost_rupees) FILTER (WHERE f.translator_used), 0)::bigint AS translator_cost
  FROM public.engineer_language_fluency_r2490 f
  GROUP BY date_trunc('week', f.assessed_at)
  ORDER BY week_start DESC
  LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_translator_trend_r2490() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_translator_trend_r2490() TO authenticated;
