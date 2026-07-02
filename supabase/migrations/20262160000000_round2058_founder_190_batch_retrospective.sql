BEGIN;

-- ============================================================================
-- Round 2058: Founder 190-Batch Retrospective
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_190_batch_retrospective_r2058 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL DEFAULT '',
  what_kept_working_md text NOT NULL DEFAULT '',
  what_quit_md text NOT NULL DEFAULT '',
  founder_outlook_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_190_retrospective_reactions_r2058 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retrospective_id uuid NOT NULL REFERENCES public.founder_190_batch_retrospective_r2058(id) ON DELETE CASCADE,
  reactor_email text NOT NULL,
  reactor_role text NOT NULL CHECK (reactor_role IN ('team','investor','customer','external_observer')),
  reaction_md text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_r2058_retro_written ON public.founder_190_batch_retrospective_r2058(written_at DESC);
CREATE INDEX IF NOT EXISTS idx_r2058_retro_status ON public.founder_190_batch_retrospective_r2058(status);
CREATE INDEX IF NOT EXISTS idx_r2058_reactions_retro ON public.founder_190_retrospective_reactions_r2058(retrospective_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_r2058_reactions_role ON public.founder_190_retrospective_reactions_r2058(reactor_role);

ALTER TABLE public.founder_190_batch_retrospective_r2058 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_190_retrospective_reactions_r2058 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_retro_r2058_all ON public.founder_190_batch_retrospective_r2058;
CREATE POLICY founder_retro_r2058_all ON public.founder_190_batch_retrospective_r2058
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_reactions_r2058_all ON public.founder_190_retrospective_reactions_r2058;
CREATE POLICY founder_reactions_r2058_all ON public.founder_190_retrospective_reactions_r2058
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_retros
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_retros_r2058()
RETURNS TABLE (
  id uuid,
  milestone_label text,
  written_at timestamptz,
  summary_md text,
  what_kept_working_md text,
  what_quit_md text,
  founder_outlook_md text,
  status text,
  reaction_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.milestone_label, r.written_at, r.summary_md,
         r.what_kept_working_md, r.what_quit_md, r.founder_outlook_md, r.status,
         COALESCE((SELECT COUNT(*) FROM public.founder_190_retrospective_reactions_r2058 x WHERE x.retrospective_id = r.id), 0) AS reaction_count
  FROM public.founder_190_batch_retrospective_r2058 r
  ORDER BY r.written_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_retros_r2058() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_retros_r2058() TO authenticated;

-- ============================================================================
-- RPC 2: log_retro
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_retro_r2058(
  p_milestone_label text,
  p_summary_md text,
  p_kept_md text,
  p_quit_md text,
  p_outlook_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_190_batch_retrospective_r2058(milestone_label, summary_md, what_kept_working_md, what_quit_md, founder_outlook_md)
  VALUES (p_milestone_label, COALESCE(p_summary_md,''), COALESCE(p_kept_md,''), COALESCE(p_quit_md,''), COALESCE(p_outlook_md,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_retro_r2058', jsonb_build_object('id', v_id, 'milestone', p_milestone_label));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_retro_r2058(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_retro_r2058(text, text, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_reactions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_reactions_r2058(p_retro_id uuid)
RETURNS TABLE (
  id uuid,
  retrospective_id uuid,
  reactor_email text,
  reactor_role text,
  reaction_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.id, x.retrospective_id, x.reactor_email, x.reactor_role, x.reaction_md, x.recorded_at
  FROM public.founder_190_retrospective_reactions_r2058 x
  WHERE x.retrospective_id = p_retro_id
  ORDER BY x.recorded_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reactions_r2058(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reactions_r2058(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_reaction
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_reaction_r2058(
  p_retro_id uuid,
  p_reactor_email text,
  p_reactor_role text,
  p_reaction_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_190_retrospective_reactions_r2058(retrospective_id, reactor_email, reactor_role, reaction_md)
  VALUES (p_retro_id, p_reactor_email, p_reactor_role, COALESCE(p_reaction_md,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r2058', jsonb_build_object('id', v_id, 'retro_id', p_retro_id, 'role', p_reactor_role));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_reaction_r2058(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_reaction_r2058(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2058(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('published','archived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.founder_190_batch_retrospective_r2058 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2058', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2058(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2058(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: recent_reactions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_reactions_r2058()
RETURNS TABLE (
  id uuid,
  retrospective_id uuid,
  milestone_label text,
  reactor_email text,
  reactor_role text,
  reaction_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.id, x.retrospective_id, r.milestone_label, x.reactor_email, x.reactor_role, x.reaction_md, x.recorded_at
  FROM public.founder_190_retrospective_reactions_r2058 x
  JOIN public.founder_190_batch_retrospective_r2058 r ON r.id = x.retrospective_id
  ORDER BY x.recorded_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_reactions_r2058() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_reactions_r2058() TO authenticated;

-- ============================================================================
-- RPC 7: top_reactions (by role count per retro)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_reactions_r2058()
RETURNS TABLE (
  retrospective_id uuid,
  milestone_label text,
  reactor_role text,
  reaction_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.retrospective_id, r.milestone_label, x.reactor_role, COUNT(*)::bigint AS reaction_count
  FROM public.founder_190_retrospective_reactions_r2058 x
  JOIN public.founder_190_batch_retrospective_r2058 r ON r.id = x.retrospective_id
  GROUP BY x.retrospective_id, r.milestone_label, x.reactor_role
  ORDER BY reaction_count DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_reactions_r2058() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reactions_r2058() TO authenticated;

COMMIT;
