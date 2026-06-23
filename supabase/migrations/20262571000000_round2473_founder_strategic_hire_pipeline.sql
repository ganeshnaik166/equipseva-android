-- Round 2473: founder-strategic-hire-pipeline
-- Role x candidate x stage x culture-fit x velocity-fit x references x offer-status x close prob.

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_strategic_hires_r2473 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_name text NOT NULL,
  candidate_name text NOT NULL,
  candidate_email text,
  stage text NOT NULL DEFAULT 'sourced' CHECK (stage IN ('sourced','screen','interview','reference','offer','closed_won','closed_lost')),
  culture_fit_score int NOT NULL DEFAULT 0 CHECK (culture_fit_score BETWEEN 0 AND 100),
  velocity_fit_score int NOT NULL DEFAULT 0 CHECK (velocity_fit_score BETWEEN 0 AND 100),
  references_completed boolean NOT NULL DEFAULT false,
  offer_amount_rupees bigint,
  offer_extended_at timestamptz,
  offer_decision_at timestamptz,
  close_probability_pct int NOT NULL DEFAULT 0 CHECK (close_probability_pct BETWEEN 0 AND 100),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_strategic_hires_r2473_stage ON public.founder_strategic_hires_r2473(stage);
CREATE INDEX IF NOT EXISTS idx_founder_strategic_hires_r2473_role ON public.founder_strategic_hires_r2473(role_name);
CREATE INDEX IF NOT EXISTS idx_founder_strategic_hires_r2473_owner ON public.founder_strategic_hires_r2473(owner_email);

