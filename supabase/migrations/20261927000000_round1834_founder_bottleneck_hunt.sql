BEGIN;

-- =========================================================================
-- Round 1834 — Founder Bottleneck Hunt
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_bottleneck_hunt_r1834 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hunt_week date NOT NULL UNIQUE,
  identified_bottleneck_md text NOT NULL,
  bottleneck_owner_email text,
  impact_pct numeric,
  removed_by date,
  status text NOT NULL DEFAULT 'identified' CHECK (status IN ('identified','in_progress','removed','superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_bottleneck_actions_r1834 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hunt_id uuid NOT NULL REFERENCES public.founder_bottleneck_hunt_r1834(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bn_hunt_r1834_status_week ON public.founder_bottleneck_hunt_r1834(status, hunt_week DESC);
CREATE INDEX IF NOT EXISTS idx_bn_actions_r1834_hunt ON public.founder_bottleneck_actions_r1834(hunt_id, status);

ALTER TABLE public.founder_bottleneck_hunt_r1834 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_bottleneck_actions_r1834 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_bn_hunt_r1834 ON public.founder_bottleneck_hunt_r1834;
CREATE POLICY founder_all_bn_hunt_r1834 ON public.founder_bottleneck_hunt_r1834
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_bn_actions_r1834 ON public.founder_bottleneck_actions_r1834;
CREATE POLICY founder_all_bn_actions_r1834 ON public.founder_bottleneck_actions_r1834
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_hunts
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_bottleneck_hunts_r1834(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  hunt_week date,
  identified_bottleneck_md text,
  bottleneck_owner_email text,
  impact_pct numeric,
  removed_by date,
  status text,
  open_actions int,
  done_actions int,
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
    h.id,
    h.hunt_week,
    h.identified_bottleneck_md,
    h.bottleneck_owner_email,
    h.impact_pct,
    h.removed_by,
    h.status,
    (SELECT COUNT(*) FILTER (WHERE a.status = 'open') FROM public.founder_bottleneck_actions_r1834 a WHERE a.hunt_id = h.id)::int,
    (SELECT COUNT(*) FILTER (WHERE a.status = 'done') FROM public.founder_bottleneck_actions_r1834 a WHERE a.hunt_id = h.id)::int,
    h.created_at
  FROM public.founder_bottleneck_hunt_r1834 h
  ORDER BY h.hunt_week DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- =========================================================================
-- RPC 2: log_hunt
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_bottleneck_hunt_r1834(
  p_hunt_week date,
  p_bottleneck_md text,
  p_owner_email text,
  p_impact_pct numeric
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

  INSERT INTO public.founder_bottleneck_hunt_r1834(
    hunt_week, identified_bottleneck_md, bottleneck_owner_email, impact_pct, status
  ) VALUES (
    p_hunt_week, p_bottleneck_md, p_owner_email, p_impact_pct, 'identified'
  )
  ON CONFLICT (hunt_week) DO UPDATE
    SET identified_bottleneck_md = EXCLUDED.identified_bottleneck_md,
        bottleneck_owner_email = EXCLUDED.bottleneck_owner_email,
        impact_pct = EXCLUDED.impact_pct,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_bottleneck_hunt_r1834',
    jsonb_build_object('id', v_id, 'hunt_week', p_hunt_week, 'owner', p_owner_email)
  );

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC 3: list_actions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_bottleneck_actions_r1834(p_hunt_id uuid DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  hunt_id uuid,
  hunt_week date,
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
    a.id,
    a.hunt_id,
    h.hunt_week,
    a.action_text,
    a.owner_email,
    a.due_date,
    a.status,
    a.completed_at,
    a.created_at
  FROM public.founder_bottleneck_actions_r1834 a
  JOIN public.founder_bottleneck_hunt_r1834 h ON h.id = a.hunt_id
  WHERE (p_hunt_id IS NULL OR a.hunt_id = p_hunt_id)
  ORDER BY a.status ASC, a.due_date ASC NULLS LAST, a.created_at DESC;
END;
$$;

-- =========================================================================
-- RPC 4: log_action
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_bottleneck_action_r1834(
  p_hunt_id uuid,
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

  INSERT INTO public.founder_bottleneck_actions_r1834(
    hunt_id, action_text, owner_email, due_date, status
  ) VALUES (
    p_hunt_id, p_action_text, p_owner_email, p_due_date, 'open'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_bottleneck_action_r1834',
    jsonb_build_object('id', v_id, 'hunt_id', p_hunt_id, 'owner', p_owner_email)
  );

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC 5: close_hunt
-- =========================================================================
CREATE OR REPLACE FUNCTION public.close_bottleneck_hunt_r1834(
  p_hunt_id uuid,
  p_status text,
  p_removed_by date
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

  IF p_status NOT IN ('identified','in_progress','removed','superseded') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  UPDATE public.founder_bottleneck_hunt_r1834
     SET status = p_status,
         removed_by = COALESCE(p_removed_by, removed_by),
         updated_at = now()
   WHERE id = p_hunt_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'close_bottleneck_hunt_r1834',
    jsonb_build_object('id', p_hunt_id, 'status', p_status)
  );
END;
$$;

-- =========================================================================
-- RPC 6: current_bottleneck
-- =========================================================================
CREATE OR REPLACE FUNCTION public.current_bottleneck_r1834()
RETURNS TABLE(
  id uuid,
  hunt_week date,
  identified_bottleneck_md text,
  bottleneck_owner_email text,
  impact_pct numeric,
  status text,
  open_actions int,
  total_actions int
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
    h.id,
    h.hunt_week,
    h.identified_bottleneck_md,
    h.bottleneck_owner_email,
    h.impact_pct,
    h.status,
    (SELECT COUNT(*) FILTER (WHERE a.status = 'open') FROM public.founder_bottleneck_actions_r1834 a WHERE a.hunt_id = h.id)::int,
    (SELECT COUNT(*) FROM public.founder_bottleneck_actions_r1834 a WHERE a.hunt_id = h.id)::int
  FROM public.founder_bottleneck_hunt_r1834 h
  WHERE h.status IN ('identified','in_progress')
  ORDER BY h.hunt_week DESC
  LIMIT 1;
END;
$$;

-- =========================================================================
-- RPC 7: weekly_bottleneck_history
-- =========================================================================
CREATE OR REPLACE FUNCTION public.weekly_bottleneck_history_r1834(p_weeks int DEFAULT 12)
RETURNS TABLE(
  hunt_week date,
  status text,
  impact_pct numeric,
  bottleneck_owner_email text,
  open_actions int,
  done_actions int,
  days_to_remove int
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
    h.hunt_week,
    h.status,
    h.impact_pct,
    h.bottleneck_owner_email,
    (SELECT COUNT(*) FILTER (WHERE a.status = 'open') FROM public.founder_bottleneck_actions_r1834 a WHERE a.hunt_id = h.id)::int,
    (SELECT COUNT(*) FILTER (WHERE a.status = 'done') FROM public.founder_bottleneck_actions_r1834 a WHERE a.hunt_id = h.id)::int,
    CASE WHEN h.removed_by IS NOT NULL THEN (h.removed_by - h.hunt_week)::int ELSE NULL END
  FROM public.founder_bottleneck_hunt_r1834 h
  ORDER BY h.hunt_week DESC
  LIMIT GREATEST(p_weeks, 1);
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.list_bottleneck_hunts_r1834(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bottleneck_hunts_r1834(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_bottleneck_hunt_r1834(date, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_bottleneck_hunt_r1834(date, text, text, numeric) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_bottleneck_actions_r1834(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bottleneck_actions_r1834(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_bottleneck_action_r1834(uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_bottleneck_action_r1834(uuid, text, text, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.close_bottleneck_hunt_r1834(uuid, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_bottleneck_hunt_r1834(uuid, text, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.current_bottleneck_r1834() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_bottleneck_r1834() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.weekly_bottleneck_history_r1834(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_bottleneck_history_r1834(int) TO authenticated;

COMMIT;