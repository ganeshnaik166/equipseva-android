BEGIN;

-- ===========================================================================
-- r1635 — Founder console: engineer learning paths
-- Predefined learning paths (imaging -> ultrasound -> MRI specialist)
-- Per-engineer progress · founder unlocks next path step
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_learning_paths (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            text NOT NULL UNIQUE,
  title           text NOT NULL,
  track           text NOT NULL CHECK (track IN ('imaging','biomedical','lab','dental','endoscopy','general')),
  step_order      int  NOT NULL,
  parent_slug     text REFERENCES public.engineer_learning_paths(slug),
  unlock_tier     text NOT NULL DEFAULT 'bronze' CHECK (unlock_tier IN ('bronze','silver','gold','platinum')),
  est_hours       int  NOT NULL DEFAULT 8,
  description     text,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS engineer_learning_paths_track_order_uk
  ON public.engineer_learning_paths(track, step_order);

ALTER TABLE public.engineer_learning_paths ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_learning_paths_founder_only ON public.engineer_learning_paths;
CREATE POLICY engineer_learning_paths_founder_only
  ON public.engineer_learning_paths
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_learning_progress (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL,
  path_slug       text NOT NULL REFERENCES public.engineer_learning_paths(slug),
  status          text NOT NULL DEFAULT 'locked' CHECK (status IN ('locked','unlocked','in_progress','completed')),
  unlocked_at     timestamptz,
  started_at      timestamptz,
  completed_at    timestamptz,
  unlocked_by     uuid,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, path_slug)
);

CREATE INDEX IF NOT EXISTS engineer_learning_progress_eng_idx
  ON public.engineer_learning_progress(engineer_user_id);
CREATE INDEX IF NOT EXISTS engineer_learning_progress_status_idx
  ON public.engineer_learning_progress(status);

ALTER TABLE public.engineer_learning_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_learning_progress_founder_only ON public.engineer_learning_progress;
CREATE POLICY engineer_learning_progress_founder_only
  ON public.engineer_learning_progress
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed predefined imaging ladder (idempotent)
INSERT INTO public.engineer_learning_paths (slug, title, track, step_order, parent_slug, unlock_tier, est_hours, description)
VALUES
  ('imaging_foundations', 'Imaging Foundations',          'imaging', 1, NULL,                       'bronze',   12, 'X-ray + portable imaging fundamentals'),
  ('ultrasound_specialist','Ultrasound Specialist',       'imaging', 2, 'imaging_foundations',      'silver',   24, 'Ultrasound probe service + calibration'),
  ('mri_specialist',      'MRI Specialist',               'imaging', 3, 'ultrasound_specialist',    'gold',     40, 'MRI cryo + RF + gradient coil service'),
  ('ct_specialist',       'CT Specialist',                'imaging', 4, 'mri_specialist',           'platinum', 40, 'CT tube + DAS + gantry service')
ON CONFLICT (slug) DO NOTHING;

