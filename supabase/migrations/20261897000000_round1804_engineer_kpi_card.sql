BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_kpi_cards_r1804 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  month_start date NOT NULL,
  jobs_completed int NOT NULL DEFAULT 0,
  avg_rating numeric(3,2),
  avg_response_min int,
  satisfaction_score numeric(5,2),
  payout_rupees bigint NOT NULL DEFAULT 0,
  kpi_grade text NOT NULL CHECK (kpi_grade IN ('a_plus','a','b','c','d')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_kpi_cards_r1804_eng ON public.engineer_kpi_cards_r1804(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_kpi_cards_r1804_month ON public.engineer_kpi_cards_r1804(month_start DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_kpi_cards_r1804_grade ON public.engineer_kpi_cards_r1804(kpi_grade);

CREATE TABLE IF NOT EXISTS public.engineer_kpi_grade_feedback_r1804 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id uuid NOT NULL REFERENCES public.engineer_kpi_cards_r1804(id) ON DELETE CASCADE,
  founder_feedback_md text NOT NULL,
  recognition_award text,
  action_required text NOT NULL CHECK (action_required IN ('celebrate','coach','redirect','pip')),
  fed_back_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_kpi_grade_feedback_r1804_card ON public.engineer_kpi_grade_feedback_r1804(card_id);
CREATE INDEX IF NOT EXISTS idx_engineer_kpi_grade_feedback_r1804_action ON public.engineer_kpi_grade_feedback_r1804(action_required);

-- RLS
ALTER TABLE public.engineer_kpi_cards_r1804 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_kpi_grade_feedback_r1804 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cards_r1804 ON public.engineer_kpi_cards_r1804;
CREATE POLICY founder_all_cards_r1804 ON public.engineer_kpi_cards_r1804
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_feedback_r1804 ON public.engineer_kpi_grade_feedback_r1804;
CREATE POLICY founder_all_feedback_r1804 ON public.engineer_kpi_grade_feedback_r1804
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_cards
CREATE OR REPLACE FUNCTION public.list_engineer_kpi_cards_r1804(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  month_start date,
  jobs_completed int,
  avg_rating numeric,
  avg_response_min int,
  satisfaction_score numeric,
  payout_rupees bigint,
  kpi_grade text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, c.month_start, c.jobs_completed, c.avg_rating,
         c.avg_response_min, c.satisfaction_score, c.payout_rupees, c.kpi_grade, c.recorded_at
  FROM public.engineer_kpi_cards_r1804 c
  ORDER BY c.month_start DESC, c.recorded_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 2: refresh_card
CREATE OR REPLACE FUNCTION public.refresh_engineer_kpi_card_r1804(
  p_engineer_user_id uuid,
  p_month_start date,
  p_jobs_completed int,
  p_avg_rating numeric,
  p_avg_response_min int,
  p_satisfaction_score numeric,
  p_payout_rupees bigint,
  p_kpi_grade text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_kpi_cards_r1804(
    engineer_user_id, month_start, jobs_completed, avg_rating, avg_response_min,
    satisfaction_score, payout_rupees, kpi_grade
  ) VALUES (
    p_engineer_user_id, p_month_start, p_jobs_completed, p_avg_rating, p_avg_response_min,
    p_satisfaction_score, p_payout_rupees, p_kpi_grade
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_engineer_kpi_card_r1804',
          jsonb_build_object('card_id', v_id, 'engineer_user_id', p_engineer_user_id, 'month_start', p_month_start, 'grade', p_kpi_grade));
  RETURN v_id;
END;
$$;

-- RPC 3: list_feedback
CREATE OR REPLACE FUNCTION public.list_engineer_kpi_feedback_r1804(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  card_id uuid,
  founder_feedback_md text,
  recognition_award text,
  action_required text,
  fed_back_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.id, f.card_id, f.founder_feedback_md, f.recognition_award, f.action_required, f.fed_back_at
  FROM public.engineer_kpi_grade_feedback_r1804 f
  ORDER BY f.fed_back_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 4: log_feedback
CREATE OR REPLACE FUNCTION public.log_engineer_kpi_feedback_r1804(
  p_card_id uuid,
  p_founder_feedback_md text,
  p_recognition_award text,
  p_action_required text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_kpi_grade_feedback_r1804(card_id, founder_feedback_md, recognition_award, action_required)
  VALUES (p_card_id, p_founder_feedback_md, p_recognition_award, p_action_required)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engineer_kpi_feedback_r1804',
          jsonb_build_object('feedback_id', v_id, 'card_id', p_card_id, 'action', p_action_required));
  RETURN v_id;
END;
$$;

-- RPC 5: top_a_plus_engineers
CREATE OR REPLACE FUNCTION public.top_a_plus_engineers_r1804(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_user_id uuid,
  a_plus_count int,
  total_payout bigint,
  avg_rating numeric,
  last_month date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.engineer_user_id,
         (COUNT(*) FILTER (WHERE c.kpi_grade = 'a_plus'))::int AS a_plus_count,
         COALESCE(SUM(c.payout_rupees),0)::bigint AS total_payout,
         AVG(c.avg_rating)::numeric AS avg_rating,
         MAX(c.month_start) AS last_month
  FROM public.engineer_kpi_cards_r1804 c
  GROUP BY c.engineer_user_id
  HAVING (COUNT(*) FILTER (WHERE c.kpi_grade = 'a_plus'))::int > 0
  ORDER BY a_plus_count DESC, total_payout DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 6: bottom_engineers
CREATE OR REPLACE FUNCTION public.bottom_engineers_r1804(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_user_id uuid,
  poor_grade_count int,
  total_payout bigint,
  avg_rating numeric,
  last_month date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.engineer_user_id,
         (COUNT(*) FILTER (WHERE c.kpi_grade IN ('c','d')))::int AS poor_grade_count,
         COALESCE(SUM(c.payout_rupees),0)::bigint AS total_payout,
         AVG(c.avg_rating)::numeric AS avg_rating,
         MAX(c.month_start) AS last_month
  FROM public.engineer_kpi_cards_r1804 c
  GROUP BY c.engineer_user_id
  HAVING (COUNT(*) FILTER (WHERE c.kpi_grade IN ('c','d')))::int > 0
  ORDER BY poor_grade_count DESC, avg_rating ASC NULLS FIRST
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 7: kpi_trend_per_engineer
CREATE OR REPLACE FUNCTION public.kpi_trend_per_engineer_r1804(p_engineer_user_id uuid, p_limit int DEFAULT 24)
RETURNS TABLE (
  month_start date,
  jobs_completed int,
  avg_rating numeric,
  satisfaction_score numeric,
  payout_rupees bigint,
  kpi_grade text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.month_start, c.jobs_completed, c.avg_rating, c.satisfaction_score, c.payout_rupees, c.kpi_grade
  FROM public.engineer_kpi_cards_r1804 c
  WHERE c.engineer_user_id = p_engineer_user_id
  ORDER BY c.month_start DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_engineer_kpi_cards_r1804(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_kpi_cards_r1804(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.refresh_engineer_kpi_card_r1804(uuid, date, int, numeric, int, numeric, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_engineer_kpi_card_r1804(uuid, date, int, numeric, int, numeric, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_engineer_kpi_feedback_r1804(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_kpi_feedback_r1804(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_engineer_kpi_feedback_r1804(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_engineer_kpi_feedback_r1804(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_a_plus_engineers_r1804(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_a_plus_engineers_r1804(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.bottom_engineers_r1804(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bottom_engineers_r1804(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.kpi_trend_per_engineer_r1804(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kpi_trend_per_engineer_r1804(uuid, int) TO authenticated;

COMMIT;