BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_service_excellence_ranking_r2112 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  excellence_score int NOT NULL CHECK (excellence_score BETWEEN 0 AND 100),
  percentile int NOT NULL CHECK (percentile BETWEEN 0 AND 100),
  status text NOT NULL CHECK (status IN ('rising','stable','declining','excellent','at_risk')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_ranking_action_log_r2112 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rank_id uuid NOT NULL REFERENCES public.engineer_service_excellence_ranking_r2112(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('recognized','coached','celebrated','escalated','promoted')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_service_excellence_ranking_r2112 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_ranking_action_log_r2112 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2112_rank ON public.engineer_service_excellence_ranking_r2112;
CREATE POLICY founder_all_r2112_rank ON public.engineer_service_excellence_ranking_r2112
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2112_actions ON public.engineer_ranking_action_log_r2112;
CREATE POLICY founder_all_r2112_actions ON public.engineer_ranking_action_log_r2112
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_rankings_r2112()
RETURNS TABLE (id uuid, engineer_user_id uuid, period_label text, excellence_score int, percentile int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.engineer_user_id, r.period_label, r.excellence_score, r.percentile, r.status, r.captured_at
    FROM public.engineer_service_excellence_ranking_r2112 r ORDER BY r.captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_ranking_r2112(p_engineer_user_id uuid, p_period_label text, p_excellence_score int, p_percentile int, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_service_excellence_ranking_r2112(engineer_user_id, period_label, excellence_score, percentile, status)
    VALUES (p_engineer_user_id, p_period_label, p_excellence_score, p_percentile, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_ranking_r2112', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'score', p_excellence_score));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2112(p_rank_id uuid)
RETURNS TABLE (id uuid, rank_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.rank_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_ranking_action_log_r2112 a WHERE a.rank_id = p_rank_id ORDER BY a.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2112(p_rank_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_ranking_action_log_r2112(rank_id, action_type, by_email, notes_md)
    VALUES (p_rank_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2112', jsonb_build_object('id', v_id, 'rank_id', p_rank_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2112(p_rank_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_service_excellence_ranking_r2112 SET status = p_status, updated_at = now() WHERE id = p_rank_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2112', jsonb_build_object('id', p_rank_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.top_ranked_r2112()
RETURNS TABLE (id uuid, engineer_user_id uuid, period_label text, excellence_score int, percentile int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.engineer_user_id, r.period_label, r.excellence_score, r.percentile, r.status, r.captured_at
    FROM public.engineer_service_excellence_ranking_r2112 r ORDER BY r.excellence_score DESC, r.percentile DESC LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2112()
RETURNS TABLE (id uuid, rank_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.rank_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_ranking_action_log_r2112 a ORDER BY a.taken_at DESC LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_rankings_r2112() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_ranking_r2112(uuid, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2112(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2112(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2112(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_ranked_r2112() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2112() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_rankings_r2112() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_ranking_r2112(uuid, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2112(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2112(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2112(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_ranked_r2112() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2112() TO authenticated;

COMMIT;
