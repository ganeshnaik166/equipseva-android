BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_quote_to_close_funnel_r2003 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quote_id text NOT NULL,
  quote_value_rupees bigint NOT NULL DEFAULT 0,
  days_to_response int NOT NULL DEFAULT 0,
  response_status text NOT NULL CHECK (response_status IN ('awaiting','quoted','negotiating','won','lost')),
  close_value_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('open','closed_won','closed_lost','walked_away')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_funnel_stage_log_r2003 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  funnel_id uuid NOT NULL REFERENCES public.hospital_quote_to_close_funnel_r2003(id) ON DELETE CASCADE,
  stage text NOT NULL CHECK (stage IN ('quoted','responded','follow_up','closed_won','closed_lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_quote_to_close_funnel_r2003 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_funnel_stage_log_r2003 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_funnel_r2003 ON public.hospital_quote_to_close_funnel_r2003;
CREATE POLICY founder_all_funnel_r2003 ON public.hospital_quote_to_close_funnel_r2003
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_stage_r2003 ON public.hospital_funnel_stage_log_r2003;
CREATE POLICY founder_all_stage_r2003 ON public.hospital_funnel_stage_log_r2003
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_funnels
CREATE OR REPLACE FUNCTION public.list_funnels_r2003()
RETURNS SETOF public.hospital_quote_to_close_funnel_r2003
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_quote_to_close_funnel_r2003 ORDER BY captured_at DESC LIMIT 200;
END; $$;

-- 2. log_funnel
CREATE OR REPLACE FUNCTION public.log_funnel_r2003(
  p_hospital_id uuid,
  p_quote_id text,
  p_quote_value_rupees bigint,
  p_days_to_response int,
  p_response_status text,
  p_close_value_rupees bigint,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_quote_to_close_funnel_r2003(hospital_id, quote_id, quote_value_rupees, days_to_response, response_status, close_value_rupees, status)
  VALUES (p_hospital_id, p_quote_id, p_quote_value_rupees, p_days_to_response, p_response_status, p_close_value_rupees, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_funnel_r2003', jsonb_build_object('id', v_id, 'quote_id', p_quote_id));
  RETURN v_id;
END; $$;

-- 3. list_stages
CREATE OR REPLACE FUNCTION public.list_stages_r2003(p_funnel_id uuid)
RETURNS SETOF public.hospital_funnel_stage_log_r2003
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_funnel_stage_log_r2003 WHERE funnel_id = p_funnel_id ORDER BY taken_at DESC;
END; $$;

-- 4. log_stage
CREATE OR REPLACE FUNCTION public.log_stage_r2003(
  p_funnel_id uuid,
  p_stage text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_funnel_stage_log_r2003(funnel_id, stage, by_email, notes_md)
  VALUES (p_funnel_id, p_stage, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_stage_r2003', jsonb_build_object('id', v_id, 'funnel_id', p_funnel_id, 'stage', p_stage));
  RETURN v_id;
END; $$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2003(p_id uuid, p_status text, p_close_value_rupees bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_quote_to_close_funnel_r2003
    SET status = p_status, close_value_rupees = COALESCE(p_close_value_rupees, close_value_rupees), updated_at = now()
    WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2003', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

-- 6. conversion_summary
CREATE OR REPLACE FUNCTION public.conversion_summary_r2003()
RETURNS TABLE(status text, cnt bigint, total_quote bigint, total_close bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.status, COUNT(*)::bigint, COALESCE(SUM(f.quote_value_rupees),0)::bigint, COALESCE(SUM(f.close_value_rupees),0)::bigint
    FROM public.hospital_quote_to_close_funnel_r2003 f
    GROUP BY f.status
    ORDER BY f.status;
END; $$;

-- 7. recent_stages
CREATE OR REPLACE FUNCTION public.recent_stages_r2003()
RETURNS SETOF public.hospital_funnel_stage_log_r2003
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_funnel_stage_log_r2003 ORDER BY taken_at DESC LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_funnels_r2003() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_funnel_r2003(uuid, text, bigint, int, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_stages_r2003(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_stage_r2003(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2003(uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.conversion_summary_r2003() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_stages_r2003() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_funnels_r2003() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_funnel_r2003(uuid, text, bigint, int, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_stages_r2003(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_stage_r2003(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2003(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.conversion_summary_r2003() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_stages_r2003() TO authenticated;

COMMIT;
