BEGIN;

-- =====================================================================
-- Round 2190 — Founder 800-Heavy Milestone Memo
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_800_heavy_milestone_memo_r2190 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL,
  key_observations_md text,
  founder_pulse_md text,
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_800_heavy_reaction_log_r2190 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_800_heavy_milestone_memo_r2190(id) ON DELETE CASCADE,
  reactor_email text NOT NULL,
  reactor_role text NOT NULL CHECK (reactor_role IN ('team','investor','customer','external_observer','founder_self')),
  reaction_md text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_r2190_memo_status ON public.founder_800_heavy_milestone_memo_r2190(status, written_at DESC);
CREATE INDEX IF NOT EXISTS idx_r2190_reaction_memo ON public.founder_800_heavy_reaction_log_r2190(memo_id, recorded_at DESC);

ALTER TABLE public.founder_800_heavy_milestone_memo_r2190 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_800_heavy_reaction_log_r2190 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r2190_memo_founder_all ON public.founder_800_heavy_milestone_memo_r2190;
CREATE POLICY r2190_memo_founder_all ON public.founder_800_heavy_milestone_memo_r2190
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r2190_reaction_founder_all ON public.founder_800_heavy_reaction_log_r2190;
CREATE POLICY r2190_reaction_founder_all ON public.founder_800_heavy_reaction_log_r2190
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPCs
-- =====================================================================

DROP FUNCTION IF EXISTS public.r2190_list_memos(int);
CREATE FUNCTION public.r2190_list_memos(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  milestone_label text,
  written_at timestamptz,
  summary_md text,
  key_observations_md text,
  founder_pulse_md text,
  status text,
  reaction_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.milestone_label, m.written_at, m.summary_md, m.key_observations_md, m.founder_pulse_md, m.status,
    (SELECT count(*) FROM public.founder_800_heavy_reaction_log_r2190 r WHERE r.memo_id = m.id) AS reaction_count
  FROM public.founder_800_heavy_milestone_memo_r2190 m
  ORDER BY m.written_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2190_list_memos(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2190_list_memos(int) TO authenticated;

DROP FUNCTION IF EXISTS public.r2190_log_memo(text, text, text, text);
CREATE FUNCTION public.r2190_log_memo(
  p_milestone_label text,
  p_summary_md text,
  p_key_observations_md text,
  p_founder_pulse_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_800_heavy_milestone_memo_r2190 (milestone_label, summary_md, key_observations_md, founder_pulse_md)
  VALUES (p_milestone_label, p_summary_md, p_key_observations_md, p_founder_pulse_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2190_log_memo',
    jsonb_build_object('memo_id', v_id, 'label', p_milestone_label));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2190_log_memo(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2190_log_memo(text, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.r2190_list_reactions(uuid, int);
CREATE FUNCTION public.r2190_list_reactions(p_memo_id uuid, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  memo_id uuid,
  reactor_email text,
  reactor_role text,
  reaction_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.memo_id, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
  FROM public.founder_800_heavy_reaction_log_r2190 r
  WHERE r.memo_id = p_memo_id
  ORDER BY r.recorded_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2190_list_reactions(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2190_list_reactions(uuid, int) TO authenticated;

DROP FUNCTION IF EXISTS public.r2190_log_reaction(uuid, text, text, text);
CREATE FUNCTION public.r2190_log_reaction(
  p_memo_id uuid,
  p_reactor_email text,
  p_reactor_role text,
  p_reaction_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_800_heavy_reaction_log_r2190 (memo_id, reactor_email, reactor_role, reaction_md)
  VALUES (p_memo_id, p_reactor_email, p_reactor_role, p_reaction_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2190_log_reaction',
    jsonb_build_object('reaction_id', v_id, 'memo_id', p_memo_id, 'role', p_reactor_role));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2190_log_reaction(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2190_log_reaction(uuid, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.r2190_mark_status(uuid, text);
CREATE FUNCTION public.r2190_mark_status(p_memo_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('published','archived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.founder_800_heavy_milestone_memo_r2190
    SET status = p_status, updated_at = now()
    WHERE id = p_memo_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2190_mark_status',
    jsonb_build_object('memo_id', p_memo_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2190_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2190_mark_status(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.r2190_recent_reactions(int);
CREATE FUNCTION public.r2190_recent_reactions(p_limit int DEFAULT 25)
RETURNS TABLE (
  reaction_id uuid,
  memo_id uuid,
  milestone_label text,
  reactor_email text,
  reactor_role text,
  reaction_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.memo_id, m.milestone_label, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
  FROM public.founder_800_heavy_reaction_log_r2190 r
  JOIN public.founder_800_heavy_milestone_memo_r2190 m ON m.id = r.memo_id
  ORDER BY r.recorded_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2190_recent_reactions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2190_recent_reactions(int) TO authenticated;

DROP FUNCTION IF EXISTS public.r2190_top_reactions(int);
CREATE FUNCTION public.r2190_top_reactions(p_limit int DEFAULT 10)
RETURNS TABLE (
  reactor_role text,
  reaction_count bigint,
  last_recorded_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.reactor_role, count(*)::bigint AS reaction_count, max(r.recorded_at) AS last_recorded_at
  FROM public.founder_800_heavy_reaction_log_r2190 r
  GROUP BY r.reactor_role
  ORDER BY count(*) DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2190_top_reactions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2190_top_reactions(int) TO authenticated;

COMMIT;
