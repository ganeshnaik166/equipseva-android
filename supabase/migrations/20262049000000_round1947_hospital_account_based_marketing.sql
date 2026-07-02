BEGIN;

-- ============================================================================
-- Round 1947 — Hospital Account-Based Marketing
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_abm_targets_r1947 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_segment text NOT NULL CHECK (target_segment IN ('tier_a_hospital','chain','super_specialty','government','research')),
  abm_priority text NOT NULL CHECK (abm_priority IN ('critical','high','medium','low')),
  status text NOT NULL DEFAULT 'researching' CHECK (status IN ('researching','engaging','closing','won','lost','pause')),
  last_touched_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_abm_targets_r1947_hospital ON public.hospital_abm_targets_r1947(hospital_id);
CREATE INDEX IF NOT EXISTS idx_abm_targets_r1947_status ON public.hospital_abm_targets_r1947(status);
CREATE INDEX IF NOT EXISTS idx_abm_targets_r1947_priority ON public.hospital_abm_targets_r1947(abm_priority);

CREATE TABLE IF NOT EXISTS public.hospital_abm_touch_log_r1947 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES public.hospital_abm_targets_r1947(id) ON DELETE CASCADE,
  touch_type text NOT NULL CHECK (touch_type IN ('email','linkedin','call','event','intro','whitepaper','dinner','founder_visit')),
  touched_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_abm_touch_r1947_target ON public.hospital_abm_touch_log_r1947(target_id);
CREATE INDEX IF NOT EXISTS idx_abm_touch_r1947_touched ON public.hospital_abm_touch_log_r1947(touched_at DESC);

ALTER TABLE public.hospital_abm_targets_r1947 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_abm_touch_log_r1947 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_abm_targets_r1947_founder ON public.hospital_abm_targets_r1947;
CREATE POLICY p_abm_targets_r1947_founder ON public.hospital_abm_targets_r1947
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_abm_touch_r1947_founder ON public.hospital_abm_touch_log_r1947;
CREATE POLICY p_abm_touch_r1947_founder ON public.hospital_abm_touch_log_r1947
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_targets
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_abm_targets_r1947();
CREATE OR REPLACE FUNCTION public.list_abm_targets_r1947()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  hospital_city text,
  target_segment text,
  abm_priority text,
  status text,
  last_touched_at timestamptz,
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
  SELECT t.id,
         t.hospital_id,
         COALESCE(o.name, p.full_name, p.email, 'unknown') AS hospital_name,
         o.city,
         t.target_segment,
         t.abm_priority,
         t.status,
         t.last_touched_at,
         t.created_at
  FROM public.hospital_abm_targets_r1947 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY
    CASE t.abm_priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    t.last_touched_at DESC NULLS LAST,
    t.created_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================================
-- RPC 2: log_target (upsert/create)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_abm_target_r1947(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_abm_target_r1947(
  p_hospital_id uuid,
  p_segment text,
  p_priority text,
  p_status text
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

  INSERT INTO public.hospital_abm_targets_r1947 (hospital_id, target_segment, abm_priority, status)
  VALUES (p_hospital_id, p_segment, p_priority, COALESCE(p_status, 'researching'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1947.log_target',
    jsonb_build_object('target_id', v_id, 'hospital_id', p_hospital_id, 'segment', p_segment, 'priority', p_priority, 'status', p_status)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_touches
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_abm_touches_r1947(uuid);
CREATE OR REPLACE FUNCTION public.list_abm_touches_r1947(p_target_id uuid)
RETURNS TABLE (
  id uuid,
  target_id uuid,
  touch_type text,
  touched_at timestamptz,
  by_email text,
  outcome_md text
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
  SELECT l.id, l.target_id, l.touch_type, l.touched_at, l.by_email, l.outcome_md
  FROM public.hospital_abm_touch_log_r1947 l
  WHERE l.target_id = p_target_id
  ORDER BY l.touched_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_touch
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_abm_touch_r1947(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_abm_touch_r1947(
  p_target_id uuid,
  p_touch_type text,
  p_by_email text,
  p_outcome_md text
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

  INSERT INTO public.hospital_abm_touch_log_r1947 (target_id, touch_type, by_email, outcome_md)
  VALUES (p_target_id, p_touch_type, p_by_email, p_outcome_md)
  RETURNING id INTO v_id;

  UPDATE public.hospital_abm_targets_r1947
  SET last_touched_at = now(), updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1947.log_touch',
    jsonb_build_object('touch_id', v_id, 'target_id', p_target_id, 'touch_type', p_touch_type)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_abm_status_r1947(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_abm_status_r1947(p_target_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.hospital_abm_targets_r1947
  SET status = p_status, updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1947.mark_status',
    jsonb_build_object('target_id', p_target_id, 'status', p_status)
  );
END;
$$;

-- ============================================================================
-- RPC 6: critical_targets
-- ============================================================================
DROP FUNCTION IF EXISTS public.critical_abm_targets_r1947();
CREATE OR REPLACE FUNCTION public.critical_abm_targets_r1947()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  target_segment text,
  status text,
  last_touched_at timestamptz,
  days_since_touch integer
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
  SELECT t.id,
         t.hospital_id,
         COALESCE(o.name, p.full_name, p.email, 'unknown') AS hospital_name,
         t.target_segment,
         t.status,
         t.last_touched_at,
         CASE WHEN t.last_touched_at IS NULL THEN NULL
              ELSE EXTRACT(DAY FROM (now() - t.last_touched_at))::integer END AS days_since_touch
  FROM public.hospital_abm_targets_r1947 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE t.abm_priority = 'critical'
    AND t.status NOT IN ('won','lost','pause')
  ORDER BY t.last_touched_at ASC NULLS FIRST
  LIMIT 100;
END;
$$;

-- ============================================================================
-- RPC 7: recent_touches
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_abm_touches_r1947();
CREATE OR REPLACE FUNCTION public.recent_abm_touches_r1947()
RETURNS TABLE (
  id uuid,
  target_id uuid,
  hospital_name text,
  touch_type text,
  touched_at timestamptz,
  by_email text,
  outcome_md text
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
  SELECT l.id,
         l.target_id,
         COALESCE(o.name, p.full_name, p.email, 'unknown') AS hospital_name,
         l.touch_type,
         l.touched_at,
         l.by_email,
         l.outcome_md
  FROM public.hospital_abm_touch_log_r1947 l
  JOIN public.hospital_abm_targets_r1947 t ON t.id = l.target_id
  LEFT JOIN public.profiles p ON p.id = t.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY l.touched_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_abm_targets_r1947() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_abm_target_r1947(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_abm_touches_r1947(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_abm_touch_r1947(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_abm_status_r1947(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_abm_targets_r1947() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_abm_touches_r1947() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_abm_targets_r1947() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_abm_target_r1947(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_abm_touches_r1947(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_abm_touch_r1947(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_abm_status_r1947(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_abm_targets_r1947() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_abm_touches_r1947() TO authenticated;

COMMIT;
