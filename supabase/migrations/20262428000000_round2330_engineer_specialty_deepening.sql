BEGIN;

-- =====================================================
-- Round 2330: Engineer Specialty-Deepening Recommendation Engine
-- Analyzes past repair jobs and recommends which specialty
-- each engineer should deepen next based on volume, success
-- rate, gaps, and demand signals.
-- =====================================================

CREATE TABLE IF NOT EXISTS public.engineer_specialty_recommendations_r2330 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  specialty_slug text NOT NULL,
  specialty_label text NOT NULL,
  recommendation_kind text NOT NULL CHECK (recommendation_kind IN ('deepen_strength','close_gap','emerging_demand','adjacent_skill','certification_ready')),
  rationale text NOT NULL,
  jobs_completed_count integer NOT NULL DEFAULT 0,
  success_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  avg_rating numeric(3,2),
  market_demand_score numeric(5,2) NOT NULL DEFAULT 0,
  fit_score numeric(5,2) NOT NULL DEFAULT 0,
  priority_rank integer NOT NULL DEFAULT 0,
  suggested_action text,
  estimated_revenue_uplift_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','accepted','dismissed','in_progress','completed')),
  generated_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_spec_rec_r2330_eng ON public.engineer_specialty_recommendations_r2330(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_spec_rec_r2330_status ON public.engineer_specialty_recommendations_r2330(status);
CREATE INDEX IF NOT EXISTS idx_eng_spec_rec_r2330_rank ON public.engineer_specialty_recommendations_r2330(priority_rank);

CREATE TABLE IF NOT EXISTS public.engineer_specialty_decisions_r2330 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recommendation_id uuid NOT NULL REFERENCES public.engineer_specialty_recommendations_r2330(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('accept','dismiss','snooze','escalate','mark_completed')),
  decision_note text,
  decided_by_email text NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_spec_dec_r2330_rec ON public.engineer_specialty_decisions_r2330(recommendation_id);
CREATE INDEX IF NOT EXISTS idx_eng_spec_dec_r2330_when ON public.engineer_specialty_decisions_r2330(decided_at DESC);

ALTER TABLE public.engineer_specialty_recommendations_r2330 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_specialty_decisions_r2330 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eng_spec_rec_r2330 ON public.engineer_specialty_recommendations_r2330;
CREATE POLICY founder_all_eng_spec_rec_r2330 ON public.engineer_specialty_recommendations_r2330
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eng_spec_dec_r2330 ON public.engineer_specialty_decisions_r2330;
CREATE POLICY founder_all_eng_spec_dec_r2330 ON public.engineer_specialty_decisions_r2330
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================
-- RPC 1: Overview metrics
-- =====================================================
DROP FUNCTION IF EXISTS public.founder_engineer_specialty_overview_r2330();
CREATE OR REPLACE FUNCTION public.founder_engineer_specialty_overview_r2330()
RETURNS TABLE (
  total_recommendations integer,
  proposed_count integer,
  accepted_count integer,
  in_progress_count integer,
  dismissed_count integer,
  engineers_with_recs integer,
  avg_fit_score numeric,
  total_revenue_uplift_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status = 'proposed')::int,
    COUNT(*) FILTER (WHERE status = 'accepted')::int,
    COUNT(*) FILTER (WHERE status = 'in_progress')::int,
    COUNT(*) FILTER (WHERE status = 'dismissed')::int,
    COUNT(DISTINCT engineer_user_id)::int,
    ROUND(COALESCE(AVG(fit_score),0)::numeric, 2),
    COALESCE(SUM(estimated_revenue_uplift_rupees) FILTER (WHERE status IN ('accepted','in_progress')), 0)::bigint
  FROM public.engineer_specialty_recommendations_r2330;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_specialty_overview_r2330() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_specialty_overview_r2330() TO authenticated;

-- =====================================================
-- RPC 2: Top recommendations ranked
-- =====================================================
DROP FUNCTION IF EXISTS public.founder_engineer_specialty_top_r2330(integer);
CREATE OR REPLACE FUNCTION public.founder_engineer_specialty_top_r2330(p_limit integer DEFAULT 50)
RETURNS TABLE (
  recommendation_id uuid,
  engineer_email text,
  engineer_name text,
  specialty_label text,
  recommendation_kind text,
  priority_rank integer,
  fit_score numeric,
  jobs_completed_count integer,
  success_rate_pct numeric,
  market_demand_score numeric,
  estimated_revenue_uplift_rupees bigint,
  status text,
  generated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    p.email,
    COALESCE(p.full_name, p.email),
    r.specialty_label,
    r.recommendation_kind,
    r.priority_rank,
    r.fit_score,
    r.jobs_completed_count,
    r.success_rate_pct,
    r.market_demand_score,
    r.estimated_revenue_uplift_rupees,
    r.status,
    r.generated_at
  FROM public.engineer_specialty_recommendations_r2330 r
  JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.priority_rank ASC, r.fit_score DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_specialty_top_r2330(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_specialty_top_r2330(integer) TO authenticated;

-- =====================================================
-- RPC 3: By engineer detail
-- =====================================================
DROP FUNCTION IF EXISTS public.founder_engineer_specialty_by_engineer_r2330(uuid);
CREATE OR REPLACE FUNCTION public.founder_engineer_specialty_by_engineer_r2330(p_engineer_id uuid)
RETURNS TABLE (
  recommendation_id uuid,
  specialty_label text,
  recommendation_kind text,
  rationale text,
  fit_score numeric,
  market_demand_score numeric,
  estimated_revenue_uplift_rupees bigint,
  suggested_action text,
  status text,
  generated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.specialty_label,
    r.recommendation_kind,
    r.rationale,
    r.fit_score,
    r.market_demand_score,
    r.estimated_revenue_uplift_rupees,
    r.suggested_action,
    r.status,
    r.generated_at
  FROM public.engineer_specialty_recommendations_r2330 r
  WHERE r.engineer_user_id = p_engineer_id
  ORDER BY r.priority_rank ASC, r.fit_score DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_specialty_by_engineer_r2330(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_specialty_by_engineer_r2330(uuid) TO authenticated;

-- =====================================================
-- RPC 4: Specialty mix breakdown
-- =====================================================
DROP FUNCTION IF EXISTS public.founder_engineer_specialty_mix_r2330();
CREATE OR REPLACE FUNCTION public.founder_engineer_specialty_mix_r2330()
RETURNS TABLE (
  specialty_label text,
  recommendation_kind text,
  rec_count integer,
  avg_fit_score numeric,
  total_uplift_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.specialty_label,
    r.recommendation_kind,
    COUNT(*)::int,
    ROUND(AVG(r.fit_score)::numeric, 2),
    COALESCE(SUM(r.estimated_revenue_uplift_rupees), 0)::bigint
  FROM public.engineer_specialty_recommendations_r2330 r
  GROUP BY r.specialty_label, r.recommendation_kind
  ORDER BY COUNT(*) DESC, r.specialty_label;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_specialty_mix_r2330() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_specialty_mix_r2330() TO authenticated;

-- =====================================================
-- RPC 5: Record decision
-- =====================================================
DROP FUNCTION IF EXISTS public.founder_engineer_specialty_decide_r2330(uuid, text, text);
CREATE OR REPLACE FUNCTION public.founder_engineer_specialty_decide_r2330(
  p_recommendation_id uuid,
  p_decision text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
  v_decision_id uuid;
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';

  v_new_status := CASE p_decision
    WHEN 'accept' THEN 'accepted'
    WHEN 'dismiss' THEN 'dismissed'
    WHEN 'snooze' THEN 'proposed'
    WHEN 'escalate' THEN 'in_progress'
    WHEN 'mark_completed' THEN 'completed'
    ELSE 'proposed'
  END;

  INSERT INTO public.engineer_specialty_decisions_r2330(
    recommendation_id, decision, decision_note, decided_by_email
  ) VALUES (
    p_recommendation_id, p_decision, p_note, v_email
  ) RETURNING id INTO v_decision_id;

  UPDATE public.engineer_specialty_recommendations_r2330
  SET status = v_new_status,
      decided_at = now(),
      decided_by_email = v_email,
      updated_at = now()
  WHERE id = p_recommendation_id;

  RETURN v_decision_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_specialty_decide_r2330(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_specialty_decide_r2330(uuid, text, text) TO authenticated;

-- =====================================================
-- RPC 6: Recent decisions
-- =====================================================
DROP FUNCTION IF EXISTS public.founder_engineer_specialty_recent_decisions_r2330(integer);
CREATE OR REPLACE FUNCTION public.founder_engineer_specialty_recent_decisions_r2330(p_limit integer DEFAULT 30)
RETURNS TABLE (
  decision_id uuid,
  engineer_email text,
  specialty_label text,
  decision text,
  decided_by_email text,
  decided_at timestamptz,
  decision_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    p.email,
    r.specialty_label,
    d.decision,
    d.decided_by_email,
    d.decided_at,
    d.decision_note
  FROM public.engineer_specialty_decisions_r2330 d
  JOIN public.engineer_specialty_recommendations_r2330 r ON r.id = d.recommendation_id
  JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY d.decided_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_specialty_recent_decisions_r2330(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_specialty_recent_decisions_r2330(integer) TO authenticated;

-- =====================================================
-- RPC 7: Status distribution funnel
-- =====================================================
DROP FUNCTION IF EXISTS public.founder_engineer_specialty_funnel_r2330();
CREATE OR REPLACE FUNCTION public.founder_engineer_specialty_funnel_r2330()
RETURNS TABLE (
  status text,
  rec_count integer,
  pct_share numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.engineer_specialty_recommendations_r2330;
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT
    r.status,
    COUNT(*)::int,
    ROUND((COUNT(*)::numeric * 100.0 / v_total)::numeric, 2)
  FROM public.engineer_specialty_recommendations_r2330 r
  GROUP BY r.status
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_specialty_funnel_r2330() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_specialty_funnel_r2330() TO authenticated;

COMMIT;
