BEGIN;

-- ============================================================
-- Round 1866 — Founder Internal Vlog
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_internal_vlogs_r1866 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  written_md text NOT NULL DEFAULT '',
  video_url text,
  audience text NOT NULL DEFAULT 'team_all' CHECK (audience IN ('team_all','cofounders','senior_only')),
  published_at timestamptz,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  view_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_internal_vlog_reactions_r1866 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vlog_id uuid NOT NULL REFERENCES public.founder_internal_vlogs_r1866(id) ON DELETE CASCADE,
  reactor_email text NOT NULL,
  reaction text NOT NULL CHECK (reaction IN ('appreciate','question','clarify','concern')),
  reaction_md text NOT NULL DEFAULT '',
  reacted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vlogs_r1866_status ON public.founder_internal_vlogs_r1866(status);
CREATE INDEX IF NOT EXISTS idx_vlogs_r1866_week ON public.founder_internal_vlogs_r1866(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_vlog_reactions_r1866_vlog ON public.founder_internal_vlog_reactions_r1866(vlog_id);
CREATE INDEX IF NOT EXISTS idx_vlog_reactions_r1866_reactor ON public.founder_internal_vlog_reactions_r1866(reactor_email);

ALTER TABLE public.founder_internal_vlogs_r1866 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_internal_vlog_reactions_r1866 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_vlogs_r1866 ON public.founder_internal_vlogs_r1866;
CREATE POLICY founder_all_vlogs_r1866 ON public.founder_internal_vlogs_r1866
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_vlog_reactions_r1866 ON public.founder_internal_vlog_reactions_r1866;
CREATE POLICY founder_all_vlog_reactions_r1866 ON public.founder_internal_vlog_reactions_r1866
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_vlogs_r1866()
RETURNS TABLE (
  id uuid,
  week_start date,
  audience text,
  status text,
  published_at timestamptz,
  view_count int,
  reaction_count bigint,
  has_video boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.id,
    v.week_start,
    v.audience,
    v.status,
    v.published_at,
    v.view_count,
    (SELECT COUNT(*) FROM public.founder_internal_vlog_reactions_r1866 r WHERE r.vlog_id = v.id),
    (v.video_url IS NOT NULL AND length(v.video_url) > 0)
  FROM public.founder_internal_vlogs_r1866 v
  ORDER BY v.week_start DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.draft_vlog_r1866(
  p_week_start date,
  p_written_md text,
  p_video_url text,
  p_audience text
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

  INSERT INTO public.founder_internal_vlogs_r1866 (week_start, written_md, video_url, audience, status)
  VALUES (p_week_start, COALESCE(p_written_md,''), p_video_url, COALESCE(p_audience,'team_all'), 'draft')
  ON CONFLICT (week_start) DO UPDATE
    SET written_md = EXCLUDED.written_md,
        video_url = EXCLUDED.video_url,
        audience = EXCLUDED.audience,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'draft_vlog_r1866',
          jsonb_build_object('vlog_id', v_id, 'week_start', p_week_start, 'audience', p_audience));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_vlog_r1866(p_vlog_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_internal_vlogs_r1866
  SET status = 'published',
      published_at = COALESCE(published_at, now()),
      updated_at = now()
  WHERE id = p_vlog_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'publish_vlog_r1866',
          jsonb_build_object('vlog_id', p_vlog_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.list_reactions_r1866(p_vlog_id uuid)
RETURNS TABLE (
  id uuid,
  vlog_id uuid,
  reactor_email text,
  reaction text,
  reaction_md text,
  reacted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.vlog_id, r.reactor_email, r.reaction, r.reaction_md, r.reacted_at
  FROM public.founder_internal_vlog_reactions_r1866 r
  WHERE (p_vlog_id IS NULL OR r.vlog_id = p_vlog_id)
  ORDER BY r.reacted_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reaction_r1866(
  p_vlog_id uuid,
  p_reactor_email text,
  p_reaction text,
  p_reaction_md text
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

  INSERT INTO public.founder_internal_vlog_reactions_r1866 (vlog_id, reactor_email, reaction, reaction_md)
  VALUES (p_vlog_id, p_reactor_email, p_reaction, COALESCE(p_reaction_md,''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r1866',
          jsonb_build_object('vlog_id', p_vlog_id, 'reactor_email', p_reactor_email, 'reaction', p_reaction));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.weekly_summary_r1866()
RETURNS TABLE (
  week_start date,
  total_vlogs bigint,
  published_count bigint,
  draft_count bigint,
  total_reactions bigint,
  total_views bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.week_start,
    (COUNT(*))::bigint,
    (COUNT(*) FILTER (WHERE v.status = 'published'))::bigint,
    (COUNT(*) FILTER (WHERE v.status = 'draft'))::bigint,
    COALESCE((SELECT COUNT(*) FROM public.founder_internal_vlog_reactions_r1866 r WHERE r.vlog_id = v.id), 0)::bigint,
    COALESCE(SUM(v.view_count), 0)::bigint
  FROM public.founder_internal_vlogs_r1866 v
  GROUP BY v.week_start, v.id
  ORDER BY v.week_start DESC
  LIMIT 26;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_engaged_reactors_r1866()
RETURNS TABLE (
  reactor_email text,
  reaction_count bigint,
  appreciate_count bigint,
  question_count bigint,
  clarify_count bigint,
  concern_count bigint,
  last_reacted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.reactor_email,
    (COUNT(*))::bigint,
    (COUNT(*) FILTER (WHERE r.reaction = 'appreciate'))::bigint,
    (COUNT(*) FILTER (WHERE r.reaction = 'question'))::bigint,
    (COUNT(*) FILTER (WHERE r.reaction = 'clarify'))::bigint,
    (COUNT(*) FILTER (WHERE r.reaction = 'concern'))::bigint,
    MAX(r.reacted_at)
  FROM public.founder_internal_vlog_reactions_r1866 r
  GROUP BY r.reactor_email
  ORDER BY COUNT(*) DESC
  LIMIT 25;
END;
$$;

-- ============================================================
-- Permissions
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.list_vlogs_r1866() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_vlog_r1866(date, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_vlog_r1866(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reactions_r1866(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reaction_r1866(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.weekly_summary_r1866() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_engaged_reactors_r1866() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_vlogs_r1866() TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_vlog_r1866(date, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_vlog_r1866(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reactions_r1866(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reaction_r1866(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.weekly_summary_r1866() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engaged_reactors_r1866() TO authenticated;

COMMIT;