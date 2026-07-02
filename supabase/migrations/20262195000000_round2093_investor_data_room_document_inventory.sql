BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_data_room_inventory_r2093 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_label text NOT NULL,
  document_category text NOT NULL CHECK (document_category IN ('financial','legal','contracts','business','technical','regulatory')),
  document_version text NOT NULL DEFAULT 'v1',
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','superseded','archived','retracted')),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_inventory_action_log_r2093 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_id uuid NOT NULL REFERENCES public.investor_data_room_inventory_r2093(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('uploaded','superseded','retracted','archived','version_updated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_data_room_inventory_r2093 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_inventory_action_log_r2093 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_inventory_r2093 ON public.investor_data_room_inventory_r2093;
CREATE POLICY founder_all_inventory_r2093 ON public.investor_data_room_inventory_r2093
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2093 ON public.investor_inventory_action_log_r2093;
CREATE POLICY founder_all_action_log_r2093 ON public.investor_inventory_action_log_r2093
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_docs_r2093()
RETURNS TABLE (id uuid, document_label text, document_category text, document_version text, status text, last_updated_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.document_label, d.document_category, d.document_version, d.status, d.last_updated_at
  FROM public.investor_data_room_inventory_r2093 d
  ORDER BY d.last_updated_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_doc_r2093(p_label text, p_category text, p_version text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_data_room_inventory_r2093(document_label, document_category, document_version)
  VALUES (p_label, p_category, COALESCE(p_version, 'v1'))
  RETURNING id INTO v_id;
  INSERT INTO public.investor_inventory_action_log_r2093(doc_id, action_type, by_email, notes_md)
  VALUES (v_id, 'uploaded', (auth.jwt()->>'email'), p_notes);
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_doc_r2093', jsonb_build_object('id', v_id, 'label', p_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2093(p_doc_id uuid)
RETURNS TABLE (id uuid, doc_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.doc_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_inventory_action_log_r2093 a
  WHERE (p_doc_id IS NULL OR a.doc_id = p_doc_id)
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2093(p_doc_id uuid, p_action_type text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_inventory_action_log_r2093(doc_id, action_type, by_email, notes_md)
  VALUES (p_doc_id, p_action_type, (auth.jwt()->>'email'), p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2093', jsonb_build_object('id', v_id, 'doc_id', p_doc_id, 'action', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2093(p_doc_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_data_room_inventory_r2093
  SET status = p_status, last_updated_at = now(), updated_at = now()
  WHERE id = p_doc_id;
  INSERT INTO public.investor_inventory_action_log_r2093(doc_id, action_type, by_email, notes_md)
  VALUES (p_doc_id,
    CASE WHEN p_status = 'superseded' THEN 'superseded'
         WHEN p_status = 'retracted' THEN 'retracted'
         WHEN p_status = 'archived' THEN 'archived'
         ELSE 'version_updated' END,
    (auth.jwt()->>'email'),
    'status changed to ' || p_status);
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2093', jsonb_build_object('id', p_doc_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.current_inventory_r2093()
RETURNS TABLE (document_category text, current_count bigint, superseded_count bigint, archived_count bigint, retracted_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.document_category,
    COUNT(*) FILTER (WHERE d.status = 'current') AS current_count,
    COUNT(*) FILTER (WHERE d.status = 'superseded') AS superseded_count,
    COUNT(*) FILTER (WHERE d.status = 'archived') AS archived_count,
    COUNT(*) FILTER (WHERE d.status = 'retracted') AS retracted_count
  FROM public.investor_data_room_inventory_r2093 d
  GROUP BY d.document_category
  ORDER BY d.document_category;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2093()
RETURNS TABLE (id uuid, doc_id uuid, document_label text, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.doc_id, d.document_label, a.action_type, a.taken_at, a.by_email
  FROM public.investor_inventory_action_log_r2093 a
  LEFT JOIN public.investor_data_room_inventory_r2093 d ON d.id = a.doc_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_docs_r2093() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_doc_r2093(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2093(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2093(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2093(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_inventory_r2093() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2093() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_docs_r2093() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_doc_r2093(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2093(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2093(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2093(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_inventory_r2093() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2093() TO authenticated;

COMMIT;
