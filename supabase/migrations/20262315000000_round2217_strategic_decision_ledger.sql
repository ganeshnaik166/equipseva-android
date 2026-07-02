BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_strategic_decisions_r2217 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decided_at timestamptz NOT NULL DEFAULT now(),
  decision_type text NOT NULL CHECK (decision_type IN ('hire','fire','pivot','kill','launch','invest','partner','restructure')),
  title text NOT NULL,
  rationale text NOT NULL,
  expected_outcome text NOT NULL,
  expected_review_at timestamptz NOT NULL DEFAULT (now() + interval '90 days'),
  stakes text NOT NULL DEFAULT 'medium' CHECK (stakes IN ('low','medium','high','existential')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','reviewed','reversed','superseded')),
  decided_by_user_id uuid REFERENCES public.profiles(id),
  decided_by_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_strategic_retros_r2217 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_strategic_decisions_r2217(id) ON DELETE CASCADE,
  retro_at timestamptz NOT NULL DEFAULT now(),
  outcome_grade text NOT NULL CHECK (outcome_grade IN ('A','B','C','D','F')),
  actual_outcome text NOT NULL,
  lessons_learned text,
  would_repeat boolean NOT NULL DEFAULT true,
  reviewer_user_id uuid REFERENCES public.profiles(id),
  reviewer_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategic_decisions_r2217 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_strategic_retros_r2217 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_strategic_decisions_r2217;
CREATE POLICY founder_all ON public.founder_strategic_decisions_r2217
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_strategic_retros_r2217;
CREATE POLICY founder_all ON public.founder_strategic_retros_r2217
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_strategic_decisions_r2217(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  decided_at timestamptz,
  decision_type text,
  title text,
  rationale text,
  expected_outcome text,
  expected_review_at timestamptz,
  stakes text,
  status text,
  decided_by_email text,
  days_until_review int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.decided_at, d.decision_type, d.title, d.rationale, d.expected_outcome,
           d.expected_review_at, d.stakes, d.status, d.decided_by_email,
           EXTRACT(DAY FROM (d.expected_review_at - now()))::int
    FROM public.founder_strategic_decisions_r2217 d
    ORDER BY d.decided_at DESC
    LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_strategic_decisions_r2217(p_limit int DEFAULT 50)
RETURNS TABLE (
  op_name text,
  actor_email text,
  created_at timestamptz,
  after_value jsonb
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.op_name, l.actor_email, l.created_at, l.after_value
    FROM public.founder_action_log l
    WHERE l.op_name LIKE 'op_r2217%'
    ORDER BY l.created_at DESC
    LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.top_strategic_decisions_r2217(p_limit int DEFAULT 10)
RETURNS TABLE (
  decision_type text,
  total int,
  active_count int,
  reversed_count int,
  high_stakes_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.decision_type,
           COUNT(*)::int,
           (COUNT(*) FILTER (WHERE d.status = 'active'))::int,
           (COUNT(*) FILTER (WHERE d.status = 'reversed'))::int,
           (COUNT(*) FILTER (WHERE d.stakes IN ('high','existential')))::int
    FROM public.founder_strategic_decisions_r2217 d
    GROUP BY d.decision_type
    ORDER BY COUNT(*) DESC
    LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.log_strategic_decision_r2217(
  p_decision_type text,
  p_title text,
  p_rationale text,
  p_expected_outcome text,
  p_stakes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.founder_strategic_decisions_r2217(
    decision_type, title, rationale, expected_outcome, stakes,
    decided_by_user_id, decided_by_email
  )
  VALUES (
    p_decision_type, p_title, p_rationale, p_expected_outcome, COALESCE(p_stakes,'medium'),
    auth.uid(), (auth.jwt()->>'email')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2217_log_decision',
          jsonb_build_object('id', v_id, 'type', p_decision_type, 'title', p_title, 'stakes', p_stakes));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_strategic_decision_r2217(
  p_decision_id uuid,
  p_outcome_grade text,
  p_actual_outcome text,
  p_lessons_learned text,
  p_would_repeat boolean
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.founder_strategic_retros_r2217(
    decision_id, outcome_grade, actual_outcome, lessons_learned, would_repeat,
    reviewer_user_id, reviewer_email
  )
  VALUES (
    p_decision_id, p_outcome_grade, p_actual_outcome, p_lessons_learned, COALESCE(p_would_repeat,true),
    auth.uid(), (auth.jwt()->>'email')
  )
  RETURNING id INTO v_id;

  UPDATE public.founder_strategic_decisions_r2217
     SET status = 'reviewed'
   WHERE id = p_decision_id AND status = 'active';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2217_log_retro',
          jsonb_build_object('retro_id', v_id, 'decision_id', p_decision_id, 'grade', p_outcome_grade));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_strategic_decision_r2217(
  p_decision_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_strategic_decisions_r2217
     SET status = p_status
   WHERE id = p_decision_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2217_mark_status',
          jsonb_build_object('decision_id', p_decision_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.aggregate_strategic_decisions_r2217()
RETURNS TABLE (
  total_decisions int,
  active_decisions int,
  reviewed_decisions int,
  reversed_decisions int,
  high_stakes_decisions int,
  overdue_review_count int,
  avg_grade text,
  would_repeat_rate_pct int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM public.founder_strategic_decisions_r2217),
      (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.founder_strategic_decisions_r2217),
      (SELECT (COUNT(*) FILTER (WHERE status = 'reviewed'))::int FROM public.founder_strategic_decisions_r2217),
      (SELECT (COUNT(*) FILTER (WHERE status = 'reversed'))::int FROM public.founder_strategic_decisions_r2217),
      (SELECT (COUNT(*) FILTER (WHERE stakes IN ('high','existential')))::int FROM public.founder_strategic_decisions_r2217),
      (SELECT (COUNT(*) FILTER (WHERE status = 'active' AND expected_review_at < now()))::int FROM public.founder_strategic_decisions_r2217),
      (SELECT COALESCE((
         SELECT outcome_grade FROM public.founder_strategic_retros_r2217
         GROUP BY outcome_grade ORDER BY COUNT(*) DESC LIMIT 1
       ),'-')),
      COALESCE((
        SELECT (100.0 * (COUNT(*) FILTER (WHERE would_repeat = true))::numeric / NULLIF(COUNT(*),0))::int
        FROM public.founder_strategic_retros_r2217
      ),0);
END $$;

REVOKE ALL ON FUNCTION public.list_strategic_decisions_r2217(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_strategic_decisions_r2217(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_strategic_decisions_r2217(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_strategic_decision_r2217(text,text,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_strategic_decision_r2217(uuid,text,text,text,boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_strategic_decision_r2217(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_strategic_decisions_r2217() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_strategic_decisions_r2217(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_strategic_decisions_r2217(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_strategic_decisions_r2217(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_strategic_decision_r2217(text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_strategic_decision_r2217(uuid,text,text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_strategic_decision_r2217(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_strategic_decisions_r2217() TO authenticated;

COMMIT;
