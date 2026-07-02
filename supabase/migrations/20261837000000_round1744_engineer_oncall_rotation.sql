BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_oncall_rotations_r1744 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rotation_week date NOT NULL,
  oncall_days text[] NOT NULL DEFAULT '{}',
  emergency_jobs_handled int NOT NULL DEFAULT 0,
  multiplier_applied numeric(5,2) NOT NULL DEFAULT 1.0,
  total_oncall_payout_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_oncall_call_outs_r1744 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rotation_id uuid NOT NULL REFERENCES public.engineer_oncall_rotations_r1744(id) ON DELETE CASCADE,
  call_time timestamptz NOT NULL DEFAULT now(),
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  response_time_min int NOT NULL DEFAULT 0,
  was_resolved boolean NOT NULL DEFAULT false,
  escalation_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oncall_rot_r1744_engineer ON public.engineer_oncall_rotations_r1744(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_oncall_rot_r1744_week ON public.engineer_oncall_rotations_r1744(rotation_week DESC);
CREATE INDEX IF NOT EXISTS idx_oncall_callouts_r1744_rot ON public.engineer_oncall_call_outs_r1744(rotation_id);
CREATE INDEX IF NOT EXISTS idx_oncall_callouts_r1744_time ON public.engineer_oncall_call_outs_r1744(call_time DESC);

ALTER TABLE public.engineer_oncall_rotations_r1744 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_oncall_call_outs_r1744 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_oncall_rot_r1744_founder ON public.engineer_oncall_rotations_r1744;
CREATE POLICY p_oncall_rot_r1744_founder ON public.engineer_oncall_rotations_r1744
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_oncall_callouts_r1744_founder ON public.engineer_oncall_call_outs_r1744;
CREATE POLICY p_oncall_callouts_r1744_founder ON public.engineer_oncall_call_outs_r1744
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.engineer_oncall_rotations_r1744 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.engineer_oncall_call_outs_r1744 FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.engineer_oncall_rotations_r1744 TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.engineer_oncall_call_outs_r1744 TO authenticated;

-- 1) list_rotations
DROP FUNCTION IF EXISTS public.r1744_list_rotations(int);
CREATE OR REPLACE FUNCTION public.r1744_list_rotations(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  rotation_week date,
  oncall_days text[],
  emergency_jobs_handled int,
  multiplier_applied numeric,
  total_oncall_payout_rupees bigint,
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
  SELECT r.id, r.engineer_user_id, p.email, r.rotation_week, r.oncall_days,
         r.emergency_jobs_handled, r.multiplier_applied, r.total_oncall_payout_rupees, r.created_at
  FROM public.engineer_oncall_rotations_r1744 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.rotation_week DESC, r.created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 50), 1);
END;
$$;

-- 2) schedule_rotation
DROP FUNCTION IF EXISTS public.r1744_schedule_rotation(uuid, date, text[], numeric);
CREATE OR REPLACE FUNCTION public.r1744_schedule_rotation(
  p_engineer_user_id uuid,
  p_rotation_week date,
  p_oncall_days text[],
  p_multiplier numeric
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
  INSERT INTO public.engineer_oncall_rotations_r1744(engineer_user_id, rotation_week, oncall_days, multiplier_applied)
  VALUES (p_engineer_user_id, p_rotation_week, COALESCE(p_oncall_days, '{}'), COALESCE(p_multiplier, 1.0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'r1744_schedule_rotation',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'rotation_week', p_rotation_week));
  RETURN v_id;
END;
$$;

-- 3) list_callouts
DROP FUNCTION IF EXISTS public.r1744_list_callouts(uuid, int);
CREATE OR REPLACE FUNCTION public.r1744_list_callouts(p_rotation_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  rotation_id uuid,
  call_time timestamptz,
  hospital_id uuid,
  hospital_name text,
  response_time_min int,
  was_resolved boolean,
  escalation_note text
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
  SELECT c.id, c.rotation_id, c.call_time, c.hospital_id, o.name,
         c.response_time_min, c.was_resolved, c.escalation_note
  FROM public.engineer_oncall_call_outs_r1744 c
  LEFT JOIN public.organizations o ON o.id = c.hospital_id
  WHERE p_rotation_id IS NULL OR c.rotation_id = p_rotation_id
  ORDER BY c.call_time DESC
  LIMIT GREATEST(COALESCE(p_limit, 100), 1);
END;
$$;

-- 4) log_callout
DROP FUNCTION IF EXISTS public.r1744_log_callout(uuid, uuid, int, boolean, text);
CREATE OR REPLACE FUNCTION public.r1744_log_callout(
  p_rotation_id uuid,
  p_hospital_id uuid,
  p_response_time_min int,
  p_was_resolved boolean,
  p_escalation_note text
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
  INSERT INTO public.engineer_oncall_call_outs_r1744(rotation_id, hospital_id, response_time_min, was_resolved, escalation_note)
  VALUES (p_rotation_id, p_hospital_id, COALESCE(p_response_time_min, 0), COALESCE(p_was_resolved, false), p_escalation_note)
  RETURNING id INTO v_id;

  UPDATE public.engineer_oncall_rotations_r1744
     SET emergency_jobs_handled = emergency_jobs_handled + 1,
         updated_at = now()
   WHERE id = p_rotation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'r1744_log_callout',
          jsonb_build_object('id', v_id, 'rotation_id', p_rotation_id, 'hospital_id', p_hospital_id));
  RETURN v_id;
