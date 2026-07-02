BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_rfp_responses_r2207 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_name text NOT NULL,
  rfp_title text NOT NULL,
  rfp_ref_code text,
  city text,
  bid_value_rupees bigint NOT NULL DEFAULT 0,
  win_probability_pct int NOT NULL DEFAULT 0 CHECK (win_probability_pct BETWEEN 0 AND 100),
  submitted_at timestamptz,
  decision_due_at timestamptz,
  stage text NOT NULL DEFAULT 'drafting' CHECK (stage IN ('drafting','submitted','under_review','clarification','awarded','lost','withdrawn')),
  primary_owner_user_id uuid REFERENCES public.profiles(id),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_rfp_events_r2207 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfp_id uuid NOT NULL REFERENCES public.hospital_rfp_responses_r2207(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('note','stage_change','prob_change','clarification_sent','clarification_received','site_visit','demo')),
  detail text,
  prev_value text,
  new_value text,
  logged_by_user_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_rfp_responses_r2207 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_rfp_events_r2207 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_rfp_responses_r2207;
CREATE POLICY founder_all ON public.hospital_rfp_responses_r2207
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_rfp_events_r2207;
CREATE POLICY founder_all ON public.hospital_rfp_events_r2207
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list_rfps
CREATE OR REPLACE FUNCTION public.list_rfps_r2207()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  rfp_title text,
  city text,
  bid_value_rupees bigint,
  win_probability_pct int,
  stage text,
  decision_due_at timestamptz,
  days_to_decision int,
  expected_value_rupees bigint,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_name, r.rfp_title, r.city, r.bid_value_rupees,
         r.win_probability_pct, r.stage, r.decision_due_at,
         CASE WHEN r.decision_due_at IS NULL THEN NULL
              ELSE GREATEST(0, (EXTRACT(EPOCH FROM (r.decision_due_at - now()))/86400)::int) END AS days_to_decision,
         ((r.bid_value_rupees * r.win_probability_pct) / 100)::bigint AS expected_value_rupees,
         r.created_at
  FROM public.hospital_rfp_responses_r2207 r
  ORDER BY r.decision_due_at NULLS LAST, r.bid_value_rupees DESC
  LIMIT 200;
END;
$$;

-- 2. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2207()
RETURNS TABLE (
  id uuid,
  rfp_id uuid,
  hospital_name text,
  event_type text,
  detail text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.rfp_id, r.hospital_name, e.event_type, e.detail, e.created_at
  FROM public.hospital_rfp_events_r2207 e
  JOIN public.hospital_rfp_responses_r2207 r ON r.id = e.rfp_id
  ORDER BY e.created_at DESC
  LIMIT 100;
END;
$$;

-- 3. top_stage
CREATE OR REPLACE FUNCTION public.top_stage_r2207()
RETURNS TABLE (
  stage text,
  rfp_count int,
  total_bid_value_rupees bigint,
  total_expected_value_rupees bigint,
  avg_win_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.stage,
         (COUNT(*))::int AS rfp_count,
         COALESCE(SUM(r.bid_value_rupees),0)::bigint,
         COALESCE(SUM((r.bid_value_rupees * r.win_probability_pct)/100),0)::bigint,
         ROUND(AVG(r.win_probability_pct)::numeric, 1)
  FROM public.hospital_rfp_responses_r2207 r
  GROUP BY r.stage
  ORDER BY rfp_count DESC;
END;
$$;

-- 4. log_rfp
CREATE OR REPLACE FUNCTION public.log_rfp_r2207(
  p_hospital_name text,
  p_rfp_title text,
  p_city text,
  p_bid_value_rupees bigint,
  p_win_probability_pct int,
  p_decision_due_at timestamptz,
  p_stage text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_rfp_responses_r2207(
    hospital_name, rfp_title, city, bid_value_rupees,
    win_probability_pct, decision_due_at, stage, primary_owner_user_id
  ) VALUES (
    p_hospital_name, p_rfp_title, p_city, COALESCE(p_bid_value_rupees,0),
    COALESCE(p_win_probability_pct,0), p_decision_due_at, COALESCE(p_stage,'drafting'),
    auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2207_log_rfp',
          jsonb_build_object('rfp_id', v_id, 'hospital', p_hospital_name, 'bid', p_bid_value_rupees));
  RETURN v_id;
END;
$$;

-- 5. log_action
CREATE OR REPLACE FUNCTION public.log_action_r2207(
  p_rfp_id uuid,
  p_event_type text,
  p_detail text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_rfp_events_r2207(rfp_id, event_type, detail, logged_by_user_id)
  VALUES (p_rfp_id, p_event_type, p_detail, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2207_log_action',
          jsonb_build_object('rfp_id', p_rfp_id, 'event_type', p_event_type));
  RETURN v_id;
END;
$$;

-- 6. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2207(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('drafting','submitted','under_review','clarification','awarded','lost','withdrawn') THEN
    RAISE EXCEPTION 'invalid stage';
  END IF;

  SELECT stage INTO v_prev FROM public.hospital_rfp_responses_r2207 WHERE id = p_id;

  UPDATE public.hospital_rfp_responses_r2207
  SET stage = p_status
  WHERE id = p_id;

  INSERT INTO public.hospital_rfp_events_r2207(rfp_id, event_type, detail, prev_value, new_value, logged_by_user_id)
  VALUES (p_id, 'stage_change', 'stage updated', v_prev, p_status, auth.uid());

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2207_mark_status',
          jsonb_build_object('rfp_id', p_id, 'from', v_prev, 'to', p_status));
END;
$$;

-- 7. aggregate
CREATE OR REPLACE FUNCTION public.aggregate_rfp_r2207()
RETURNS TABLE (
  active_rfp_count int,
  total_value_at_stake_rupees bigint,
  weighted_pipeline_rupees bigint,
  avg_days_to_decision numeric,
  closing_within_7d int,
  awarded_30d_count int,
  awarded_30d_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE stage IN ('drafting','submitted','under_review','clarification')))::int,
    (COALESCE(SUM(bid_value_rupees) FILTER (WHERE stage IN ('drafting','submitted','under_review','clarification')),0))::bigint,
    (COALESCE(SUM((bid_value_rupees * win_probability_pct)/100) FILTER (WHERE stage IN ('drafting','submitted','under_review','clarification')),0))::bigint,
    ROUND(AVG(EXTRACT(EPOCH FROM (decision_due_at - now()))/86400) FILTER (WHERE decision_due_at IS NOT NULL AND decision_due_at > now())::numeric, 1),
    (COUNT(*) FILTER (WHERE decision_due_at IS NOT NULL AND decision_due_at <= now() + interval '7 days' AND decision_due_at > now()))::int,
    (COUNT(*) FILTER (WHERE stage='awarded' AND created_at >= now() - interval '30 days'))::int,
    (COALESCE(SUM(bid_value_rupees) FILTER (WHERE stage='awarded' AND created_at >= now() - interval '30 days'),0))::bigint
  FROM public.hospital_rfp_responses_r2207;
END;
$$;

REVOKE ALL ON FUNCTION public.list_rfps_r2207() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2207() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_stage_r2207() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_rfp_r2207(text,text,text,bigint,int,timestamptz,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2207(uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2207(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_rfp_r2207() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_rfps_r2207() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2207() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_stage_r2207() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_rfp_r2207(text,text,text,bigint,int,timestamptz,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2207(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2207(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_rfp_r2207() TO authenticated;

COMMIT;
