BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_pipeline_states_r1705 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  current_stage text NOT NULL CHECK (current_stage IN ('intro','diligence','term_sheet','legal','close','passed')),
  warmth int NOT NULL DEFAULT 5 CHECK (warmth BETWEEN 1 AND 10),
  days_in_stage int NOT NULL DEFAULT 0,
  expected_close_date date,
  expected_check_size_rupees bigint,
  last_touch_at timestamptz,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_pipeline_stage_history_r1705 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  state_id uuid NOT NULL REFERENCES public.investor_pipeline_states_r1705(id) ON DELETE CASCADE,
  from_stage text,
  to_stage text NOT NULL,
  transitioned_at timestamptz NOT NULL DEFAULT now(),
  transition_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_pipeline_states_r1705 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_pipeline_stage_history_r1705 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_states_r1705 ON public.investor_pipeline_states_r1705;
CREATE POLICY founder_all_states_r1705 ON public.investor_pipeline_states_r1705
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hist_r1705 ON public.investor_pipeline_stage_history_r1705;
CREATE POLICY founder_all_hist_r1705 ON public.investor_pipeline_stage_history_r1705
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_pipeline_states_r1705_stage ON public.investor_pipeline_states_r1705(current_stage);
CREATE INDEX IF NOT EXISTS idx_pipeline_states_r1705_warmth ON public.investor_pipeline_states_r1705(warmth);
CREATE INDEX IF NOT EXISTS idx_pipeline_hist_r1705_state ON public.investor_pipeline_stage_history_r1705(state_id);

DROP FUNCTION IF EXISTS public.list_pipeline_r1705();
CREATE OR REPLACE FUNCTION public.list_pipeline_r1705()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  current_stage text,
  warmth int,
  days_in_stage int,
  expected_close_date date,
  expected_check_size_rupees bigint,
  last_touch_at timestamptz,
  founder_note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_id, s.current_stage, s.warmth, s.days_in_stage,
         s.expected_close_date, s.expected_check_size_rupees, s.last_touch_at,
         s.founder_note, s.created_at
  FROM public.investor_pipeline_states_r1705 s
  ORDER BY s.warmth DESC NULLS LAST, s.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.set_state_r1705(uuid, text, int, int, date, bigint, timestamptz, text);
CREATE OR REPLACE FUNCTION public.set_state_r1705(
  p_investor_id uuid,
  p_current_stage text,
  p_warmth int,
  p_days_in_stage int,
  p_expected_close_date date,
  p_expected_check_size_rupees bigint,
  p_last_touch_at timestamptz,
  p_founder_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_pipeline_states_r1705(
    investor_id, current_stage, warmth, days_in_stage,
    expected_close_date, expected_check_size_rupees, last_touch_at, founder_note
  ) VALUES (
    p_investor_id, p_current_stage, COALESCE(p_warmth, 5), COALESCE(p_days_in_stage, 0),
    p_expected_close_date, p_expected_check_size_rupees, p_last_touch_at, p_founder_note
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_state_r1705',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'stage', p_current_stage));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_history_r1705(uuid);
CREATE OR REPLACE FUNCTION public.list_history_r1705(p_state_id uuid)
RETURNS TABLE (
  id uuid,
  state_id uuid,
  from_stage text,
  to_stage text,
  transitioned_at timestamptz,
  transition_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.state_id, h.from_stage, h.to_stage, h.transitioned_at, h.transition_note
  FROM public.investor_pipeline_stage_history_r1705 h
  WHERE h.state_id = p_state_id
  ORDER BY h.transitioned_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.log_transition_r1705(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_transition_r1705(
  p_state_id uuid,
  p_from_stage text,
  p_to_stage text,
  p_transition_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_pipeline_stage_history_r1705(state_id, from_stage, to_stage, transition_note)
  VALUES (p_state_id, p_from_stage, p_to_stage, p_transition_note)
  RETURNING id INTO v_id;

  UPDATE public.investor_pipeline_states_r1705
     SET current_stage = p_to_stage,
         days_in_stage = 0,
         updated_at = now()
   WHERE id = p_state_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_transition_r1705',
    jsonb_build_object('state_id', p_state_id, 'from', p_from_stage, 'to', p_to_stage));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.pipeline_heatmap_summary_r1705();
CREATE OR REPLACE FUNCTION public.pipeline_heatmap_summary_r1705()
RETURNS TABLE (
  stage text,
  state_count int,
  avg_warmth numeric,
  avg_days_in_stage numeric,
  total_expected_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.current_stage AS stage,
         (COUNT(*))::int AS state_count,
         ROUND(AVG(s.warmth)::numeric, 2) AS avg_warmth,
         ROUND(AVG(s.days_in_stage)::numeric, 2) AS avg_days_in_stage,
         COALESCE(SUM(s.expected_check_size_rupees), 0)::bigint AS total_expected_rupees
  FROM public.investor_pipeline_states_r1705 s
  WHERE s.current_stage <> 'passed'
  GROUP BY s.current_stage
  ORDER BY s.current_stage;
END;
$$;

DROP FUNCTION IF EXISTS public.expected_close_this_quarter_r1705();
CREATE OR REPLACE FUNCTION public.expected_close_this_quarter_r1705()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  current_stage text,
  warmth int,
  expected_close_date date,
  expected_check_size_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_q_start date := date_trunc('quarter', now())::date;
  v_q_end date := (date_trunc('quarter', now()) + interval '3 months' - interval '1 day')::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_id, s.current_stage, s.warmth, s.expected_close_date, s.expected_check_size_rupees
  FROM public.investor_pipeline_states_r1705 s
  WHERE s.expected_close_date IS NOT NULL
    AND s.expected_close_date BETWEEN v_q_start AND v_q_end
    AND s.current_stage <> 'passed'
  ORDER BY s.expected_close_date ASC;
END;
$$;

DROP FUNCTION IF EXISTS public.cold_investors_r1705();
CREATE OR REPLACE FUNCTION public.cold_investors_r1705()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  current_stage text,
  warmth int,
  days_in_stage int,
  last_touch_at timestamptz,
  founder_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_id, s.current_stage, s.warmth, s.days_in_stage, s.last_touch_at, s.founder_note
  FROM public.investor_pipeline_states_r1705 s
  WHERE (s.warmth <= 3 OR s.last_touch_at < (now() - interval '21 days'))
    AND s.current_stage <> 'passed'
  ORDER BY s.warmth ASC NULLS FIRST, s.last_touch_at ASC NULLS FIRST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pipeline_r1705() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_state_r1705(uuid, text, int, int, date, bigint, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_history_r1705(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_transition_r1705(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pipeline_heatmap_summary_r1705() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expected_close_this_quarter_r1705() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cold_investors_r1705() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pipeline_r1705() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_state_r1705(uuid, text, int, int, date, bigint, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_history_r1705(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_transition_r1705(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pipeline_heatmap_summary_r1705() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expected_close_this_quarter_r1705() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cold_investors_r1705() TO authenticated;

COMMIT;