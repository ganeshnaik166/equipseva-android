BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_1200_ship_reflection_r2026 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL,
  top_three_wins_md text NOT NULL,
  top_three_misses_md text NOT NULL,
  founder_personal_takeaways_md text NOT NULL,
  next_500_ship_plan_md text NOT NULL,
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_1200_ship_signal_log_r2026 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reflection_id uuid NOT NULL REFERENCES public.founder_1200_ship_reflection_r2026(id) ON DELETE CASCADE,
  signal_type text NOT NULL CHECK (signal_type IN ('team_reaction','customer_reaction','investor_reaction','external_observer','founder_emotion')),
  signal_md text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_1200_ship_reflection_r2026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_1200_ship_signal_log_r2026 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2026_refl ON public.founder_1200_ship_reflection_r2026;
CREATE POLICY founder_all_r2026_refl ON public.founder_1200_ship_reflection_r2026
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2026_signal ON public.founder_1200_ship_signal_log_r2026;
CREATE POLICY founder_all_r2026_signal ON public.founder_1200_ship_signal_log_r2026
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_reflections_r2026()
RETURNS TABLE (
  id uuid,
  milestone_label text,
  written_at timestamptz,
  summary_md text,
  top_three_wins_md text,
  top_three_misses_md text,
  founder_personal_takeaways_md text,
  next_500_ship_plan_md text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.milestone_label, r.written_at, r.summary_md, r.top_three_wins_md,
         r.top_three_misses_md, r.founder_personal_takeaways_md, r.next_500_ship_plan_md, r.status
  FROM public.founder_1200_ship_reflection_r2026 r
  ORDER BY r.written_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reflection_r2026(
  p_milestone_label text,
  p_summary_md text,
  p_top_three_wins_md text,
  p_top_three_misses_md text,
  p_founder_personal_takeaways_md text,
  p_next_500_ship_plan_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_1200_ship_reflection_r2026 (
    milestone_label, summary_md, top_three_wins_md, top_three_misses_md,
    founder_personal_takeaways_md, next_500_ship_plan_md
  ) VALUES (
    p_milestone_label, p_summary_md, p_top_three_wins_md, p_top_three_misses_md,
    p_founder_personal_takeaways_md, p_next_500_ship_plan_md
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reflection_r2026',
          jsonb_build_object('id', v_id, 'milestone_label', p_milestone_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_signals_r2026(p_reflection_id uuid)
RETURNS TABLE (
  id uuid,
  reflection_id uuid,
  signal_type text,
  signal_md text,
  recorded_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.reflection_id, s.signal_type, s.signal_md, s.recorded_at, s.by_email
  FROM public.founder_1200_ship_signal_log_r2026 s
  WHERE s.reflection_id = p_reflection_id
  ORDER BY s.recorded_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_signal_r2026(
  p_reflection_id uuid,
  p_signal_type text,
  p_signal_md text,
  p_by_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_1200_ship_signal_log_r2026 (
    reflection_id, signal_type, signal_md, by_email
  ) VALUES (p_reflection_id, p_signal_type, p_signal_md, p_by_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_signal_r2026',
          jsonb_build_object('id', v_id, 'reflection_id', p_reflection_id, 'signal_type', p_signal_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2026(p_reflection_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('published','archived') THEN RAISE EXCEPTION 'bad status'; END IF;
  UPDATE public.founder_1200_ship_reflection_r2026
  SET status = p_status, updated_at = now()
  WHERE id = p_reflection_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2026',
          jsonb_build_object('id', p_reflection_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_signals_r2026()
RETURNS TABLE (
  id uuid,
  reflection_id uuid,
  milestone_label text,
  signal_type text,
  signal_md text,
  recorded_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.reflection_id, r.milestone_label, s.signal_type, s.signal_md, s.recorded_at, s.by_email
  FROM public.founder_1200_ship_signal_log_r2026 s
  JOIN public.founder_1200_ship_reflection_r2026 r ON r.id = s.reflection_id
  ORDER BY s.recorded_at DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_signals_r2026()
RETURNS TABLE (
  signal_type text,
  signal_count bigint,
  latest_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.signal_type, COUNT(*)::bigint AS signal_count, MAX(s.recorded_at) AS latest_at
  FROM public.founder_1200_ship_signal_log_r2026 s
  GROUP BY s.signal_type
  ORDER BY signal_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reflections_r2026() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reflection_r2026(text, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_signals_r2026(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_signal_r2026(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2026(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_signals_r2026() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_signals_r2026() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reflections_r2026() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reflection_r2026(text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_signals_r2026(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_signal_r2026(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2026(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_signals_r2026() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_signals_r2026() TO authenticated;

COMMIT;
