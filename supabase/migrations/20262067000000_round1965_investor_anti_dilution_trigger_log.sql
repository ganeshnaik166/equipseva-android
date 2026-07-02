BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_anti_dilution_triggers_r1965 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  trigger_event_label text NOT NULL,
  trigger_event_at timestamptz NOT NULL DEFAULT now(),
  anti_dilution_type text NOT NULL CHECK (anti_dilution_type IN ('weighted_avg','full_ratchet','none')),
  shares_added_to_investor bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'triggered' CHECK (status IN ('triggered','calculating','finalized','disputed')),
  finalized_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_anti_dilution_action_log_r1965 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trigger_id uuid NOT NULL REFERENCES public.investor_anti_dilution_triggers_r1965(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('calculation_completed','notified_investor','issued_additional_shares','disputed','resolved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_anti_dilution_triggers_r1965 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_anti_dilution_action_log_r1965 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_triggers_r1965 ON public.investor_anti_dilution_triggers_r1965;
CREATE POLICY founder_all_triggers_r1965 ON public.investor_anti_dilution_triggers_r1965
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1965 ON public.investor_anti_dilution_action_log_r1965;
CREATE POLICY founder_all_actions_r1965 ON public.investor_anti_dilution_action_log_r1965
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_anti_dilution_triggers_r1965()
RETURNS SETOF public.investor_anti_dilution_triggers_r1965
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_anti_dilution_triggers_r1965 ORDER BY trigger_event_at DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.log_anti_dilution_trigger_r1965(
  p_investor_id uuid,
  p_label text,
  p_anti_dilution_type text,
  p_shares_added bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_anti_dilution_triggers_r1965(investor_id, trigger_event_label, anti_dilution_type, shares_added_to_investor)
  VALUES (p_investor_id, p_label, p_anti_dilution_type, COALESCE(p_shares_added, 0))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_anti_dilution_trigger_r1965',
    jsonb_build_object('trigger_id', v_id, 'investor_id', p_investor_id, 'label', p_label));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.list_anti_dilution_actions_r1965(p_trigger_id uuid DEFAULT NULL)
RETURNS SETOF public.investor_anti_dilution_action_log_r1965
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_anti_dilution_action_log_r1965
    WHERE p_trigger_id IS NULL OR trigger_id = p_trigger_id
    ORDER BY taken_at DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.log_anti_dilution_action_r1965(
  p_trigger_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_anti_dilution_action_log_r1965(trigger_id, action_type, by_email, notes_md)
  VALUES (p_trigger_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_anti_dilution_action_r1965',
    jsonb_build_object('action_id', v_id, 'trigger_id', p_trigger_id, 'action_type', p_action_type));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.mark_anti_dilution_trigger_status_r1965(
  p_trigger_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_anti_dilution_triggers_r1965
     SET status = p_status,
         finalized_at = CASE WHEN p_status = 'finalized' THEN now() ELSE finalized_at END,
         updated_at = now()
   WHERE id = p_trigger_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_anti_dilution_trigger_status_r1965',
    jsonb_build_object('trigger_id', p_trigger_id, 'status', p_status));
END;$$;

CREATE OR REPLACE FUNCTION public.recent_anti_dilution_triggers_r1965(p_limit int DEFAULT 20)
RETURNS SETOF public.investor_anti_dilution_triggers_r1965
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_anti_dilution_triggers_r1965
    ORDER BY trigger_event_at DESC LIMIT COALESCE(p_limit, 20);
END;$$;

CREATE OR REPLACE FUNCTION public.recent_anti_dilution_actions_r1965(p_limit int DEFAULT 20)
RETURNS SETOF public.investor_anti_dilution_action_log_r1965
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_anti_dilution_action_log_r1965
    ORDER BY taken_at DESC LIMIT COALESCE(p_limit, 20);
END;$$;

REVOKE EXECUTE ON FUNCTION public.list_anti_dilution_triggers_r1965() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_anti_dilution_trigger_r1965(uuid, text, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_anti_dilution_actions_r1965(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_anti_dilution_action_r1965(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_anti_dilution_trigger_status_r1965(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_anti_dilution_triggers_r1965(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_anti_dilution_actions_r1965(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_anti_dilution_triggers_r1965() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_anti_dilution_trigger_r1965(uuid, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_anti_dilution_actions_r1965(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_anti_dilution_action_r1965(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_anti_dilution_trigger_status_r1965(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_anti_dilution_triggers_r1965(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_anti_dilution_actions_r1965(int) TO authenticated;

COMMIT;
