BEGIN;

-- =====================================================================
-- Round 1782 — Founder Whiteboard Snapshots
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_whiteboard_snapshots_r1782 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  taken_at timestamptz NOT NULL DEFAULT now(),
  session_topic text NOT NULL,
  image_url text,
  transcription_md text,
  key_insights_md text,
  follow_up_required boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'captured'
    CHECK (status IN ('captured','transcribed','actioned','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_whiteboard_action_items_r1782 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id uuid NOT NULL REFERENCES public.founder_whiteboard_snapshots_r1782(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','done','dropped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wb_snapshots_r1782_taken_at
  ON public.founder_whiteboard_snapshots_r1782(taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_wb_snapshots_r1782_status
  ON public.founder_whiteboard_snapshots_r1782(status);
CREATE INDEX IF NOT EXISTS idx_wb_actions_r1782_snapshot
  ON public.founder_whiteboard_action_items_r1782(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_wb_actions_r1782_status
  ON public.founder_whiteboard_action_items_r1782(status);

ALTER TABLE public.founder_whiteboard_snapshots_r1782 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_whiteboard_action_items_r1782 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_wb_snap_r1782 ON public.founder_whiteboard_snapshots_r1782;
CREATE POLICY founder_all_wb_snap_r1782 ON public.founder_whiteboard_snapshots_r1782
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_wb_action_r1782 ON public.founder_whiteboard_action_items_r1782;
CREATE POLICY founder_all_wb_action_r1782 ON public.founder_whiteboard_action_items_r1782
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_snapshots
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_snapshots_r1782()
RETURNS TABLE (
  id uuid,
  taken_at timestamptz,
  session_topic text,
  image_url text,
  status text,
  follow_up_required boolean,
  action_count int,
  open_action_count int
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
    s.id,
    s.taken_at,
    s.session_topic,
    s.image_url,
    s.status,
    s.follow_up_required,
    (SELECT COUNT(*) FROM public.founder_whiteboard_action_items_r1782 a WHERE a.snapshot_id = s.id)::int,
    (SELECT COUNT(*) FROM public.founder_whiteboard_action_items_r1782 a WHERE a.snapshot_id = s.id AND a.status = 'open')::int
  FROM public.founder_whiteboard_snapshots_r1782 s
  ORDER BY s.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_snapshots_r1782() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_snapshots_r1782() TO authenticated;

-- =====================================================================
-- RPC 2: capture_snapshot
-- =====================================================================
CREATE OR REPLACE FUNCTION public.capture_snapshot_r1782(
  p_session_topic text,
  p_image_url text,
  p_transcription_md text DEFAULT NULL,
  p_key_insights_md text DEFAULT NULL,
  p_follow_up_required boolean DEFAULT false
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

  INSERT INTO public.founder_whiteboard_snapshots_r1782
    (session_topic, image_url, transcription_md, key_insights_md, follow_up_required, status)
  VALUES
    (p_session_topic, p_image_url, p_transcription_md, p_key_insights_md, p_follow_up_required,
     CASE WHEN p_transcription_md IS NOT NULL THEN 'transcribed' ELSE 'captured' END)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'capture_snapshot_r1782',
          jsonb_build_object('id', v_id, 'topic', p_session_topic));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.capture_snapshot_r1782(text, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.capture_snapshot_r1782(text, text, text, text, boolean) TO authenticated;

-- =====================================================================
-- RPC 3: list_actions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1782(p_snapshot_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  snapshot_id uuid,
  session_topic text,
  action_text text,
  owner_email text,
  due_date date,
  status text,
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
    a.id,
    a.snapshot_id,
    s.session_topic,
    a.action_text,
    a.owner_email,
    a.due_date,
    a.status,
    a.created_at
  FROM public.founder_whiteboard_action_items_r1782 a
  JOIN public.founder_whiteboard_snapshots_r1782 s ON s.id = a.snapshot_id
  WHERE (p_snapshot_id IS NULL OR a.snapshot_id = p_snapshot_id)
  ORDER BY
    CASE a.status WHEN 'open' THEN 0 WHEN 'done' THEN 1 ELSE 2 END,
    a.due_date NULLS LAST,
    a.created_at DESC
  LIMIT 300;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r1782(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r1782(uuid) TO authenticated;

-- =====================================================================
-- RPC 4: log_action
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1782(
  p_snapshot_id uuid,
  p_action_text text,
  p_owner_email text DEFAULT NULL,
  p_due_date date DEFAULT NULL
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

  INSERT INTO public.founder_whiteboard_action_items_r1782
    (snapshot_id, action_text, owner_email, due_date, status)
  VALUES (p_snapshot_id, p_action_text, p_owner_email, p_due_date, 'open')
  RETURNING id INTO v_id;

  UPDATE public.founder_whiteboard_snapshots_r1782
     SET follow_up_required = true,
         updated_at = now()
   WHERE id = p_snapshot_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1782',
          jsonb_build_object('id', v_id, 'snapshot_id', p_snapshot_id, 'action', p_action_text));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r1782(uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r1782(uuid, text, text, date) TO authenticated;

-- =====================================================================
-- RPC 5: complete_action
-- =====================================================================
CREATE OR REPLACE FUNCTION public.complete_action_r1782(
  p_action_id uuid,
  p_status text DEFAULT 'done'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_snap uuid;
  v_open int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('open','done','dropped') THEN
    RAISE EXCEPTION 'bad_status';
  END IF;

  UPDATE public.founder_whiteboard_action_items_r1782
     SET status = p_status,
         updated_at = now()
   WHERE id = p_action_id
   RETURNING snapshot_id INTO v_snap;

  IF v_snap IS NULL THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  SELECT COUNT(*) INTO v_open
    FROM public.founder_whiteboard_action_items_r1782
   WHERE snapshot_id = v_snap AND status = 'open';

  IF v_open = 0 THEN
    UPDATE public.founder_whiteboard_snapshots_r1782
       SET status = 'actioned',
           follow_up_required = false,
           updated_at = now()
     WHERE id = v_snap AND status <> 'archived';
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_action_r1782',
          jsonb_build_object('id', p_action_id, 'status', p_status));

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.complete_action_r1782(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_action_r1782(uuid, text) TO authenticated;

-- =====================================================================
-- RPC 6: recent_topics
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_topics_r1782()
RETURNS TABLE (
  session_topic text,
  snapshot_count int,
  last_taken_at timestamptz,
  open_actions int
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
    s.session_topic,
    COUNT(*)::int,
    MAX(s.taken_at),
    (SELECT COUNT(*) FROM public.founder_whiteboard_action_items_r1782 a
       JOIN public.founder_whiteboard_snapshots_r1782 s2 ON s2.id = a.snapshot_id
      WHERE s2.session_topic = s.session_topic AND a.status = 'open')::int
  FROM public.founder_whiteboard_snapshots_r1782 s
  WHERE s.taken_at > now() - interval '60 days'
  GROUP BY s.session_topic
  ORDER BY MAX(s.taken_at) DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_topics_r1782() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_topics_r1782() TO authenticated;

-- =====================================================================
-- RPC 7: actionable_snapshots
-- =====================================================================
CREATE OR REPLACE FUNCTION public.actionable_snapshots_r1782()
RETURNS TABLE (
  id uuid,
  taken_at timestamptz,
  session_topic text,
  status text,
  open_actions int,
  overdue_actions int
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
    s.id,
    s.taken_at,
    s.session_topic,
    s.status,
    (SELECT COUNT(*) FROM public.founder_whiteboard_action_items_r1782 a
      WHERE a.snapshot_id = s.id AND a.status = 'open')::int,
    (SELECT COUNT(*) FROM public.founder_whiteboard_action_items_r1782 a
      WHERE a.snapshot_id = s.id AND a.status = 'open'
        AND a.due_date IS NOT NULL AND a.due_date < CURRENT_DATE)::int
  FROM public.founder_whiteboard_snapshots_r1782 s
  WHERE s.follow_up_required = true
    AND s.status <> 'archived'
  ORDER BY s.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.actionable_snapshots_r1782() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.actionable_snapshots_r1782() TO authenticated;

COMMIT;