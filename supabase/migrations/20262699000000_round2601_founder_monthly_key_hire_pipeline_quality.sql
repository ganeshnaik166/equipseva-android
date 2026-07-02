-- Round 2601: Founder Monthly Key Hire Pipeline Quality
-- Track quality of senior/key hires pipeline (bar pass, diversity, velocity, close prob).

CREATE TABLE IF NOT EXISTS public.founder_key_hire_pipeline_r2601 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  role_name text NOT NULL,
  candidates_count int NOT NULL DEFAULT 0,
  bar_passed_count int NOT NULL DEFAULT 0,
  diversity_count int NOT NULL DEFAULT 0,
  velocity_days int NOT NULL DEFAULT 0,
  close_probability_pct int NOT NULL DEFAULT 0 CHECK (close_probability_pct BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.key_hire_pipeline_actions_r2601 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.founder_key_hire_pipeline_r2601(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('sourcing_increase','bar_raise','diversity_initiative','offer_negotiation','exec_intro')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_key_hire_pipeline_r2601 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.key_hire_pipeline_actions_r2601 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_key_hire_pipeline_r2601;
CREATE POLICY founder_all ON public.founder_key_hire_pipeline_r2601
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.key_hire_pipeline_actions_r2601;
CREATE POLICY founder_all ON public.key_hire_pipeline_actions_r2601
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.founder_key_hire_pipeline_r2601 (month_label, role_name, candidates_count, bar_passed_count, diversity_count, velocity_days, close_probability_pct, owner_email, status, notes)
VALUES
  ('2026-06','VP Engineering', 42, 6, 2, 38, 65, 'founder@equipseva.in', 'active', 'Strong India + remote pool'),
  ('2026-06','Head of Sales (Hospital Chains)', 28, 4, 1, 51, 45, 'founder@equipseva.in', 'active', 'Tier-1 chain sales background needed'),
  ('2026-06','Principal SRE', 35, 5, 2, 29, 70, 'founder@equipseva.in', 'active', 'Pipeline healthy'),
  ('2026-05','Director of Operations', 22, 3, 1, 60, 35, 'founder@equipseva.in', 'paused', 'Paused — reprioritised after Q2 plan'),
  ('2026-05','Head of Compliance', 18, 4, 2, 44, 80, 'founder@equipseva.in', 'closed', 'Offer accepted — joins next month');

INSERT INTO public.key_hire_pipeline_actions_r2601 (pipeline_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'sourcing_increase', 'positive', 'founder@equipseva.in', 'done', 'Added 2 senior recruiters' FROM public.founder_key_hire_pipeline_r2601 WHERE role_name='VP Engineering' LIMIT 1;

INSERT INTO public.key_hire_pipeline_actions_r2601 (pipeline_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'bar_raise', 'neutral', 'founder@equipseva.in', 'open', 'Calibration session with board advisor' FROM public.founder_key_hire_pipeline_r2601 WHERE role_name='Head of Sales (Hospital Chains)' LIMIT 1;

INSERT INTO public.key_hire_pipeline_actions_r2601 (pipeline_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'diversity_initiative', 'positive', 'founder@equipseva.in', 'done', 'Partnered with WomenInTech sourcing' FROM public.founder_key_hire_pipeline_r2601 WHERE role_name='Principal SRE' LIMIT 1;

INSERT INTO public.key_hire_pipeline_actions_r2601 (pipeline_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'offer_negotiation', 'positive', 'founder@equipseva.in', 'done', 'Closed at target comp + ESOP refresh' FROM public.founder_key_hire_pipeline_r2601 WHERE role_name='Head of Compliance' LIMIT 1;

INSERT INTO public.key_hire_pipeline_actions_r2601 (pipeline_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'exec_intro', 'pending', 'founder@equipseva.in', 'open', 'Coffee chat scheduled with founder' FROM public.founder_key_hire_pipeline_r2601 WHERE role_name='VP Engineering' LIMIT 1;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_pipeline_r2601()
RETURNS SETOF public.founder_key_hire_pipeline_r2601
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_key_hire_pipeline_r2601 ORDER BY month_label DESC, close_probability_pct DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_pipeline_r2601() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pipeline_r2601() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_pipeline_actions_r2601()
RETURNS SETOF public.key_hire_pipeline_actions_r2601
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.key_hire_pipeline_actions_r2601 ORDER BY action_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_pipeline_actions_r2601() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pipeline_actions_r2601() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_close_prob_roles_r2601()
RETURNS TABLE(role_name text, month_label text, close_probability_pct int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.role_name, p.month_label, p.close_probability_pct, p.status
    FROM public.founder_key_hire_pipeline_r2601 p
    ORDER BY p.close_probability_pct DESC, p.month_label DESC
    LIMIT 10;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_close_prob_roles_r2601() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_close_prob_roles_r2601() TO authenticated;

CREATE OR REPLACE FUNCTION public.velocity_distribution_r2601()
RETURNS TABLE(bucket text, role_count bigint, avg_close_prob numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN velocity_days <= 30 THEN 'fast_0_30'
        WHEN velocity_days <= 45 THEN 'mid_31_45'
        WHEN velocity_days <= 60 THEN 'slow_46_60'
        ELSE 'stalled_60_plus'
      END::text AS bucket,
      COUNT(*)::bigint AS role_count,
      ROUND(AVG(close_probability_pct)::numeric, 1) AS avg_close_prob
    FROM public.founder_key_hire_pipeline_r2601
    GROUP BY 1
    ORDER BY role_count DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.velocity_distribution_r2601() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.velocity_distribution_r2601() TO authenticated;

CREATE OR REPLACE FUNCTION public.bar_pass_rate_summary_r2601()
RETURNS TABLE(role_name text, candidates_count int, bar_passed_count int, bar_pass_rate_pct numeric, diversity_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.role_name,
      p.candidates_count,
      p.bar_passed_count,
      CASE WHEN p.candidates_count > 0
        THEN ROUND((p.bar_passed_count::numeric / p.candidates_count::numeric) * 100, 1)
        ELSE 0::numeric
      END AS bar_pass_rate_pct,
      p.diversity_count
    FROM public.founder_key_hire_pipeline_r2601 p
    ORDER BY bar_pass_rate_pct DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.bar_pass_rate_summary_r2601() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bar_pass_rate_summary_r2601() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_pipeline_trend_r2601()
RETURNS TABLE(month_label text, roles_open bigint, total_candidates bigint, total_bar_passed bigint, avg_close_prob numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.month_label,
      COUNT(*)::bigint AS roles_open,
      SUM(p.candidates_count)::bigint AS total_candidates,
      SUM(p.bar_passed_count)::bigint AS total_bar_passed,
      ROUND(AVG(p.close_probability_pct)::numeric, 1) AS avg_close_prob
    FROM public.founder_key_hire_pipeline_r2601 p
    GROUP BY p.month_label
    ORDER BY p.month_label DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2601() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2601() TO authenticated;

CREATE OR REPLACE FUNCTION public.action_kind_breakdown_r2601()
RETURNS TABLE(action_kind text, action_count bigint, positive_count bigint, pending_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      a.action_kind,
      COUNT(*)::bigint AS action_count,
      COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_count,
      COUNT(*) FILTER (WHERE a.outcome = 'pending')::bigint AS pending_count
    FROM public.key_hire_pipeline_actions_r2601 a
    GROUP BY a.action_kind
    ORDER BY action_count DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_breakdown_r2601() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_breakdown_r2601() TO authenticated;
