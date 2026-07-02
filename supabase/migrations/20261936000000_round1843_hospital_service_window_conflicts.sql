BEGIN;

-- ============================================================================
-- Round 1843: Hospital Service Window Conflicts
-- Track simultaneous emergency-service capacity conflicts across hospitals
-- ============================================================================

-- Conflicts table
CREATE TABLE IF NOT EXISTS public.hospital_service_window_conflicts_r1843 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conflict_at timestamptz NOT NULL DEFAULT now(),
  hospital_ids uuid[] NOT NULL DEFAULT '{}'::uuid[],
  resolution_path text CHECK (resolution_path IN ('escalate_engineer','pause_one','decline_one','parallel_dispatch')),
  resolved_at timestamptz,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Resolution log table
CREATE TABLE IF NOT EXISTS public.hospital_service_window_resolution_log_r1843 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conflict_id uuid NOT NULL REFERENCES public.hospital_service_window_conflicts_r1843(id) ON DELETE CASCADE,
  action_taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  decision text CHECK (decision IN ('apologize','credit','escalate','escalate_to_partner')),
  customer_response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.hospital_service_window_conflicts_r1843 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_window_resolution_log_r1843 ENABLE ROW LEVEL SECURITY;

-- Founder-only RLS
DROP POLICY IF EXISTS founder_all_conflicts_r1843 ON public.hospital_service_window_conflicts_r1843;
CREATE POLICY founder_all_conflicts_r1843 ON public.hospital_service_window_conflicts_r1843
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_resolution_log_r1843 ON public.hospital_service_window_resolution_log_r1843;
CREATE POLICY founder_all_resolution_log_r1843 ON public.hospital_service_window_resolution_log_r1843
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1) list_conflicts
DROP FUNCTION IF EXISTS public.list_hsw_conflicts_r1843();
CREATE OR REPLACE FUNCTION public.list_hsw_conflicts_r1843()
RETURNS TABLE (
  id uuid,
  conflict_at timestamptz,
  hospital_count int,
  resolution_path text,
  resolved_at timestamptz,
  founder_note text,
  is_resolved boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.conflict_at,
    COALESCE(array_length(c.hospital_ids,1),0)::int AS hospital_count,
    c.resolution_path,
    c.resolved_at,
    c.founder_note,
    (c.resolved_at IS NOT NULL) AS is_resolved
  FROM public.hospital_service_window_conflicts_r1843 c
  ORDER BY c.conflict_at DESC
  LIMIT 200;
END;
$$;

-- 2) log_conflict
DROP FUNCTION IF EXISTS public.log_hsw_conflict_r1843(uuid[], text, text);
CREATE OR REPLACE FUNCTION public.log_hsw_conflict_r1843(
  p_hospital_ids uuid[],
  p_resolution_path text DEFAULT NULL,
  p_founder_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_window_conflicts_r1843 (hospital_ids, resolution_path, founder_note)
  VALUES (COALESCE(p_hospital_ids,'{}'::uuid[]), p_resolution_path, p_founder_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_hsw_conflict_r1843',
    jsonb_build_object('id', v_id, 'hospital_ids', p_hospital_ids, 'resolution_path', p_resolution_path)
  );

  RETURN v_id;
END;
$$;

-- 3) list_resolutions
DROP FUNCTION IF EXISTS public.list_hsw_resolutions_r1843(uuid);
CREATE OR REPLACE FUNCTION public.list_hsw_resolutions_r1843(p_conflict_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  conflict_id uuid,
  action_taken_at timestamptz,
  by_email text,
  decision text,
  customer_response text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.conflict_id, r.action_taken_at, r.by_email, r.decision, r.customer_response
  FROM public.hospital_service_window_resolution_log_r1843 r
  WHERE p_conflict_id IS NULL OR r.conflict_id = p_conflict_id
  ORDER BY r.action_taken_at DESC
  LIMIT 200;
END;
$$;

-- 4) log_resolution
DROP FUNCTION IF EXISTS public.log_hsw_resolution_r1843(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_hsw_resolution_r1843(
  p_conflict_id uuid,
  p_decision text,
  p_customer_response text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.hospital_service_window_resolution_log_r1843 (conflict_id, by_email, decision, customer_response)
  VALUES (p_conflict_id, v_email, p_decision, p_customer_response)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_hsw_resolution_r1843',
    jsonb_build_object('id', v_id, 'conflict_id', p_conflict_id, 'decision', p_decision)
  );

  RETURN v_id;
END;
$$;

-- 5) resolve_conflict
DROP FUNCTION IF EXISTS public.resolve_hsw_conflict_r1843(uuid, text, text);
CREATE OR REPLACE FUNCTION public.resolve_hsw_conflict_r1843(
  p_conflict_id uuid,
  p_resolution_path text,
  p_founder_note text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_window_conflicts_r1843
  SET resolution_path = p_resolution_path,
      resolved_at = now(),
      founder_note = COALESCE(p_founder_note, founder_note),
      updated_at = now()
  WHERE id = p_conflict_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'resolve_hsw_conflict_r1843',
    jsonb_build_object('id', p_conflict_id, 'resolution_path', p_resolution_path)
  );

  RETURN true;
