-- Round 2617: founder quarterly leadership clone pipeline

CREATE TABLE IF NOT EXISTS public.founder_leadership_clones_r2617 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  candidate_name text NOT NULL,
  candidate_email text NOT NULL,
  role_target_kind text NOT NULL CHECK (role_target_kind IN ('coo','cmo','cfo','cto','cpo','vp_engineering','head_sales')),
  readiness_pct int NOT NULL DEFAULT 0 CHECK (readiness_pct BETWEEN 0 AND 100),
  succession_target_quarter text NOT NULL,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'building' CHECK (status IN ('building','ready','onboarded','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.clone_pipeline_actions_r2617 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.founder_leadership_clones_r2617(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('coaching','external_course','skip_level','founder_shadow','board_intro')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_leadership_clones_r2617 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clone_pipeline_actions_r2617 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_leadership_clones_r2617;
CREATE POLICY founder_all ON public.founder_leadership_clones_r2617
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.clone_pipeline_actions_r2617;
CREATE POLICY founder_all ON public.clone_pipeline_actions_r2617
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.founder_leadership_clones_r2617 (quarter_label, candidate_name, candidate_email, role_target_kind, readiness_pct, succession_target_quarter, owner_email, status, notes) VALUES
  ('2026Q2', 'Anika Rao', 'anika.rao@equipseva.in', 'coo', 65, '2026Q4', 'founder@equipseva.in', 'building', 'Strong ops mind needs board exposure'),
  ('2026Q2', 'Vikram Shetty', 'vikram.shetty@equipseva.in', 'cmo', 80, '2026Q3', 'founder@equipseva.in', 'ready', 'Ready to own brand and demand gen'),
  ('2026Q2', 'Pooja Iyer', 'pooja.iyer@equipseva.in', 'cfo', 50, '2027Q1', 'founder@equipseva.in', 'building', 'Needs fundraising rep building'),
  ('2026Q2', 'Karthik Menon', 'karthik.menon@equipseva.in', 'vp_engineering', 90, '2026Q3', 'founder@equipseva.in', 'ready', 'Already running engineering org day-to-day'),
  ('2026Q2', 'Sneha Bhat', 'sneha.bhat@equipseva.in', 'head_sales', 40, '2027Q2', 'founder@equipseva.in', 'building', 'Promising but early')
ON CONFLICT DO NOTHING;

INSERT INTO public.clone_pipeline_actions_r2617 (candidate_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT c.id, '2026-06-10T10:00:00+05:30'::timestamptz, 'coaching', 'positive', 'founder@equipseva.in', 'done', 'Executive coach session weekly'
FROM public.founder_leadership_clones_r2617 c WHERE c.candidate_name = 'Anika Rao'
ON CONFLICT DO NOTHING;

INSERT INTO public.clone_pipeline_actions_r2617 (candidate_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT c.id, '2026-06-15T12:00:00+05:30'::timestamptz, 'board_intro', 'positive', 'founder@equipseva.in', 'done', 'Met chair of board'
FROM public.founder_leadership_clones_r2617 c WHERE c.candidate_name = 'Vikram Shetty'
ON CONFLICT DO NOTHING;

INSERT INTO public.clone_pipeline_actions_r2617 (candidate_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT c.id, '2026-06-18T09:30:00+05:30'::timestamptz, 'external_course', 'pending', 'founder@equipseva.in', 'open', 'INSEAD finance leaders cohort'
FROM public.founder_leadership_clones_r2617 c WHERE c.candidate_name = 'Pooja Iyer'
ON CONFLICT DO NOTHING;

INSERT INTO public.clone_pipeline_actions_r2617 (candidate_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT c.id, '2026-06-20T14:00:00+05:30'::timestamptz, 'founder_shadow', 'positive', 'founder@equipseva.in', 'done', 'Shadowed CEO for full week'
FROM public.founder_leadership_clones_r2617 c WHERE c.candidate_name = 'Karthik Menon'
ON CONFLICT DO NOTHING;

INSERT INTO public.clone_pipeline_actions_r2617 (candidate_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT c.id, '2026-06-22T11:00:00+05:30'::timestamptz, 'skip_level', 'neutral', 'founder@equipseva.in', 'open', 'Skip level with three reports'
FROM public.founder_leadership_clones_r2617 c WHERE c.candidate_name = 'Sneha Bhat'
ON CONFLICT DO NOTHING;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_clones_r2617()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  candidate_name text,
  candidate_email text,
  role_target_kind text,
  readiness_pct int,
  succession_target_quarter text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.quarter_label, c.candidate_name, c.candidate_email, c.role_target_kind,
           c.readiness_pct, c.succession_target_quarter, c.owner_email, c.status, c.notes, c.created_at
      FROM public.founder_leadership_clones_r2617 c
     ORDER BY c.readiness_pct DESC, c.created_at DESC
     LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_clones_r2617() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_clones_r2617() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_pipeline_actions_r2617()
RETURNS TABLE (
  id uuid,
  candidate_id uuid,
  candidate_name text,
  role_target_kind text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.candidate_id, c.candidate_name, c.role_target_kind,
           a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
      FROM public.clone_pipeline_actions_r2617 a
      JOIN public.founder_leadership_clones_r2617 c ON c.id = a.candidate_id
     ORDER BY a.action_at DESC
     LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pipeline_actions_r2617() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pipeline_actions_r2617() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_ready_candidates_r2617()
RETURNS TABLE (
  id uuid,
  candidate_name text,
  role_target_kind text,
  readiness_pct int,
  succession_target_quarter text,
  status text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.candidate_name, c.role_target_kind, c.readiness_pct,
           c.succession_target_quarter, c.status
      FROM public.founder_leadership_clones_r2617 c
     WHERE c.status IN ('building','ready')
     ORDER BY c.readiness_pct DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_ready_candidates_r2617() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_ready_candidates_r2617() TO authenticated;

CREATE OR REPLACE FUNCTION public.role_kind_distribution_r2617()
RETURNS TABLE (
  role_target_kind text,
  candidate_count bigint,
  avg_readiness numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.role_target_kind, count(*)::bigint, round(avg(c.readiness_pct)::numeric, 1)
      FROM public.founder_leadership_clones_r2617 c
     GROUP BY c.role_target_kind
     ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.role_kind_distribution_r2617() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_kind_distribution_r2617() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2617()
RETURNS TABLE (
  status text,
  candidate_count bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.status, count(*)::bigint
      FROM public.founder_leadership_clones_r2617 c
     GROUP BY c.status
     ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2617() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2617() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_pipeline_trend_r2617()
RETURNS TABLE (
  quarter_label text,
  candidate_count bigint,
  ready_count bigint,
  avg_readiness numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.quarter_label,
           count(*)::bigint,
           count(*) FILTER (WHERE c.status = 'ready')::bigint,
           round(avg(c.readiness_pct)::numeric, 1)
      FROM public.founder_leadership_clones_r2617 c
     GROUP BY c.quarter_label
     ORDER BY c.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_pipeline_trend_r2617() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_pipeline_trend_r2617() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2617()
RETURNS TABLE (
  owner_email text,
  candidate_count bigint,
  open_actions bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.owner_email,
           count(DISTINCT c.id)::bigint,
           count(a.id) FILTER (WHERE a.status = 'open')::bigint
      FROM public.founder_leadership_clones_r2617 c
      LEFT JOIN public.clone_pipeline_actions_r2617 a ON a.candidate_id = c.id
     GROUP BY c.owner_email
     ORDER BY count(DISTINCT c.id) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2617() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2617() TO authenticated;