-- ===========================================================================
-- RPC: list paths with engineer count + completion stats (READ)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.founder_learning_paths_overview()
RETURNS TABLE (
  slug          text,
  title         text,
  track         text,
  step_order    int,
  parent_slug   text,
  unlock_tier   text,
  est_hours     int,
  enrolled      bigint,
  in_progress   bigint,
  completed     bigint,
  avg_days_to_complete numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.slug, p.title, p.track, p.step_order, p.parent_slug, p.unlock_tier, p.est_hours,
         COUNT(pr.id) FILTER (WHERE pr.status <> 'locked')           AS enrolled,
         COUNT(pr.id) FILTER (WHERE pr.status = 'in_progress')       AS in_progress,
         COUNT(pr.id) FILTER (WHERE pr.status = 'completed')         AS completed,
         AVG(EXTRACT(EPOCH FROM (pr.completed_at - pr.unlocked_at))/86400.0)
           FILTER (WHERE pr.completed_at IS NOT NULL AND pr.unlocked_at IS NOT NULL) AS avg_days_to_complete
    FROM public.engineer_learning_paths p
    LEFT JOIN public.engineer_learning_progress pr ON pr.path_slug = p.slug
   WHERE p.is_active
   GROUP BY p.slug, p.title, p.track, p.step_order, p.parent_slug, p.unlock_tier, p.est_hours
   ORDER BY p.track, p.step_order;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_learning_paths_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_learning_paths_overview() TO authenticated;

-- ===========================================================================
-- RPC: per-engineer progress board
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.founder_engineer_learning_board(p_limit int DEFAULT 50)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email   text,
  cached_tier      text,
  paths_unlocked   bigint,
  paths_completed  bigint,
  current_path     text,
  current_status   text,
  last_activity    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT pr.engineer_user_id,
           COUNT(*) FILTER (WHERE pr.status IN ('unlocked','in_progress','completed')) AS paths_unlocked,
           COUNT(*) FILTER (WHERE pr.status = 'completed')                              AS paths_completed,
           MAX(pr.updated_at)                                                           AS last_activity
      FROM public.engineer_learning_progress pr
     GROUP BY pr.engineer_user_id
  ),
  cur AS (
    SELECT DISTINCT ON (pr.engineer_user_id)
           pr.engineer_user_id, pr.path_slug, pr.status
      FROM public.engineer_learning_progress pr
     WHERE pr.status IN ('in_progress','unlocked')
     ORDER BY pr.engineer_user_id, pr.updated_at DESC
  )
  SELECT a.engineer_user_id,
         pf.email,
         e.cached_highest_tier,
         COALESCE(a.paths_unlocked,0),
         COALESCE(a.paths_completed,0),
         cur.path_slug,
         cur.status,
         a.last_activity
    FROM agg a
    LEFT JOIN public.engineers e ON e.user_id = a.engineer_user_id
    LEFT JOIN public.profiles  pf ON pf.id = a.engineer_user_id
    LEFT JOIN cur ON cur.engineer_user_id = a.engineer_user_id
   ORDER BY a.last_activity DESC NULLS LAST
   LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_learning_board(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_learning_board(int) TO authenticated;

-- ===========================================================================
-- RPC: founder UNLOCK next path step for an engineer (WRITE)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.founder_unlock_learning_path(
  p_engineer_user_id uuid,
  p_path_slug text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.engineer_learning_paths WHERE slug = p_path_slug AND is_active) THEN
    RAISE EXCEPTION 'invalid_path';
  END IF;

  INSERT INTO public.engineer_learning_progress (engineer_user_id, path_slug, status, unlocked_at, unlocked_by)
  VALUES (p_engineer_user_id, p_path_slug, 'unlocked', now(), auth.uid())
  ON CONFLICT (engineer_user_id, path_slug)
  DO UPDATE SET status = CASE WHEN public.engineer_learning_progress.status = 'locked' THEN 'unlocked' ELSE public.engineer_learning_progress.status END,
                unlocked_at = COALESCE(public.engineer_learning_progress.unlocked_at, now()),
                unlocked_by = COALESCE(public.engineer_learning_progress.unlocked_by, auth.uid()),
                updated_at  = now()
  RETURNING id INTO v_id;

  PERFORM public.log_founder_unlock_learning_path(p_engineer_user_id, p_path_slug);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_unlock_learning_path(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_unlock_learning_path(uuid, text) TO authenticated;

-- ===========================================================================
-- RPC: founder MARK progress (in_progress / completed) (WRITE)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.founder_mark_learning_progress(
  p_engineer_user_id uuid,
  p_path_slug text,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('in_progress','completed') THEN RAISE EXCEPTION 'invalid_status'; END IF;

  UPDATE public.engineer_learning_progress
     SET status       = p_status,
         started_at   = CASE WHEN p_status = 'in_progress' AND started_at IS NULL THEN now() ELSE started_at END,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at   = now()
   WHERE engineer_user_id = p_engineer_user_id
     AND path_slug = p_path_slug;

  PERFORM public.log_founder_mark_learning_progress(p_engineer_user_id, p_path_slug, p_status);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_mark_learning_progress(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_mark_learning_progress(uuid, text, text) TO authenticated;

-- ===========================================================================
-- RPC: track funnel (track-level completion ladder)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.founder_learning_track_funnel()
RETURNS TABLE (
  track        text,
  step_order   int,
  title        text,
  completed    bigint,
  in_progress  bigint,
  drop_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH counts AS (
    SELECT p.track, p.step_order, p.title,
           COUNT(pr.id) FILTER (WHERE pr.status = 'completed')   AS completed,
           COUNT(pr.id) FILTER (WHERE pr.status = 'in_progress') AS in_progress
      FROM public.engineer_learning_paths p
      LEFT JOIN public.engineer_learning_progress pr ON pr.path_slug = p.slug
     WHERE p.is_active
     GROUP BY p.track, p.step_order, p.title
  ),
  with_prev AS (
    SELECT c.*, LAG(c.completed) OVER (PARTITION BY c.track ORDER BY c.step_order) AS prev_completed
      FROM counts c
  )
  SELECT w.track, w.step_order, w.title, w.completed, w.in_progress,
         CASE WHEN w.prev_completed IS NULL OR w.prev_completed = 0 THEN 0
              ELSE ROUND((1.0 - (w.completed::numeric / w.prev_completed::numeric)) * 100, 1)
         END AS drop_pct
    FROM with_prev w
   ORDER BY w.track, w.step_order;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_learning_track_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_learning_track_funnel() TO authenticated;

-- ===========================================================================
-- RPC: recent unlock activity log
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.founder_learning_recent_unlocks(p_limit int DEFAULT 25)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email   text,
  path_slug        text,
  path_title       text,
  status           text,
  unlocked_at      timestamptz,
  updated_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT pr.engineer_user_id, pf.email, pr.path_slug, p.title, pr.status, pr.unlocked_at, pr.updated_at
    FROM public.engineer_learning_progress pr
    JOIN public.engineer_learning_paths p ON p.slug = pr.path_slug
    LEFT JOIN public.profiles pf ON pf.id = pr.engineer_user_id
   ORDER BY pr.updated_at DESC NULLS LAST
   LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_learning_recent_unlocks(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_learning_recent_unlocks(int) TO authenticated;

-- ===========================================================================
-- RPC: tier vs completion correlation
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.founder_learning_tier_correlation()
RETURNS TABLE (
  cached_tier      text,
  engineers        bigint,
  paths_completed  bigint,
  avg_completed    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(e.cached_highest_tier, 'unranked'),
         COUNT(DISTINCT e.user_id),
         COUNT(pr.id) FILTER (WHERE pr.status = 'completed'),
         CASE WHEN COUNT(DISTINCT e.user_id) = 0 THEN 0
              ELSE ROUND(COUNT(pr.id) FILTER (WHERE pr.status = 'completed')::numeric / COUNT(DISTINCT e.user_id)::numeric, 2)
         END
    FROM public.engineers e
    LEFT JOIN public.engineer_learning_progress pr ON pr.engineer_user_id = e.user_id
   GROUP BY COALESCE(e.cached_highest_tier, 'unranked')
   ORDER BY 1;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_learning_tier_correlation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_learning_tier_correlation() TO authenticated;

-- ===========================================================================
-- log helpers
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.log_founder_unlock_learning_path(p_engineer_user_id uuid, p_path_slug text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_unlock_learning_path',
          jsonb_build_object('engineer_user_id', p_engineer_user_id, 'path_slug', p_path_slug), now());
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_unlock_learning_path(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_unlock_learning_path(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_mark_learning_progress(p_engineer_user_id uuid, p_path_slug text, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_mark_learning_progress',
          jsonb_build_object('engineer_user_id', p_engineer_user_id, 'path_slug', p_path_slug, 'status', p_status), now());
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_mark_learning_progress(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_mark_learning_progress(uuid, text, text) TO authenticated;

COMMIT;