END;
$$;

-- 6) conflict_pattern_summary
DROP FUNCTION IF EXISTS public.hsw_conflict_pattern_summary_r1843();
CREATE OR REPLACE FUNCTION public.hsw_conflict_pattern_summary_r1843()
RETURNS TABLE (
  resolution_path text,
  total int,
  resolved int,
  open_count int,
  avg_hospitals numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(c.resolution_path, 'unassigned') AS resolution_path,
    COUNT(*)::int AS total,
    (COUNT(*) FILTER (WHERE c.resolved_at IS NOT NULL))::int AS resolved,
    (COUNT(*) FILTER (WHERE c.resolved_at IS NULL))::int AS open_count,
    ROUND(AVG(COALESCE(array_length(c.hospital_ids,1),0))::numeric, 2) AS avg_hospitals
  FROM public.hospital_service_window_conflicts_r1843 c
  GROUP BY COALESCE(c.resolution_path,'unassigned')
  ORDER BY total DESC;
END;
$$;

-- 7) recent_conflicts (last 7 days)
DROP FUNCTION IF EXISTS public.hsw_recent_conflicts_r1843();
CREATE OR REPLACE FUNCTION public.hsw_recent_conflicts_r1843()
RETURNS TABLE (
  id uuid,
  conflict_at timestamptz,
  hospital_count int,
  resolution_path text,
  is_resolved boolean,
  age_hours numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.conflict_at,
    COALESCE(array_length(c.hospital_ids,1),0)::int AS hospital_count,
    c.resolution_path,
    (c.resolved_at IS NOT NULL) AS is_resolved,
    ROUND(EXTRACT(EPOCH FROM (now() - c.conflict_at))/3600.0, 2) AS age_hours
  FROM public.hospital_service_window_conflicts_r1843 c
  WHERE c.conflict_at >= now() - interval '7 days'
  ORDER BY c.conflict_at DESC
  LIMIT 100;
END;
$$;

-- Lock down
REVOKE EXECUTE ON FUNCTION public.list_hsw_conflicts_r1843() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_hsw_conflict_r1843(uuid[], text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_hsw_resolutions_r1843(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_hsw_resolution_r1843(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.resolve_hsw_conflict_r1843(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hsw_conflict_pattern_summary_r1843() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hsw_recent_conflicts_r1843() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hsw_conflicts_r1843() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hsw_conflict_r1843(uuid[], text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_hsw_resolutions_r1843(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hsw_resolution_r1843(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_hsw_conflict_r1843(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hsw_conflict_pattern_summary_r1843() TO authenticated;
GRANT EXECUTE ON FUNCTION public.hsw_recent_conflicts_r1843() TO authenticated;

COMMIT;