CREATE TABLE IF NOT EXISTS public.strategic_hire_interview_log_r2473 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hire_id uuid NOT NULL REFERENCES public.founder_strategic_hires_r2473(id) ON DELETE CASCADE,
  interview_at timestamptz,
  interviewer_email text,
  panel_kind text NOT NULL DEFAULT 'culture' CHECK (panel_kind IN ('culture','technical','founder','reference','values')),
  score int NOT NULL DEFAULT 0 CHECK (score BETWEEN 0 AND 10),
  summary_md text,
  recommendation text NOT NULL DEFAULT 'maybe' CHECK (recommendation IN ('strong_yes','yes','maybe','no','strong_no')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_strategic_hire_interview_log_r2473_hire ON public.strategic_hire_interview_log_r2473(hire_id);
CREATE INDEX IF NOT EXISTS idx_strategic_hire_interview_log_r2473_panel ON public.strategic_hire_interview_log_r2473(panel_kind);
CREATE INDEX IF NOT EXISTS idx_strategic_hire_interview_log_r2473_at ON public.strategic_hire_interview_log_r2473(interview_at);

ALTER TABLE public.founder_strategic_hires_r2473 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strategic_hire_interview_log_r2473 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_strategic_hires_r2473;
CREATE POLICY founder_all ON public.founder_strategic_hires_r2473
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.strategic_hire_interview_log_r2473;
CREATE POLICY founder_all ON public.strategic_hire_interview_log_r2473
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_h4 uuid;
  v_h5 uuid;
BEGIN
  INSERT INTO public.founder_strategic_hires_r2473(role_name, candidate_name, candidate_email, stage, culture_fit_score, velocity_fit_score, references_completed, offer_amount_rupees, offer_extended_at, offer_decision_at, close_probability_pct, owner_email, notes)
  VALUES ('VP Engineering', 'Priya Raman', 'priya.raman@example.com', 'offer', 88, 92, true, 6500000, '2026-06-15 10:00:00'::timestamptz, NULL, 80, 'founder@equipseva.com', 'Strong founder fit, exec at biomed scale-up')
  RETURNING id INTO v_h1;

  INSERT INTO public.founder_strategic_hires_r2473(role_name, candidate_name, candidate_email, stage, culture_fit_score, velocity_fit_score, references_completed, offer_amount_rupees, close_probability_pct, owner_email, notes)
  VALUES ('Head of Sales', 'Arjun Mehta', 'arjun.mehta@example.com', 'reference', 75, 85, false, NULL, 55, 'founder@equipseva.com', 'Reference check in progress with last 2 employers')
  RETURNING id INTO v_h2;

  INSERT INTO public.founder_strategic_hires_r2473(role_name, candidate_name, candidate_email, stage, culture_fit_score, velocity_fit_score, references_completed, close_probability_pct, owner_email, notes)
  VALUES ('Director of Ops', 'Kavya Iyer', 'kavya.iyer@example.com', 'interview', 82, 78, false, 40, 'coo@equipseva.com', 'Excellent culture signal, technical depth tbd')
  RETURNING id INTO v_h3;

  INSERT INTO public.founder_strategic_hires_r2473(role_name, candidate_name, candidate_email, stage, culture_fit_score, velocity_fit_score, references_completed, offer_amount_rupees, offer_extended_at, offer_decision_at, close_probability_pct, owner_email, notes)
  VALUES ('Head of Product', 'Rohan Desai', 'rohan.desai@example.com', 'closed_won', 90, 88, true, 5500000, '2026-05-20 09:00:00'::timestamptz, '2026-05-28 18:00:00'::timestamptz, 100, 'founder@equipseva.com', 'Joined! Starts 2026-07-01')
  RETURNING id INTO v_h4;

  INSERT INTO public.founder_strategic_hires_r2473(role_name, candidate_name, candidate_email, stage, culture_fit_score, velocity_fit_score, references_completed, offer_amount_rupees, offer_extended_at, offer_decision_at, close_probability_pct, owner_email, notes)
  VALUES ('VP Engineering', 'Sanjay Krishnan', 'sanjay.k@example.com', 'closed_lost', 65, 70, true, 6000000, '2026-04-10 10:00:00'::timestamptz, '2026-04-22 14:00:00'::timestamptz, 0, 'founder@equipseva.com', 'Declined; took offer from competitor')
  RETURNING id INTO v_h5;

  IF v_h1 IS NOT NULL THEN
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h1, '2026-06-01 11:00:00'::timestamptz, 'founder@equipseva.com', 'founder', 9, '- Strong vision alignment\n- Owned 3 product launches\n- Founder energy', 'strong_yes', 'Top 1% candidate');
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h1, '2026-06-05 14:00:00'::timestamptz, 'cto@equipseva.com', 'technical', 8, '- Deep systems design\n- Mobile + backend\n- Could go deeper on ML', 'yes', NULL);
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h1, '2026-06-10 09:00:00'::timestamptz, 'reference@example.com', 'reference', 9, '- Prior CEO endorses strongly\n- Reliable under pressure', 'strong_yes', 'Reference 2 of 3');
  END IF;

  IF v_h2 IS NOT NULL THEN
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h2, '2026-06-12 15:00:00'::timestamptz, 'founder@equipseva.com', 'founder', 7, '- Closed enterprise deals\n- Velocity ok\n- Values alignment iffy', 'maybe', 'Need second culture round');
  END IF;

  IF v_h3 IS NOT NULL THEN
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h3, '2026-06-14 10:00:00'::timestamptz, 'coo@equipseva.com', 'culture', 8, '- Mission-driven\n- Asked great founder questions', 'yes', NULL);
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h3, '2026-06-18 11:00:00'::timestamptz, 'ops@equipseva.com', 'values', 7, '- Solid on integrity\n- Velocity tbd', 'maybe', NULL);
  END IF;

  IF v_h4 IS NOT NULL THEN
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h4, '2026-05-10 10:00:00'::timestamptz, 'founder@equipseva.com', 'founder', 10, '- Best PM founder ever interviewed\n- Closed in 2 weeks', 'strong_yes', NULL);
  END IF;

  IF v_h5 IS NOT NULL THEN
    INSERT INTO public.strategic_hire_interview_log_r2473(hire_id, interview_at, interviewer_email, panel_kind, score, summary_md, recommendation, notes)
    VALUES (v_h5, '2026-04-05 13:00:00'::timestamptz, 'founder@equipseva.com', 'founder', 6, '- Technical chops good\n- Lacked founder hunger', 'no', 'Passed on offer');
  END IF;
END $$;

