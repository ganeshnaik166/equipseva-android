BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_cadence_r1882 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date UNIQUE NOT NULL,
  keep_md text NOT NULL DEFAULT '',
  stop_md text NOT NULL DEFAULT '',
  start_md text NOT NULL DEFAULT '',
  founder_score int CHECK (founder_score BETWEEN 1 AND 10),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_cadence_actions_r1882 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cadence_id uuid NOT NULL REFERENCES public.founder_weekly_cadence_r1882(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('keep','stop','start')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcad_actions_cadence_r1882 ON public.founder_cadence_actions_r1882(cadence_id);
CREATE INDEX IF NOT EXISTS idx_fcad_actions_status_r1882 ON public.founder_cadence_actions_r1882(status);
CREATE INDEX IF NOT EXISTS idx_fcad_week_r1882 ON public.founder_weekly_cadence_r1882(week_start DESC);

ALTER TABLE public.founder_weekly_cadence_r1882 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_cadence_actions_r1882 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_cadence_r1882 ON public.founder_weekly_cadence_r1882;
CREATE POLICY founder_only_cadence_r1882 ON public.founder_weekly_cadence_r1882
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_actions_r1882 ON public.founder_cadence_actions_r1882;
CREATE POLICY founder_only_actions_r1882 ON public.founder_cadence_actions_r1882
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_cadences_r1882()
RETURNS TABLE(
  id uuid,
  week_start date,
  founder_score int,
  status text,
  recorded_at timestamptz,
  keep_len int,
  stop_len int,
  start_len int,
  action_count int,
  done_count int
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
  SELECT
    c.id,
    c.week_start,
    c.founder_score,
    c.status,
    c.recorded_at,
    length(c.keep_md)::int,
    length(c.stop_md)::int,
    length(c.start_md)::int,
    (SELECT COUNT(*) FROM public.founder_cadence_actions_r1882 a WHERE a.cadence_id = c.id)::int,
    (SELECT COUNT(*) FILTER (WHERE a.status = 'done') FROM public.founder_cadence_actions_r1882 a WHERE a.cadence_id = c.id)::int
  FROM public.founder_weekly_cadence_r1882 c
  ORDER BY c.week_start DESC
  LIMIT 26;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_cadence_r1882(
  p_week_start date,
  p_keep text,
  p_stop text,
  p_start text,
  p_score int
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
  INSERT INTO public.founder_weekly_cadence_r1882(week_start, keep_md, stop_md, start_md, founder_score)
  VALUES (p_week_start, COALESCE(p_keep,''), COALESCE(p_stop,''), COALESCE(p_start,''), p_score)
  ON CONFLICT (week_start) DO UPDATE
    SET keep_md = EXCLUDED.keep_md,
        stop_md = EXCLUDED.stop_md,
        start_md = EXCLUDED.start_md,
        founder_score = EXCLUDED.founder_score,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_cadence_r1882',
          jsonb_build_object('cadence_id', v_id, 'week_start', p_week_start, 'score', p_score));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1882(p_cadence_id uuid)
RETURNS TABLE(
  id uuid,
  action_text text,
  action_type text,
  status text,
  completed_at timestamptz,
  created_at timestamptz
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
  SELECT a.id, a.action_text, a.action_type, a.status, a.completed_at, a.created_at
  FROM public.founder_cadence_actions_r1882 a
  WHERE a.cadence_id = p_cadence_id
  ORDER BY a.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1882(
  p_cadence_id uuid,
  p_text text,
  p_type text
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
  IF p_type NOT IN ('keep','stop','start') THEN
    RAISE EXCEPTION 'invalid_type';
  END IF;
  INSERT INTO public.founder_cadence_actions_r1882(cadence_id, action_text, action_type)
  VALUES (p_cadence_id, p_text, p_type)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1882',
          jsonb_build_object('action_id', v_id, 'cadence_id', p_cadence_id, 'type', p_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_action_r1882(
  p_action_id uuid,
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
  IF p_status NOT IN ('open','done','dropped') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.founder_cadence_actions_r1882
  SET status = p_status,
      completed_at = CASE WHEN p_status = 'done' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_action_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_action_r1882',
          jsonb_build_object('action_id', p_action_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_themes_r1882()
RETURNS TABLE(
  action_type text,
  total_count int,
  open_count int,
  done_count int,
  dropped_count int
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
  SELECT
    a.action_type,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE a.status = 'open'))::int,
    (COUNT(*) FILTER (WHERE a.status = 'done'))::int,
    (COUNT(*) FILTER (WHERE a.status = 'dropped'))::int
  FROM public.founder_cadence_actions_r1882 a
  JOIN public.founder_weekly_cadence_r1882 c ON c.id = a.cadence_id
  WHERE c.week_start >= (CURRENT_DATE - INTERVAL '90 days')
  GROUP BY a.action_type
  ORDER BY a.action_type;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_score_trend_r1882()
RETURNS TABLE(
  week_start date,
  founder_score int,
  rolling_avg numeric
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
  SELECT
    c.week_start,
    c.founder_score,
    ROUND(AVG(c.founder_score) OVER (ORDER BY c.week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)::numeric, 2)
  FROM public.founder_weekly_cadence_r1882 c
  WHERE c.founder_score IS NOT NULL
  ORDER BY c.week_start DESC
  LIMIT 12;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_cadences_r1882() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_cadence_r1882(date,text,text,text,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1882(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1882(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_action_r1882(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_themes_r1882() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_score_trend_r1882() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cadences_r1882() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_cadence_r1882(date,text,text,text,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1882(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1882(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_action_r1882(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_themes_r1882() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_score_trend_r1882() TO authenticated;

COMMIT;