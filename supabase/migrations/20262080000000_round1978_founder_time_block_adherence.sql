BEGIN;

-- ============================================================================
-- r1978 — Founder Time-Block Adherence (170-batch milestone tracker)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_time_block_adherence_r1978 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_label text NOT NULL,
  scheduled_minutes int NOT NULL DEFAULT 0,
  actual_minutes int NOT NULL DEFAULT 0,
  adherence_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'on_target'
    CHECK (status IN ('on_target','missed','exceeded','cancelled')),
  block_date date NOT NULL DEFAULT CURRENT_DATE,
  block_category text NOT NULL DEFAULT 'deep_work'
    CHECK (block_category IN ('deep_work','meetings','sales','ops','personal','recovery')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ftba_r1978_date
  ON public.founder_time_block_adherence_r1978(block_date DESC);
CREATE INDEX IF NOT EXISTS idx_ftba_r1978_status
  ON public.founder_time_block_adherence_r1978(status);
CREATE INDEX IF NOT EXISTS idx_ftba_r1978_cat
  ON public.founder_time_block_adherence_r1978(block_category);

CREATE TABLE IF NOT EXISTS public.founder_time_block_action_log_r1978 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid NOT NULL REFERENCES public.founder_time_block_adherence_r1978(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('started','interrupted','extended','completed','cancelled','rescheduled')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ftbal_r1978_block
  ON public.founder_time_block_action_log_r1978(block_id);
CREATE INDEX IF NOT EXISTS idx_ftbal_r1978_taken
  ON public.founder_time_block_action_log_r1978(taken_at DESC);

ALTER TABLE public.founder_time_block_adherence_r1978 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_time_block_action_log_r1978 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ftba_r1978_founder ON public.founder_time_block_adherence_r1978;
CREATE POLICY ftba_r1978_founder ON public.founder_time_block_adherence_r1978
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ftbal_r1978_founder ON public.founder_time_block_action_log_r1978;
CREATE POLICY ftbal_r1978_founder ON public.founder_time_block_action_log_r1978
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.list_time_blocks_r1978(int);
CREATE OR REPLACE FUNCTION public.list_time_blocks_r1978(p_limit int DEFAULT 100)
RETURNS SETOF public.founder_time_block_adherence_r1978
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.founder_time_block_adherence_r1978
    ORDER BY block_date DESC, created_at DESC
    LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS public.log_time_block_r1978(text, int, int, text, date, text);
CREATE OR REPLACE FUNCTION public.log_time_block_r1978(
  p_label text,
  p_scheduled int,
  p_actual int,
  p_status text,
  p_date date,
  p_category text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_pct numeric(6,2);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_pct := CASE WHEN p_scheduled = 0 THEN 0
                ELSE ROUND((p_actual::numeric / p_scheduled::numeric) * 100, 2)
           END;
  INSERT INTO public.founder_time_block_adherence_r1978
    (block_label, scheduled_minutes, actual_minutes, adherence_pct, status, block_date, block_category)
  VALUES (p_label, p_scheduled, p_actual, v_pct, p_status, p_date, p_category)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_time_block_r1978',
    jsonb_build_object('id', v_id, 'label', p_label, 'scheduled', p_scheduled, 'actual', p_actual)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_block_actions_r1978(uuid, int);
CREATE OR REPLACE FUNCTION public.list_block_actions_r1978(p_block_id uuid, p_limit int DEFAULT 100)
RETURNS SETOF public.founder_time_block_action_log_r1978
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.founder_time_block_action_log_r1978
    WHERE block_id = p_block_id
    ORDER BY taken_at DESC
    LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS public.log_block_action_r1978(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_block_action_r1978(
  p_block_id uuid,
  p_action text,
  p_email text,
  p_notes text
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
  INSERT INTO public.founder_time_block_action_log_r1978
    (block_id, action_type, by_email, notes_md)
  VALUES (p_block_id, p_action, p_email, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_block_action_r1978',
    jsonb_build_object('id', v_id, 'block_id', p_block_id, 'action', p_action)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_block_status_r1978(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_block_status_r1978(p_block_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_time_block_adherence_r1978
  SET status = p_status, updated_at = now()
  WHERE id = p_block_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_block_status_r1978',
    jsonb_build_object('id', p_block_id, 'status', p_status)
  );
END;
$$;

DROP FUNCTION IF EXISTS public.adherence_trend_r1978(int);
CREATE OR REPLACE FUNCTION public.adherence_trend_r1978(p_days int DEFAULT 14)
RETURNS TABLE(
  block_date date,
  total_blocks bigint,
  on_target_blocks bigint,
  missed_blocks bigint,
  avg_adherence numeric
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
      b.block_date,
      COUNT(*)::bigint,
      COUNT(*) FILTER (WHERE b.status = 'on_target')::bigint,
      COUNT(*) FILTER (WHERE b.status = 'missed')::bigint,
      ROUND(AVG(b.adherence_pct), 2)
    FROM public.founder_time_block_adherence_r1978 b
    WHERE b.block_date >= (CURRENT_DATE - (p_days || ' days')::interval)::date
    GROUP BY b.block_date
    ORDER BY b.block_date DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.recent_block_actions_r1978(int);
CREATE OR REPLACE FUNCTION public.recent_block_actions_r1978(p_limit int DEFAULT 50)
RETURNS SETOF public.founder_time_block_action_log_r1978
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.founder_time_block_action_log_r1978
    ORDER BY taken_at DESC
    LIMIT p_limit;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_time_blocks_r1978(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_time_blocks_r1978(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_time_block_r1978(text, int, int, text, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_time_block_r1978(text, int, int, text, date, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_block_actions_r1978(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_block_actions_r1978(uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_block_action_r1978(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_block_action_r1978(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_block_status_r1978(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_block_status_r1978(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.adherence_trend_r1978(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.adherence_trend_r1978(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_block_actions_r1978(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_block_actions_r1978(int) TO authenticated;

COMMIT;