END;
$$;

-- 5) rotation_summary
DROP FUNCTION IF EXISTS public.r1744_rotation_summary();
CREATE OR REPLACE FUNCTION public.r1744_rotation_summary()
RETURNS TABLE(
  total_rotations int,
  total_callouts int,
  resolved_callouts int,
  avg_response_min numeric,
  total_payout_rupees bigint
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
    (SELECT COUNT(*)::int FROM public.engineer_oncall_rotations_r1744),
    (SELECT COUNT(*)::int FROM public.engineer_oncall_call_outs_r1744),
    (SELECT (COUNT(*) FILTER (WHERE was_resolved))::int FROM public.engineer_oncall_call_outs_r1744),
    (SELECT COALESCE(ROUND(AVG(response_time_min)::numeric, 2), 0) FROM public.engineer_oncall_call_outs_r1744),
    (SELECT COALESCE(SUM(total_oncall_payout_rupees), 0)::bigint FROM public.engineer_oncall_rotations_r1744);
END;
$$;

-- 6) response_time_per_engineer
DROP FUNCTION IF EXISTS public.r1744_response_time_per_engineer();
CREATE OR REPLACE FUNCTION public.r1744_response_time_per_engineer()
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  callouts_count int,
  avg_response_min numeric,
  resolved_count int
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
  SELECT r.engineer_user_id,
         p.email,
         COUNT(c.id)::int,
         COALESCE(ROUND(AVG(c.response_time_min)::numeric, 2), 0),
         (COUNT(*) FILTER (WHERE c.was_resolved))::int
  FROM public.engineer_oncall_rotations_r1744 r
  LEFT JOIN public.engineer_oncall_call_outs_r1744 c ON c.rotation_id = r.id
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  GROUP BY r.engineer_user_id, p.email
  ORDER BY COUNT(c.id) DESC NULLS LAST;
END;
$$;

-- 7) top_response_engineers
DROP FUNCTION IF EXISTS public.r1744_top_response_engineers(int);
CREATE OR REPLACE FUNCTION public.r1744_top_response_engineers(p_limit int DEFAULT 10)
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  callouts_count int,
  avg_response_min numeric
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
  SELECT r.engineer_user_id,
         p.email,
         COUNT(c.id)::int,
         COALESCE(ROUND(AVG(c.response_time_min)::numeric, 2), 0)
  FROM public.engineer_oncall_rotations_r1744 r
  JOIN public.engineer_oncall_call_outs_r1744 c ON c.rotation_id = r.id
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  GROUP BY r.engineer_user_id, p.email
  HAVING COUNT(c.id) > 0
  ORDER BY AVG(c.response_time_min) ASC
  LIMIT GREATEST(COALESCE(p_limit, 10), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1744_list_rotations(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1744_schedule_rotation(uuid, date, text[], numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1744_list_callouts(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1744_log_callout(uuid, uuid, int, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1744_rotation_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1744_response_time_per_engineer() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1744_top_response_engineers(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1744_list_rotations(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1744_schedule_rotation(uuid, date, text[], numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1744_list_callouts(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1744_log_callout(uuid, uuid, int, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1744_rotation_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1744_response_time_per_engineer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1744_top_response_engineers(int) TO authenticated;

COMMIT;