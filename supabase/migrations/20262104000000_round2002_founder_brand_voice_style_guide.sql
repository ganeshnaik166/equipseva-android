BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_brand_voice_style_guide_r2002 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_attribute text NOT NULL CHECK (voice_attribute IN ('tone','diction','topics_covered','topics_avoided','cadence','visuals')),
  current_definition_md text NOT NULL,
  last_revised_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','being_revised')),
  revision_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_brand_voice_revision_log_r2002 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attribute_id uuid NOT NULL REFERENCES public.founder_brand_voice_style_guide_r2002(id) ON DELETE CASCADE,
  revision_md text NOT NULL,
  revision_reason text NOT NULL CHECK (revision_reason IN ('user_feedback','market_shift','founder_evolution','incident_response')),
  revised_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_brand_voice_style_guide_r2002 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_brand_voice_revision_log_r2002 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_style_guide_r2002 ON public.founder_brand_voice_style_guide_r2002;
CREATE POLICY p_founder_style_guide_r2002 ON public.founder_brand_voice_style_guide_r2002 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_revision_log_r2002 ON public.founder_brand_voice_revision_log_r2002;
CREATE POLICY p_founder_revision_log_r2002 ON public.founder_brand_voice_revision_log_r2002 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.founder_brand_voice_list_attributes_r2002()
RETURNS SETOF public.founder_brand_voice_style_guide_r2002
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_brand_voice_style_guide_r2002 ORDER BY last_revised_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_brand_voice_log_attribute_r2002(p_attr text, p_def_md text, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_brand_voice_style_guide_r2002(voice_attribute, current_definition_md, status)
  VALUES (p_attr, p_def_md, COALESCE(p_status,'active')) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'brand_voice_log_attribute_r2002', jsonb_build_object('id', v_id, 'attr', p_attr));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_brand_voice_list_revisions_r2002(p_attr_id uuid)
RETURNS SETOF public.founder_brand_voice_revision_log_r2002
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_brand_voice_revision_log_r2002 WHERE attribute_id = p_attr_id ORDER BY revised_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_brand_voice_log_revision_r2002(p_attr_id uuid, p_md text, p_reason text, p_by text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_brand_voice_revision_log_r2002(attribute_id, revision_md, revision_reason, by_email)
  VALUES (p_attr_id, p_md, p_reason, p_by) RETURNING id INTO v_id;
  UPDATE public.founder_brand_voice_style_guide_r2002
    SET revision_count = revision_count + 1, last_revised_at = now(), current_definition_md = p_md, updated_at = now()
    WHERE id = p_attr_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'brand_voice_log_revision_r2002', jsonb_build_object('id', v_id, 'attr_id', p_attr_id, 'reason', p_reason));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_brand_voice_mark_status_r2002(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_brand_voice_style_guide_r2002 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'brand_voice_mark_status_r2002', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.founder_brand_voice_current_voice_r2002()
RETURNS TABLE(voice_attribute text, current_definition_md text, last_revised_at timestamptz, revision_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT g.voice_attribute, g.current_definition_md, g.last_revised_at, g.revision_count
    FROM public.founder_brand_voice_style_guide_r2002 g WHERE g.status = 'active' ORDER BY g.voice_attribute;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_brand_voice_recent_revisions_r2002(p_limit int DEFAULT 20)
RETURNS TABLE(revision_id uuid, attribute_id uuid, voice_attribute text, revision_reason text, revised_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.attribute_id, g.voice_attribute, r.revision_reason, r.revised_at, r.by_email
    FROM public.founder_brand_voice_revision_log_r2002 r
    JOIN public.founder_brand_voice_style_guide_r2002 g ON g.id = r.attribute_id
    ORDER BY r.revised_at DESC LIMIT COALESCE(p_limit, 20);
END; $$;

REVOKE EXECUTE ON FUNCTION public.founder_brand_voice_list_attributes_r2002() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_brand_voice_log_attribute_r2002(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_brand_voice_list_revisions_r2002(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_brand_voice_log_revision_r2002(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_brand_voice_mark_status_r2002(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_brand_voice_current_voice_r2002() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_brand_voice_recent_revisions_r2002(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_brand_voice_list_attributes_r2002() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_brand_voice_log_attribute_r2002(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_brand_voice_list_revisions_r2002(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_brand_voice_log_revision_r2002(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_brand_voice_mark_status_r2002(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_brand_voice_current_voice_r2002() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_brand_voice_recent_revisions_r2002(int) TO authenticated;

COMMIT;
