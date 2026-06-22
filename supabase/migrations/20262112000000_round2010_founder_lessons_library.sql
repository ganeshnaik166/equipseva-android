BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_lessons_library_r2010 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_label text NOT NULL,
  lesson_md text NOT NULL,
  lesson_category text NOT NULL CHECK (lesson_category IN ('sales','hiring','product','financial','operational','personal','strategy','marketing')),
  source_event_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_lesson_reference_log_r2010 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.founder_lessons_library_r2010(id) ON DELETE CASCADE,
  reference_context_md text NOT NULL,
  referenced_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_lessons_library_r2010 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_lesson_reference_log_r2010 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lessons_library_founder_all ON public.founder_lessons_library_r2010;
CREATE POLICY lessons_library_founder_all ON public.founder_lessons_library_r2010
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS lesson_ref_log_founder_all ON public.founder_lesson_reference_log_r2010;
CREATE POLICY lesson_ref_log_founder_all ON public.founder_lesson_reference_log_r2010
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_lessons_r2010(p_status text DEFAULT NULL, p_category text DEFAULT NULL)
RETURNS TABLE(id uuid, lesson_label text, lesson_md text, lesson_category text, source_event_md text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.lesson_label, l.lesson_md, l.lesson_category, l.source_event_md, l.status, l.captured_at
  FROM public.founder_lessons_library_r2010 l
  WHERE (p_status IS NULL OR l.status = p_status)
    AND (p_category IS NULL OR l.lesson_category = p_category)
  ORDER BY l.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_lesson_r2010(p_label text, p_md text, p_category text, p_source_event_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_lessons_library_r2010(lesson_label, lesson_md, lesson_category, source_event_md)
  VALUES (p_label, p_md, p_category, p_source_event_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lesson_r2010',
    jsonb_build_object('lesson_id', v_id, 'label', p_label, 'category', p_category));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_references_r2010(p_lesson_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid, lesson_id uuid, lesson_label text, reference_context_md text, referenced_at timestamptz, by_email text, outcome_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.lesson_id, l.lesson_label, r.reference_context_md, r.referenced_at, r.by_email, r.outcome_md
  FROM public.founder_lesson_reference_log_r2010 r
  JOIN public.founder_lessons_library_r2010 l ON l.id = r.lesson_id
  WHERE (p_lesson_id IS NULL OR r.lesson_id = p_lesson_id)
  ORDER BY r.referenced_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reference_r2010(p_lesson_id uuid, p_context_md text, p_by_email text, p_outcome_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_lesson_reference_log_r2010(lesson_id, reference_context_md, by_email, outcome_md)
  VALUES (p_lesson_id, p_context_md, p_by_email, p_outcome_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reference_r2010',
    jsonb_build_object('reference_id', v_id, 'lesson_id', p_lesson_id));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2010(p_lesson_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_lessons_library_r2010
  SET status = p_status, updated_at = now()
  WHERE id = p_lesson_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2010',
    jsonb_build_object('lesson_id', p_lesson_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_categories_r2010()
RETURNS TABLE(lesson_category text, lesson_count bigint, active_count bigint, last_captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.lesson_category,
         count(*)::bigint AS lesson_count,
         count(*) FILTER (WHERE l.status = 'active')::bigint AS active_count,
         max(l.captured_at) AS last_captured_at
  FROM public.founder_lessons_library_r2010 l
  GROUP BY l.lesson_category
  ORDER BY lesson_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_references_r2010(p_limit int DEFAULT 25)
RETURNS TABLE(id uuid, lesson_id uuid, lesson_label text, lesson_category text, reference_context_md text, referenced_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.lesson_id, l.lesson_label, l.lesson_category, r.reference_context_md, r.referenced_at, r.by_email
  FROM public.founder_lesson_reference_log_r2010 r
  JOIN public.founder_lessons_library_r2010 l ON l.id = r.lesson_id
  ORDER BY r.referenced_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 25), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_lessons_r2010(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lesson_r2010(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_references_r2010(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reference_r2010(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2010(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_categories_r2010() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_references_r2010(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_lessons_r2010(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lesson_r2010(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_references_r2010(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reference_r2010(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2010(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_categories_r2010() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_references_r2010(int) TO authenticated;

COMMIT;
