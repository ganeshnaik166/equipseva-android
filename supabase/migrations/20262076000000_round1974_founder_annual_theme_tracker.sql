BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_annual_themes_r1974 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year int NOT NULL,
  theme_label text NOT NULL,
  theme_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','missed')),
  theme_committed_at timestamptz NOT NULL DEFAULT now(),
  theme_completed_at timestamptz,
  retro_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_theme_progress_log_r1974 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  theme_id uuid NOT NULL REFERENCES public.founder_annual_themes_r1974(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  progress_score int NOT NULL CHECK (progress_score BETWEEN 1 AND 10),
  progress_md text,
  logged_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_annual_themes_r1974 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_theme_progress_log_r1974 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_themes_founder ON public.founder_annual_themes_r1974;
CREATE POLICY p_themes_founder ON public.founder_annual_themes_r1974
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_theme_progress_founder ON public.founder_theme_progress_log_r1974;
CREATE POLICY p_theme_progress_founder ON public.founder_theme_progress_log_r1974
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_themes_r1974()
RETURNS TABLE(id uuid, year int, theme_label text, theme_md text, status text, theme_committed_at timestamptz, theme_completed_at timestamptz, retro_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.year, t.theme_label, t.theme_md, t.status, t.theme_committed_at, t.theme_completed_at, t.retro_md
    FROM public.founder_annual_themes_r1974 t
    ORDER BY t.year DESC, t.theme_committed_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_theme_r1974(p_year int, p_label text, p_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_annual_themes_r1974(year, theme_label, theme_md)
    VALUES (p_year, p_label, p_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_theme_r1974',
      jsonb_build_object('id', v_id, 'year', p_year, 'label', p_label));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_progress_r1974(p_theme_id uuid)
RETURNS TABLE(id uuid, theme_id uuid, quarter_label text, progress_score int, progress_md text, logged_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.theme_id, p.quarter_label, p.progress_score, p.progress_md, p.logged_at, p.by_email
    FROM public.founder_theme_progress_log_r1974 p
    WHERE p.theme_id = p_theme_id
    ORDER BY p.logged_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_progress_r1974(p_theme_id uuid, p_quarter text, p_score int, p_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_theme_progress_log_r1974(theme_id, quarter_label, progress_score, progress_md, by_email)
    VALUES (p_theme_id, p_quarter, p_score, p_md, (auth.jwt()->>'email'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_progress_r1974',
      jsonb_build_object('id', v_id, 'theme_id', p_theme_id, 'quarter', p_quarter, 'score', p_score));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1974(p_theme_id uuid, p_status text, p_retro_md text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','archived','missed') THEN
    RAISE EXCEPTION 'bad status';
  END IF;
  UPDATE public.founder_annual_themes_r1974
    SET status = p_status,
        retro_md = COALESCE(p_retro_md, retro_md),
        theme_completed_at = CASE WHEN p_status IN ('archived','missed') THEN now() ELSE theme_completed_at END,
        updated_at = now()
    WHERE id = p_theme_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1974',
      jsonb_build_object('id', p_theme_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.current_theme_r1974()
RETURNS TABLE(id uuid, year int, theme_label text, theme_md text, status text, theme_committed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.year, t.theme_label, t.theme_md, t.status, t.theme_committed_at
    FROM public.founder_annual_themes_r1974 t
    WHERE t.status = 'active'
    ORDER BY t.year DESC, t.theme_committed_at DESC
    LIMIT 1;
END $$;

CREATE OR REPLACE FUNCTION public.recent_progress_r1974()
RETURNS TABLE(id uuid, theme_id uuid, theme_label text, quarter_label text, progress_score int, progress_md text, logged_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.theme_id, t.theme_label, p.quarter_label, p.progress_score, p.progress_md, p.logged_at, p.by_email
    FROM public.founder_theme_progress_log_r1974 p
    JOIN public.founder_annual_themes_r1974 t ON t.id = p.theme_id
    ORDER BY p.logged_at DESC
    LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_themes_r1974() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_theme_r1974(int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_progress_r1974(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_progress_r1974(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1974(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_theme_r1974() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_progress_r1974() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_themes_r1974() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_theme_r1974(int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_progress_r1974(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_progress_r1974(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1974(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_theme_r1974() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_progress_r1974() TO authenticated;

COMMIT;
