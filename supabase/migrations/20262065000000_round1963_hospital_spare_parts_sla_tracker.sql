BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_spare_parts_sla_r1963 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  part_category text NOT NULL CHECK (part_category IN ('consumable','critical_spare','non_critical','long_lead_time')),
  target_delivery_hours integer NOT NULL CHECK (target_delivery_hours > 0),
  actual_delivery_hours integer NOT NULL CHECK (actual_delivery_hours >= 0),
  sla_met boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','breached','escalated','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsps_r1963_hospital ON public.hospital_spare_parts_sla_r1963(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hsps_r1963_status ON public.hospital_spare_parts_sla_r1963(status);
CREATE INDEX IF NOT EXISTS idx_hsps_r1963_captured ON public.hospital_spare_parts_sla_r1963(captured_at DESC);

ALTER TABLE public.hospital_spare_parts_sla_r1963 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsps_r1963_founder_all ON public.hospital_spare_parts_sla_r1963;
CREATE POLICY hsps_r1963_founder_all ON public.hospital_spare_parts_sla_r1963
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_sla_breach_log_r1963 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sla_id uuid NOT NULL REFERENCES public.hospital_spare_parts_sla_r1963(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('escalated','expedited_alternative','customer_notified','credit_issued','process_improved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsbl_r1963_sla ON public.hospital_sla_breach_log_r1963(sla_id);
CREATE INDEX IF NOT EXISTS idx_hsbl_r1963_taken ON public.hospital_sla_breach_log_r1963(taken_at DESC);

ALTER TABLE public.hospital_sla_breach_log_r1963 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsbl_r1963_founder_all ON public.hospital_sla_breach_log_r1963;
CREATE POLICY hsbl_r1963_founder_all ON public.hospital_sla_breach_log_r1963
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_slas
CREATE OR REPLACE FUNCTION public.list_slas_r1963()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  part_category text,
  target_delivery_hours integer,
  actual_delivery_hours integer,
  sla_met boolean,
  status text,
  captured_at timestamptz
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
  SELECT s.id, s.hospital_id, o.name, s.part_category, s.target_delivery_hours,
         s.actual_delivery_hours, s.sla_met, s.status, s.captured_at
  FROM public.hospital_spare_parts_sla_r1963 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  ORDER BY s.captured_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_sla
CREATE OR REPLACE FUNCTION public.log_sla_r1963(
  p_hospital_id uuid,
  p_part_category text,
  p_target_hours integer,
  p_actual_hours integer,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_met boolean;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_met := p_actual_hours <= p_target_hours;
  INSERT INTO public.hospital_spare_parts_sla_r1963(
    hospital_id, part_category, target_delivery_hours, actual_delivery_hours, sla_met, status
  ) VALUES (p_hospital_id, p_part_category, p_target_hours, p_actual_hours, v_met, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_sla_r1963',
    jsonb_build_object('sla_id', v_id, 'hospital_id', p_hospital_id, 'category', p_part_category, 'sla_met', v_met)
  );
  RETURN v_id;
END;
$$;

-- 3. list_breaches
CREATE OR REPLACE FUNCTION public.list_breaches_r1963(p_sla_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  sla_id uuid,
  hospital_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
  SELECT b.id, b.sla_id, o.name, b.action_type, b.taken_at, b.by_email, b.notes_md
  FROM public.hospital_sla_breach_log_r1963 b
  LEFT JOIN public.hospital_spare_parts_sla_r1963 s ON s.id = b.sla_id
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  WHERE p_sla_id IS NULL OR b.sla_id = p_sla_id
  ORDER BY b.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4. log_breach
CREATE OR REPLACE FUNCTION public.log_breach_r1963(
  p_sla_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_sla_breach_log_r1963(sla_id, action_type, by_email, notes_md)
  VALUES (p_sla_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_breach_r1963',
    jsonb_build_object('breach_id', v_id, 'sla_id', p_sla_id, 'action', p_action_type)
  );
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1963(
  p_sla_id uuid,
  p_status text
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
  UPDATE public.hospital_spare_parts_sla_r1963
  SET status = p_status, updated_at = now()
  WHERE id = p_sla_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r1963',
    jsonb_build_object('sla_id', p_sla_id, 'status', p_status)
  );
END;
$$;

-- 6. recent_breaches
CREATE OR REPLACE FUNCTION public.recent_breaches_r1963()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  part_category text,
  target_delivery_hours integer,
  actual_delivery_hours integer,
  captured_at timestamptz,
  status text
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
  SELECT s.id, o.name, s.part_category, s.target_delivery_hours,
         s.actual_delivery_hours, s.captured_at, s.status
  FROM public.hospital_spare_parts_sla_r1963 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  WHERE s.status IN ('breached','escalated')
    AND s.captured_at >= now() - interval '30 days'
  ORDER BY s.captured_at DESC
  LIMIT 50;
END;
$$;

-- 7. top_breach_hospitals
CREATE OR REPLACE FUNCTION public.top_breach_hospitals_r1963()
RETURNS TABLE (
  hospital_id uuid,
  hospital_name text,
  breach_count bigint,
  total_count bigint,
  breach_rate_pct numeric
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
  SELECT s.hospital_id, o.name,
         COUNT(*) FILTER (WHERE s.status IN ('breached','escalated'))::bigint,
         COUNT(*)::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE s.status IN ('breached','escalated'))::numeric / NULLIF(COUNT(*),0), 2)
  FROM public.hospital_spare_parts_sla_r1963 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  GROUP BY s.hospital_id, o.name
  HAVING COUNT(*) FILTER (WHERE s.status IN ('breached','escalated')) > 0
  ORDER BY COUNT(*) FILTER (WHERE s.status IN ('breached','escalated')) DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_slas_r1963() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_sla_r1963(uuid, text, integer, integer, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_breaches_r1963(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_breach_r1963(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1963(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_breaches_r1963() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_breach_hospitals_r1963() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_slas_r1963() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_sla_r1963(uuid, text, integer, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_breaches_r1963(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_breach_r1963(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1963(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_breaches_r1963() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_breach_hospitals_r1963() TO authenticated;

COMMIT;
