BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_investor_drip_sequencer_r2062 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sequence_label text NOT NULL,
  sequence_md text NOT NULL,
  audience_segment text NOT NULL CHECK (audience_segment IN ('warm','cold','follow_up','cold_outbound','champion')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','completed','abandoned')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_drip_send_log_r2062 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sequence_id uuid NOT NULL REFERENCES public.founder_investor_drip_sequencer_r2062(id) ON DELETE CASCADE,
  send_to_investor_id uuid,
  sent_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response_received boolean NOT NULL DEFAULT false,
  response_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_investor_drip_sequencer_r2062 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_drip_send_log_r2062 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_seq_r2062 ON public.founder_investor_drip_sequencer_r2062;
CREATE POLICY p_founder_all_seq_r2062 ON public.founder_investor_drip_sequencer_r2062
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_all_send_r2062 ON public.founder_drip_send_log_r2062;
CREATE POLICY p_founder_all_send_r2062 ON public.founder_drip_send_log_r2062
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_sequences_r2062()
RETURNS SETOF public.founder_investor_drip_sequencer_r2062
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_investor_drip_sequencer_r2062 ORDER BY captured_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_sequence_r2062(
  p_label text,
  p_md text,
  p_segment text,
  p_status text DEFAULT 'active'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_investor_drip_sequencer_r2062(sequence_label, sequence_md, audience_segment, status)
  VALUES (p_label, p_md, p_segment, COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_sequence_r2062', jsonb_build_object('id', v_id, 'label', p_label, 'segment', p_segment));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_sends_r2062(p_sequence_id uuid)
RETURNS SETOF public.founder_drip_send_log_r2062
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_drip_send_log_r2062 WHERE sequence_id = p_sequence_id ORDER BY sent_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_send_r2062(
  p_sequence_id uuid,
  p_send_to_investor_id uuid,
  p_by_email text,
  p_response_received boolean DEFAULT false,
  p_response_md text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_drip_send_log_r2062(sequence_id, send_to_investor_id, by_email, response_received, response_md)
  VALUES (p_sequence_id, p_send_to_investor_id, p_by_email, COALESCE(p_response_received, false), p_response_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_send_r2062', jsonb_build_object('id', v_id, 'sequence_id', p_sequence_id));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2062(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','paused','completed','abandoned') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.founder_investor_drip_sequencer_r2062
     SET status = p_status, updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2062', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.active_sequences_r2062()
RETURNS SETOF public.founder_investor_drip_sequencer_r2062
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_investor_drip_sequencer_r2062 WHERE status = 'active' ORDER BY captured_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_sends_r2062()
RETURNS SETOF public.founder_drip_send_log_r2062
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_drip_send_log_r2062 ORDER BY sent_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_sequences_r2062() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_sequence_r2062(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_sends_r2062(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_send_r2062(uuid, uuid, text, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2062(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_sequences_r2062() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_sends_r2062() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_sequences_r2062() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_sequence_r2062(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_sends_r2062(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_send_r2062(uuid, uuid, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2062(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_sequences_r2062() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_sends_r2062() TO authenticated;

COMMIT;
