BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_thinking_weeks_r2397 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start_date date NOT NULL UNIQUE,
  target_block_count int NOT NULL DEFAULT 3 CHECK (target_block_count >= 0),
  target_total_minutes int NOT NULL DEFAULT 240 CHECK (target_total_minutes >= 0),
  week_theme text NOT NULL DEFAULT '',
  reflection_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_thinking_blocks_r2397 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_id uuid NOT NULL REFERENCES public.founder_thinking_weeks_r2397(id) ON DELETE CASCADE,
  block_date date NOT NULL,
  start_time time NOT NULL,
  duration_minutes int NOT NULL CHECK (duration_minutes > 0),
  topic text NOT NULL,
  was_protected boolean NOT NULL DEFAULT true,
  interruption_reason text,
  decision_emerged text NOT NULL DEFAULT '',
  decision_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quality_rating int CHECK (quality_rating BETWEEN 1 AND 5),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','interrupted','skipped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_thinking_blocks_week_r2397 ON public.founder_thinking_blocks_r2397(week_id);
CREATE INDEX IF NOT EXISTS idx_thinking_blocks_date_r2397 ON public.founder_thinking_blocks_r2397(block_date);

ALTER TABLE public.founder_thinking_weeks_r2397 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_thinking_blocks_r2397 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_weeks_r2397 ON public.founder_thinking_weeks_r2397;
CREATE POLICY founder_all_weeks_r2397 ON public.founder_thinking_weeks_r2397
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_blocks_r2397 ON public.founder_thinking_blocks_r2397;
CREATE POLICY founder_all_blocks_r2397 ON public.founder_thinking_blocks_r2397
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_weeks
CREATE OR REPLACE FUNCTION public.list_thinking_weeks_r2397()
RETURNS TABLE (
  id uuid,
  week_start_date date,
  target_block_count int,
  target_total_minutes int,
  week_theme text,
  completed_block_count int,
  completed_minutes int,
  decision_count int,
  target_met boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.week_start_date, w.target_block_count, w.target_total_minutes, w.week_theme,
    (SELECT (COUNT(*))::int FROM public.founder_thinking_blocks_r2397 b
      WHERE b.week_id = w.id AND b.status='completed') AS completed_block_count,
    (SELECT COALESCE(SUM(b.duration_minutes),0)::int FROM public.founder_thinking_blocks_r2397 b
      WHERE b.week_id = w.id AND b.status='completed') AS completed_minutes,
    (SELECT (COUNT(*))::int FROM public.founder_thinking_blocks_r2397 b
      WHERE b.week_id = w.id AND b.status='completed' AND length(trim(b.decision_emerged)) > 0) AS decision_count,
    (
      (SELECT (COUNT(*))::int FROM public.founder_thinking_blocks_r2397 b
        WHERE b.week_id = w.id AND b.status='completed') >= w.target_block_count
      AND
      (SELECT COALESCE(SUM(b.duration_minutes),0)::int FROM public.founder_thinking_blocks_r2397 b
        WHERE b.week_id = w.id AND b.status='completed') >= w.target_total_minutes
    ) AS target_met
  FROM public.founder_thinking_weeks_r2397 w
  ORDER BY w.week_start_date DESC;
END;
$$;

-- RPC 2: add_week
CREATE OR REPLACE FUNCTION public.add_thinking_week_r2397(
  p_week_start_date date,
  p_target_block_count int,
  p_target_total_minutes int,
  p_week_theme text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_thinking_weeks_r2397 (week_start_date, target_block_count, target_total_minutes, week_theme)
  VALUES (p_week_start_date, COALESCE(p_target_block_count,3), COALESCE(p_target_total_minutes,240), COALESCE(p_week_theme,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_thinking_week_r2397',
    jsonb_build_object('week_id', v_id, 'week_start', p_week_start_date, 'theme', p_week_theme));
  RETURN v_id;
END;
$$;

-- RPC 3: list_blocks
CREATE OR REPLACE FUNCTION public.list_thinking_blocks_r2397(p_week_id uuid)
RETURNS TABLE (
  id uuid,
  week_id uuid,
  block_date date,
  start_time time,
  duration_minutes int,
  topic text,
  was_protected boolean,
  interruption_reason text,
  decision_emerged text,
  decision_owner_email text,
  quality_rating int,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.week_id, b.block_date, b.start_time, b.duration_minutes, b.topic,
    b.was_protected, b.interruption_reason, b.decision_emerged,
    p.email AS decision_owner_email, b.quality_rating, b.status
  FROM public.founder_thinking_blocks_r2397 b
  LEFT JOIN public.profiles p ON p.id = b.decision_owner_id
  WHERE b.week_id = p_week_id
  ORDER BY b.block_date ASC, b.start_time ASC;
END;
$$;

-- RPC 4: add_block
CREATE OR REPLACE FUNCTION public.add_thinking_block_r2397(
  p_week_id uuid,
  p_block_date date,
  p_start_time time,
  p_duration_minutes int,
  p_topic text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_thinking_blocks_r2397 (week_id, block_date, start_time, duration_minutes, topic)
  VALUES (p_week_id, p_block_date, p_start_time, p_duration_minutes, p_topic)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_thinking_block_r2397',
    jsonb_build_object('block_id', v_id, 'week_id', p_week_id, 'topic', p_topic, 'duration', p_duration_minutes));
  RETURN v_id;
END;
$$;

-- RPC 5: complete_block
CREATE OR REPLACE FUNCTION public.complete_thinking_block_r2397(
  p_block_id uuid,
  p_was_protected boolean,
  p_interruption_reason text,
  p_decision_emerged text,
  p_decision_owner_id uuid,
  p_quality_rating int
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_thinking_blocks_r2397
  SET status = CASE WHEN p_was_protected THEN 'completed' ELSE 'interrupted' END,
      was_protected = COALESCE(p_was_protected, true),
      interruption_reason = p_interruption_reason,
      decision_emerged = COALESCE(p_decision_emerged, ''),
      decision_owner_id = p_decision_owner_id,
      quality_rating = p_quality_rating,
      updated_at = now()
  WHERE id = p_block_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_thinking_block_r2397',
    jsonb_build_object('block_id', p_block_id, 'protected', p_was_protected, 'quality', p_quality_rating));
END;
$$;

-- RPC 6: weekly_protection_rate
CREATE OR REPLACE FUNCTION public.thinking_protection_rate_r2397()
RETURNS TABLE (
  week_start_date date,
  total_blocks int,
  protected_blocks int,
  interrupted_blocks int,
  skipped_blocks int,
  protection_pct numeric,
  avg_quality numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.week_start_date,
    (COUNT(b.*))::int AS total_blocks,
    (COUNT(b.*) FILTER (WHERE b.status='completed' AND b.was_protected))::int AS protected_blocks,
    (COUNT(b.*) FILTER (WHERE b.status='interrupted'))::int AS interrupted_blocks,
    (COUNT(b.*) FILTER (WHERE b.status='skipped'))::int AS skipped_blocks,
    CASE WHEN COUNT(b.*) = 0 THEN 0::numeric
      ELSE ROUND((COUNT(b.*) FILTER (WHERE b.status='completed' AND b.was_protected))::numeric * 100.0 / COUNT(b.*), 2)
    END AS protection_pct,
    ROUND(AVG(b.quality_rating)::numeric, 2) AS avg_quality
  FROM public.founder_thinking_weeks_r2397 w
  LEFT JOIN public.founder_thinking_blocks_r2397 b ON b.week_id = w.id
  GROUP BY w.week_start_date
  ORDER BY w.week_start_date DESC;
END;
$$;

-- RPC 7: decisions_emerged
CREATE OR REPLACE FUNCTION public.thinking_decisions_emerged_r2397()
RETURNS TABLE (
  block_id uuid,
  week_start_date date,
  block_date date,
  topic text,
  decision_emerged text,
  decision_owner_email text,
  quality_rating int,
  duration_minutes int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id AS block_id, w.week_start_date, b.block_date, b.topic, b.decision_emerged,
    p.email AS decision_owner_email, b.quality_rating, b.duration_minutes
  FROM public.founder_thinking_blocks_r2397 b
  JOIN public.founder_thinking_weeks_r2397 w ON w.id = b.week_id
  LEFT JOIN public.profiles p ON p.id = b.decision_owner_id
  WHERE b.status='completed' AND length(trim(b.decision_emerged)) > 0
  ORDER BY b.block_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_thinking_weeks_r2397() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_thinking_week_r2397(date, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_thinking_blocks_r2397(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_thinking_block_r2397(uuid, date, time, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_thinking_block_r2397(uuid, boolean, text, text, uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.thinking_protection_rate_r2397() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.thinking_decisions_emerged_r2397() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_thinking_weeks_r2397() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_thinking_week_r2397(date, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_thinking_blocks_r2397(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_thinking_block_r2397(uuid, date, time, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_thinking_block_r2397(uuid, boolean, text, text, uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.thinking_protection_rate_r2397() TO authenticated;
GRANT EXECUTE ON FUNCTION public.thinking_decisions_emerged_r2397() TO authenticated;

COMMIT;
