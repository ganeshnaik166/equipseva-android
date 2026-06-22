BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_negotiation_outcome_tracker_r2182 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_label text NOT NULL,
  negotiation_type text NOT NULL CHECK (negotiation_type IN ('vendor','customer','investor','employee','partner')),
  outcome text NOT NULL CHECK (outcome IN ('won','lost','walked_away','extended','escalated')),
  value_change_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('open','closed','escalated','walked_away')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_negotiation_action_log_r2182 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id uuid NOT NULL REFERENCES public.founder_negotiation_outcome_tracker_r2182(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('started','counter_offered','walked_away','escalated','won','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_negotiation_outcome_tracker_r2182 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_negotiation_action_log_r2182 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_neg_tracker_r2182 ON public.founder_negotiation_outcome_tracker_r2182;
CREATE POLICY founder_all_neg_tracker_r2182 ON public.founder_negotiation_outcome_tracker_r2182
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_neg_action_r2182 ON public.founder_negotiation_action_log_r2182;
CREATE POLICY founder_all_neg_action_r2182 ON public.founder_negotiation_action_log_r2182
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_neg_tracker_r2182_status ON public.founder_negotiation_outcome_tracker_r2182(status, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_neg_tracker_r2182_outcome ON public.founder_negotiation_outcome_tracker_r2182(outcome, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_neg_action_r2182_neg ON public.founder_negotiation_action_log_r2182(negotiation_id, taken_at DESC);

CREATE OR REPLACE FUNCTION public.list_negotiations_r2182()
RETURNS TABLE (
  id uuid,
  negotiation_label text,
  negotiation_type text,
  outcome text,
  value_change_rupees bigint,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.negotiation_label, t.negotiation_type, t.outcome, t.value_change_rupees, t.status, t.captured_at
  FROM public.founder_negotiation_outcome_tracker_r2182 t
  ORDER BY t.captured_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_negotiations_r2182() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_negotiations_r2182() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_negotiation_r2182(
  p_label text,
  p_type text,
  p_outcome text,
  p_value_change_rupees bigint,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_negotiation_outcome_tracker_r2182(negotiation_label, negotiation_type, outcome, value_change_rupees, status)
  VALUES (p_label, p_type, p_outcome, COALESCE(p_value_change_rupees, 0), p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_negotiation_r2182', jsonb_build_object('id', v_id, 'label', p_label, 'type', p_type));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_negotiation_r2182(text, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_negotiation_r2182(text, text, text, bigint, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2182(p_negotiation_id uuid)
RETURNS TABLE (
  id uuid,
  negotiation_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.negotiation_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_negotiation_action_log_r2182 a
  WHERE a.negotiation_id = p_negotiation_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2182(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2182(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2182(
  p_negotiation_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_negotiation_action_log_r2182(negotiation_id, action_type, by_email, notes_md)
  VALUES (p_negotiation_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2182', jsonb_build_object('id', v_id, 'negotiation_id', p_negotiation_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2182(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2182(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2182(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_negotiation_outcome_tracker_r2182
  SET status = p_status, updated_at = now()
  WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2182', jsonb_build_object('id', p_id, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2182(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2182(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_won_r2182()
RETURNS TABLE (
  id uuid,
  negotiation_label text,
  negotiation_type text,
  value_change_rupees bigint,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.negotiation_label, t.negotiation_type, t.value_change_rupees, t.captured_at
  FROM public.founder_negotiation_outcome_tracker_r2182 t
  WHERE t.outcome = 'won'
  ORDER BY t.captured_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_won_r2182() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_won_r2182() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2182()
RETURNS TABLE (
  id uuid,
  negotiation_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.negotiation_id, a.action_type, a.taken_at, a.by_email
  FROM public.founder_negotiation_action_log_r2182 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2182() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2182() TO authenticated;

COMMIT;
