BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_8x8_reporting_packs_r2009 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  pack_summary_md text NOT NULL DEFAULT '',
  key_metrics_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','acknowledged','archived')),
  generated_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_8x8_action_log_r2009 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id uuid NOT NULL REFERENCES public.investor_8x8_reporting_packs_r2009(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('generated','sent','acknowledged','superseded','archived')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_8x8_reporting_packs_r2009 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_8x8_action_log_r2009 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_packs_r2009 ON public.investor_8x8_reporting_packs_r2009;
CREATE POLICY founder_all_packs_r2009 ON public.investor_8x8_reporting_packs_r2009
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2009 ON public.investor_8x8_action_log_r2009;
CREATE POLICY founder_all_actions_r2009 ON public.investor_8x8_action_log_r2009
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_packs_r2009()
RETURNS SETOF public.investor_8x8_reporting_packs_r2009
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_8x8_reporting_packs_r2009 ORDER BY created_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_pack_r2009(p_period_label text, p_pack_summary_md text, p_key_metrics_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_8x8_reporting_packs_r2009(period_label, pack_summary_md, key_metrics_md, generated_at)
    VALUES (p_period_label, COALESCE(p_pack_summary_md,''), COALESCE(p_key_metrics_md,''), now())
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pack_r2009', jsonb_build_object('id', v_id, 'period_label', p_period_label));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2009(p_pack_id uuid)
RETURNS SETOF public.investor_8x8_action_log_r2009
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_8x8_action_log_r2009 WHERE pack_id = p_pack_id ORDER BY taken_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2009(p_pack_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_8x8_action_log_r2009(pack_id, action_type, by_email, notes_md)
    VALUES (p_pack_id, p_action_type, p_by_email, COALESCE(p_notes_md,''))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2009', jsonb_build_object('id', v_id, 'pack_id', p_pack_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2009(p_pack_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('draft','sent','acknowledged','archived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_8x8_reporting_packs_r2009
    SET status = p_status,
        sent_at = CASE WHEN p_status = 'sent' THEN now() ELSE sent_at END,
        updated_at = now()
    WHERE id = p_pack_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2009', jsonb_build_object('pack_id', p_pack_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.recent_packs_r2009()
RETURNS SETOF public.investor_8x8_reporting_packs_r2009
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_8x8_reporting_packs_r2009 ORDER BY created_at DESC LIMIT 25;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2009()
RETURNS SETOF public.investor_8x8_action_log_r2009
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_8x8_action_log_r2009 ORDER BY taken_at DESC LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_packs_r2009() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pack_r2009(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2009(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2009(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2009(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_packs_r2009() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2009() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_packs_r2009() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pack_r2009(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2009(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2009(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2009(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_packs_r2009() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2009() TO authenticated;

COMMIT;
