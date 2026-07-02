BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_round_pipeline_funnel_r2041 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  intro_date date,
  qualified_date date,
  term_sheet_date date,
  closed_date date,
  declined_date date,
  round_label text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','qualified','term_signed','closed','declined','walked_away')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_pipeline_action_log_r2041 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  funnel_id uuid NOT NULL REFERENCES public.investor_round_pipeline_funnel_r2041(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('qualified','term_sent','term_received','closed','declined','walked')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_round_pipeline_funnel_r2041 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_pipeline_action_log_r2041 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_funnel_r2041 ON public.investor_round_pipeline_funnel_r2041;
CREATE POLICY founder_all_funnel_r2041 ON public.investor_round_pipeline_funnel_r2041
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2041 ON public.investor_pipeline_action_log_r2041;
CREATE POLICY founder_all_action_r2041 ON public.investor_pipeline_action_log_r2041
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_funnels_r2041()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  intro_date date,
  qualified_date date,
  term_sheet_date date,
  closed_date date,
  declined_date date,
  round_label text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT f.id, f.investor_id, f.intro_date, f.qualified_date, f.term_sheet_date,
           f.closed_date, f.declined_date, f.round_label, f.status, f.captured_at
    FROM public.investor_round_pipeline_funnel_r2041 f
    ORDER BY f.captured_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_funnel_r2041(
  p_investor_id uuid,
  p_intro_date date,
  p_round_label text,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_round_pipeline_funnel_r2041(investor_id, intro_date, round_label, status)
  VALUES (p_investor_id, p_intro_date, p_round_label, COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_funnel_r2041',
          jsonb_build_object('funnel_id', v_id, 'investor_id', p_investor_id, 'round_label', p_round_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2041(p_funnel_id uuid)
RETURNS TABLE (
  id uuid,
  funnel_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT a.id, a.funnel_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_pipeline_action_log_r2041 a
    WHERE p_funnel_id IS NULL OR a.funnel_id = p_funnel_id
    ORDER BY a.taken_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2041(
  p_funnel_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_pipeline_action_log_r2041(funnel_id, action_type, by_email, notes_md)
  VALUES (p_funnel_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2041',
          jsonb_build_object('action_id', v_id, 'funnel_id', p_funnel_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2041(
  p_funnel_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_round_pipeline_funnel_r2041
  SET status = p_status, updated_at = now()
  WHERE id = p_funnel_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2041',
          jsonb_build_object('funnel_id', p_funnel_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.active_funnels_r2041()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  round_label text,
  status text,
  intro_date date,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT f.id, f.investor_id, f.round_label, f.status, f.intro_date, f.captured_at
    FROM public.investor_round_pipeline_funnel_r2041 f
    WHERE f.status IN ('active','qualified','term_signed')
    ORDER BY f.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2041()
RETURNS TABLE (
  id uuid,
  funnel_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT a.id, a.funnel_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_pipeline_action_log_r2041 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_funnels_r2041() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_funnel_r2041(uuid, date, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2041(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2041(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2041(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_funnels_r2041() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2041() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_funnels_r2041() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_funnel_r2041(uuid, date, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2041(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2041(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2041(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_funnels_r2041() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2041() TO authenticated;

COMMIT;
