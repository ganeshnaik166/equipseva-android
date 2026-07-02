BEGIN;

-- ============================================================================
-- Round 1806 — Founder Sprint Retro Board
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_sprint_retros_r1806 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sprint_label text NOT NULL,
  sprint_start date NOT NULL,
  sprint_end date NOT NULL,
  what_worked_md text,
  what_didnt_md text,
  next_sprint_focus_md text,
  founder_score int CHECK (founder_score BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed','archived')),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_sprint_retro_actions_r1806 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retro_id uuid NOT NULL REFERENCES public.founder_sprint_retros_r1806(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_retros_r1806_status ON public.founder_sprint_retros_r1806(status, sprint_start DESC);
CREATE INDEX IF NOT EXISTS idx_retro_actions_r1806_retro ON public.founder_sprint_retro_actions_r1806(retro_id, status);

ALTER TABLE public.founder_sprint_retros_r1806 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_sprint_retro_actions_r1806 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS retros_r1806_founder ON public.founder_sprint_retros_r1806;
CREATE POLICY retros_r1806_founder ON public.founder_sprint_retros_r1806
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS retro_actions_r1806_founder ON public.founder_sprint_retro_actions_r1806;
CREATE POLICY retro_actions_r1806_founder ON public.founder_sprint_retro_actions_r1806
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_retros
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_retros_r1806()
RETURNS TABLE (
  id uuid,
  sprint_label text,
  sprint_start date,
  sprint_end date,
  founder_score int,
  status text,
  closed_at timestamptz,
  action_count bigint,
  open_action_count bigint,
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
  SELECT
    r.id,
    r.sprint_label,
    r.sprint_start,
    r.sprint_end,
    r.founder_score,
    r.status,
    r.closed_at,
    (SELECT COUNT(*) FROM public.founder_sprint_retro_actions_r1806 a WHERE a.retro_id = r.id),
    (SELECT COUNT(*) FROM public.founder_sprint_retro_actions_r1806 a WHERE a.retro_id = r.id AND a.status = 'open'),
    r.created_at
  FROM public.founder_sprint_retros_r1806 r
  ORDER BY r.sprint_start DESC, r.created_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- RPC 2: log_retro
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_retro_r1806(
  p_sprint_label text,
  p_sprint_start date,
  p_sprint_end date,
  p_what_worked_md text,
  p_what_didnt_md text,
  p_next_sprint_focus_md text,
  p_founder_score int
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

  INSERT INTO public.founder_sprint_retros_r1806(
    sprint_label, sprint_start, sprint_end,
    what_worked_md, what_didnt_md, next_sprint_focus_md,
    founder_score
  )
  VALUES (p_sprint_label, p_sprint_start, p_sprint_end,
          p_what_worked_md, p_what_didnt_md, p_next_sprint_focus_md,
          p_founder_score)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_retro_r1806',
          jsonb_build_object('id', v_id, 'sprint_label', p_sprint_label, 'score', p_founder_score));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1806(p_retro_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  retro_id uuid,
  sprint_label text,
  action_text text,
  owner_email text,
  due_date date,
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
  SELECT
    a.id, a.retro_id, r.sprint_label,
    a.action_text, a.owner_email, a.due_date,
    a.status, a.completed_at, a.created_at
  FROM public.founder_sprint_retro_actions_r1806 a
  JOIN public.founder_sprint_retros_r1806 r ON r.id = a.retro_id
  WHERE (p_retro_id IS NULL OR a.retro_id = p_retro_id)
  ORDER BY
    CASE a.status WHEN 'open' THEN 0 WHEN 'done' THEN 1 ELSE 2 END,
    a.due_date NULLS LAST,
    a.created_at DESC
  LIMIT 300;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1806(
  p_retro_id uuid,
  p_action_text text,
  p_owner_email text,
  p_due_date date
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

  INSERT INTO public.founder_sprint_retro_actions_r1806(
    retro_id, action_text, owner_email, due_date
  )
  VALUES (p_retro_id, p_action_text, p_owner_email, p_due_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1806',
          jsonb_build_object('id', v_id, 'retro_id', p_retro_id, 'owner_email', p_owner_email));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: close_retro
-- ============================================================================
CREATE OR REPLACE FUNCTION public.close_retro_r1806(p_retro_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_sprint_retros_r1806
  SET status = 'closed',
      closed_at = now(),
      updated_at = now()
  WHERE id = p_retro_id AND status = 'active';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_retro_r1806',
          jsonb_build_object('id', p_retro_id));
END;
$$;

-- ============================================================================
-- RPC 6: average_sprint_score
-- ============================================================================
CREATE OR REPLACE FUNCTION public.average_sprint_score_r1806()
RETURNS TABLE (
  total_retros bigint,
  closed_retros bigint,
  active_retros bigint,
  avg_score numeric,
  last_score int,
  best_score int,
  worst_score int,
  total_actions bigint,
  open_actions bigint,
  done_actions bigint
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
    (SELECT COUNT(*) FROM public.founder_sprint_retros_r1806),
    (SELECT COUNT(*) FROM public.founder_sprint_retros_r1806 WHERE status = 'closed'),
    (SELECT COUNT(*) FROM public.founder_sprint_retros_r1806 WHERE status = 'active'),
    (SELECT ROUND(AVG(founder_score)::numeric, 2) FROM public.founder_sprint_retros_r1806 WHERE founder_score IS NOT NULL),
    (SELECT founder_score FROM public.founder_sprint_retros_r1806 WHERE founder_score IS NOT NULL ORDER BY sprint_end DESC LIMIT 1),
    (SELECT MAX(founder_score) FROM public.founder_sprint_retros_r1806),
    (SELECT MIN(founder_score) FROM public.founder_sprint_retros_r1806),
    (SELECT COUNT(*) FROM public.founder_sprint_retro_actions_r1806),
    (SELECT COUNT(*) FROM public.founder_sprint_retro_actions_r1806 WHERE status = 'open'),
    (SELECT COUNT(*) FROM public.founder_sprint_retro_actions_r1806 WHERE status = 'done');
END;
$$;

-- ============================================================================
-- RPC 7: recent_themes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_themes_r1806()
RETURNS TABLE (
  sprint_label text,
  sprint_end date,
  founder_score int,
  status text,
  what_worked_excerpt text,
  what_didnt_excerpt text,
  next_focus_excerpt text,
  open_action_count bigint
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
    r.sprint_label,
    r.sprint_end,
    r.founder_score,
    r.status,
    LEFT(COALESCE(r.what_worked_md, ''), 240),
    LEFT(COALESCE(r.what_didnt_md, ''), 240),
    LEFT(COALESCE(r.next_sprint_focus_md, ''), 240),
    (SELECT COUNT(*) FROM public.founder_sprint_retro_actions_r1806 a WHERE a.retro_id = r.id AND a.status = 'open')
  FROM public.founder_sprint_retros_r1806 r
  ORDER BY r.sprint_end DESC
  LIMIT 6;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_retros_r1806() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_retro_r1806(text, date, date, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1806(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1806(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_retro_r1806(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.average_sprint_score_r1806() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_themes_r1806() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_retros_r1806() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_retro_r1806(text, date, date, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1806(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1806(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_retro_r1806(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.average_sprint_score_r1806() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_themes_r1806() TO authenticated;

COMMIT;