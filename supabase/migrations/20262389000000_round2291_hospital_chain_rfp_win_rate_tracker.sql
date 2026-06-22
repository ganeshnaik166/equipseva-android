BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_rfp_submissions_r2291 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  rfp_title text NOT NULL,
  submission_date date NOT NULL,
  decision_date date,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','won','lost','withdrawn')),
  contract_value_rupees bigint NOT NULL DEFAULT 0,
  competitor_count int NOT NULL DEFAULT 0,
  winning_competitor text,
  loss_reason text,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_rfp_learnings_r2291 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid REFERENCES public.hospital_chain_rfp_submissions_r2291(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  category text NOT NULL CHECK (category IN ('pricing','technical','relationship','compliance','timing','other')),
  learning_text text NOT NULL,
  impact_score int NOT NULL DEFAULT 3 CHECK (impact_score BETWEEN 1 AND 5),
  shared_with_team boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_rfp_submissions_r2291 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_rfp_learnings_r2291 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_rfp_submissions_r2291;
CREATE POLICY founder_all ON public.hospital_chain_rfp_submissions_r2291
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_rfp_learnings_r2291;
CREATE POLICY founder_all ON public.hospital_chain_rfp_learnings_r2291
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS hcrfp_sub_chain_r2291 ON public.hospital_chain_rfp_submissions_r2291(chain_name);
CREATE INDEX IF NOT EXISTS hcrfp_sub_outcome_r2291 ON public.hospital_chain_rfp_submissions_r2291(outcome);
CREATE INDEX IF NOT EXISTS hcrfp_sub_date_r2291 ON public.hospital_chain_rfp_submissions_r2291(submission_date DESC);
CREATE INDEX IF NOT EXISTS hcrfp_learn_chain_r2291 ON public.hospital_chain_rfp_learnings_r2291(chain_name);
CREATE INDEX IF NOT EXISTS hcrfp_learn_shared_r2291 ON public.hospital_chain_rfp_learnings_r2291(shared_with_team);

CREATE OR REPLACE FUNCTION public.rpc_r2291_chain_win_rate_summary()
RETURNS TABLE (
  chain_name text,
  total_submissions bigint,
  wins bigint,
  losses bigint,
  pending_count bigint,
  win_rate_pct numeric,
  total_won_value_rupees bigint,
  total_lost_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.chain_name,
    COUNT(*)::bigint AS total_submissions,
    (COUNT(*) FILTER (WHERE s.outcome = 'won'))::bigint AS wins,
    (COUNT(*) FILTER (WHERE s.outcome = 'lost'))::bigint AS losses,
    (COUNT(*) FILTER (WHERE s.outcome = 'pending'))::bigint AS pending_count,
    CASE WHEN COUNT(*) FILTER (WHERE s.outcome IN ('won','lost')) > 0
      THEN ROUND(100.0 * (COUNT(*) FILTER (WHERE s.outcome = 'won'))::numeric
                 / NULLIF((COUNT(*) FILTER (WHERE s.outcome IN ('won','lost')))::numeric, 0), 1)
      ELSE 0 END AS win_rate_pct,
    COALESCE(SUM(s.contract_value_rupees) FILTER (WHERE s.outcome = 'won'), 0)::bigint AS total_won_value_rupees,
    COALESCE(SUM(s.contract_value_rupees) FILTER (WHERE s.outcome = 'lost'), 0)::bigint AS total_lost_value_rupees
  FROM public.hospital_chain_rfp_submissions_r2291 s
  GROUP BY s.chain_name
  ORDER BY total_submissions DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_r2291_monthly_trend()
RETURNS TABLE (
  month_start date,
  submissions bigint,
  wins bigint,
  losses bigint,
  win_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', s.submission_date)::date AS month_start,
    COUNT(*)::bigint AS submissions,
    (COUNT(*) FILTER (WHERE s.outcome = 'won'))::bigint AS wins,
    (COUNT(*) FILTER (WHERE s.outcome = 'lost'))::bigint AS losses,
    CASE WHEN COUNT(*) FILTER (WHERE s.outcome IN ('won','lost')) > 0
      THEN ROUND(100.0 * (COUNT(*) FILTER (WHERE s.outcome = 'won'))::numeric
                 / NULLIF((COUNT(*) FILTER (WHERE s.outcome IN ('won','lost')))::numeric, 0), 1)
      ELSE 0 END AS win_rate_pct
  FROM public.hospital_chain_rfp_submissions_r2291 s
  WHERE s.submission_date >= (CURRENT_DATE - INTERVAL '12 months')
  GROUP BY date_trunc('month', s.submission_date)
  ORDER BY month_start DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_r2291_recent_submissions(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  chain_name text,
  rfp_title text,
  submission_date date,
  decision_date date,
  outcome text,
  contract_value_rupees bigint,
  competitor_count int,
  winning_competitor text,
  owner_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.rfp_title, s.submission_date, s.decision_date,
         s.outcome, s.contract_value_rupees, s.competitor_count, s.winning_competitor,
         p.email AS owner_email
  FROM public.hospital_chain_rfp_submissions_r2291 s
  LEFT JOIN public.profiles p ON p.id = s.owner_user_id
  ORDER BY s.submission_date DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_r2291_loss_reason_breakdown()
RETURNS TABLE (
  loss_reason text,
  loss_count bigint,
  total_lost_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(s.loss_reason, 'unspecified') AS loss_reason,
    COUNT(*)::bigint AS loss_count,
    COALESCE(SUM(s.contract_value_rupees), 0)::bigint AS total_lost_value_rupees
  FROM public.hospital_chain_rfp_submissions_r2291 s
  WHERE s.outcome = 'lost'
  GROUP BY COALESCE(s.loss_reason, 'unspecified')
  ORDER BY loss_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_r2291_top_learnings(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  chain_name text,
  category text,
  learning_text text,
  impact_score int,
  shared_with_team boolean,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.chain_name, l.category, l.learning_text, l.impact_score,
         l.shared_with_team, l.created_at
  FROM public.hospital_chain_rfp_learnings_r2291 l
  ORDER BY l.impact_score DESC, l.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_r2291_kpis()
RETURNS TABLE (
  total_rfps bigint,
  total_wins bigint,
  total_losses bigint,
  overall_win_rate_pct numeric,
  pipeline_value_rupees bigint,
  won_value_rupees bigint,
  unshared_learnings bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.hospital_chain_rfp_submissions_r2291)::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_rfp_submissions_r2291 WHERE outcome = 'won')::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_rfp_submissions_r2291 WHERE outcome = 'lost')::bigint,
    (SELECT CASE WHEN COUNT(*) FILTER (WHERE outcome IN ('won','lost')) > 0
        THEN ROUND(100.0 * (COUNT(*) FILTER (WHERE outcome = 'won'))::numeric
                   / NULLIF((COUNT(*) FILTER (WHERE outcome IN ('won','lost')))::numeric, 0), 1)
        ELSE 0 END
      FROM public.hospital_chain_rfp_submissions_r2291),
    (SELECT COALESCE(SUM(contract_value_rupees), 0) FROM public.hospital_chain_rfp_submissions_r2291 WHERE outcome = 'pending')::bigint,
    (SELECT COALESCE(SUM(contract_value_rupees), 0) FROM public.hospital_chain_rfp_submissions_r2291 WHERE outcome = 'won')::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_rfp_learnings_r2291 WHERE shared_with_team = false)::bigint;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_r2291_category_learning_mix()
RETURNS TABLE (
  category text,
  learning_count bigint,
  avg_impact numeric,
  shared_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.category,
    COUNT(*)::bigint AS learning_count,
    ROUND(AVG(l.impact_score)::numeric, 2) AS avg_impact,
    (COUNT(*) FILTER (WHERE l.shared_with_team))::bigint AS shared_count
  FROM public.hospital_chain_rfp_learnings_r2291 l
  GROUP BY l.category
  ORDER BY learning_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2291_chain_win_rate_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_r2291_monthly_trend() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_r2291_recent_submissions(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_r2291_loss_reason_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_r2291_top_learnings(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_r2291_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_r2291_category_learning_mix() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.rpc_r2291_chain_win_rate_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2291_monthly_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2291_recent_submissions(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2291_loss_reason_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2291_top_learnings(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2291_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2291_category_learning_mix() TO authenticated;

COMMIT;