-- RPC 1: list_hires_r2473
CREATE OR REPLACE FUNCTION public.list_hires_r2473()
RETURNS TABLE(
  id uuid,
  role_name text,
  candidate_name text,
  candidate_email text,
  stage text,
  culture_fit_score int,
  velocity_fit_score int,
  references_completed boolean,
  offer_amount_rupees bigint,
  offer_extended_at timestamptz,
  offer_decision_at timestamptz,
  close_probability_pct int,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.role_name, h.candidate_name, h.candidate_email, h.stage,
         h.culture_fit_score, h.velocity_fit_score, h.references_completed,
         h.offer_amount_rupees, h.offer_extended_at, h.offer_decision_at,
         h.close_probability_pct, h.owner_email, h.notes, h.created_at
  FROM public.founder_strategic_hires_r2473 h
  ORDER BY h.created_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_hires_r2473() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_hires_r2473() TO authenticated;

-- RPC 2: list_interview_log_r2473
CREATE OR REPLACE FUNCTION public.list_interview_log_r2473()
RETURNS TABLE(
  id uuid,
  hire_id uuid,
  candidate_name text,
  role_name text,
  interview_at timestamptz,
  interviewer_email text,
  panel_kind text,
  score int,
  summary_md text,
  recommendation text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.hire_id, h.candidate_name, h.role_name, l.interview_at,
         l.interviewer_email, l.panel_kind, l.score, l.summary_md,
         l.recommendation, l.notes, l.created_at
  FROM public.strategic_hire_interview_log_r2473 l
  LEFT JOIN public.founder_strategic_hires_r2473 h ON h.id = l.hire_id
  ORDER BY COALESCE(l.interview_at, l.created_at) DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_interview_log_r2473() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_interview_log_r2473() TO authenticated;

-- RPC 3: top_close_prob_r2473
CREATE OR REPLACE FUNCTION public.top_close_prob_r2473()
RETURNS TABLE(
  id uuid,
  role_name text,
  candidate_name text,
  stage text,
  close_probability_pct int,
  culture_fit_score int,
  velocity_fit_score int,
  offer_amount_rupees bigint,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.role_name, h.candidate_name, h.stage, h.close_probability_pct,
         h.culture_fit_score, h.velocity_fit_score, h.offer_amount_rupees, h.owner_email
  FROM public.founder_strategic_hires_r2473 h
  WHERE h.stage NOT IN ('closed_won','closed_lost')
  ORDER BY h.close_probability_pct DESC, h.culture_fit_score DESC
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_close_prob_r2473() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_close_prob_r2473() TO authenticated;

-- RPC 4: stage_funnel_r2473
CREATE OR REPLACE FUNCTION public.stage_funnel_r2473()
RETURNS TABLE(
  stage text,
  hire_count int,
  pct numeric,
  avg_close_prob numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.founder_strategic_hires_r2473;
  RETURN QUERY
  SELECT h.stage,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total,0), 2),
         ROUND(AVG(h.close_probability_pct)::numeric, 2)
  FROM public.founder_strategic_hires_r2473 h
  GROUP BY h.stage
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.stage_funnel_r2473() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stage_funnel_r2473() TO authenticated;

-- RPC 5: culture_fit_breakdown_r2473
CREATE OR REPLACE FUNCTION public.culture_fit_breakdown_r2473()
RETURNS TABLE(
  band text,
  hire_count int,
  avg_culture_fit numeric,
  avg_velocity_fit numeric,
  avg_close_prob numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN h.culture_fit_score >= 85 THEN 'A: 85-100'
      WHEN h.culture_fit_score >= 70 THEN 'B: 70-84'
      WHEN h.culture_fit_score >= 50 THEN 'C: 50-69'
      ELSE 'D: <50'
    END AS band,
    COUNT(*)::int,
    ROUND(AVG(h.culture_fit_score)::numeric, 2),
    ROUND(AVG(h.velocity_fit_score)::numeric, 2),
    ROUND(AVG(h.close_probability_pct)::numeric, 2)
  FROM public.founder_strategic_hires_r2473 h
  GROUP BY 1
  ORDER BY 1 ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.culture_fit_breakdown_r2473() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.culture_fit_breakdown_r2473() TO authenticated;

-- RPC 6: owner_load_r2473
CREATE OR REPLACE FUNCTION public.owner_load_r2473()
RETURNS TABLE(
  owner_email text,
  active_hires int,
  closed_won int,
  closed_lost int,
  avg_close_prob numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.owner_email,
         COUNT(*) FILTER (WHERE h.stage NOT IN ('closed_won','closed_lost'))::int,
         COUNT(*) FILTER (WHERE h.stage = 'closed_won')::int,
         COUNT(*) FILTER (WHERE h.stage = 'closed_lost')::int,
         ROUND(AVG(h.close_probability_pct) FILTER (WHERE h.stage NOT IN ('closed_won','closed_lost'))::numeric, 2)
  FROM public.founder_strategic_hires_r2473 h
  GROUP BY h.owner_email
  ORDER BY COUNT(*) FILTER (WHERE h.stage NOT IN ('closed_won','closed_lost')) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2473() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2473() TO authenticated;

-- RPC 7: weekly_pipeline_trend_r2473
CREATE OR REPLACE FUNCTION public.weekly_pipeline_trend_r2473()
RETURNS TABLE(
  week_start timestamptz,
  new_hires int,
  closed_won int,
  closed_lost int,
  avg_close_prob numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', h.created_at) AS week_start,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE h.stage = 'closed_won')::int,
         COUNT(*) FILTER (WHERE h.stage = 'closed_lost')::int,
         ROUND(AVG(h.close_probability_pct)::numeric, 2)
  FROM public.founder_strategic_hires_r2473 h
  GROUP BY 1
  ORDER BY 1 DESC
  LIMIT 26;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_pipeline_trend_r2473() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_pipeline_trend_r2473() TO authenticated;

