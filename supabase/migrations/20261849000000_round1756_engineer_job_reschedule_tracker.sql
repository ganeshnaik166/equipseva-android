BEGIN;

-- =========================================================================
-- Round 1756: Engineer Job Reschedule Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_job_reschedules_r1756 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  original_scheduled_at timestamptz NOT NULL,
  new_scheduled_at timestamptz NOT NULL,
  reschedule_reason text NOT NULL CHECK (reschedule_reason IN ('engineer_unavailable','hospital_unavailable','parts_pending','weather','emergency')),
  requested_by text NOT NULL CHECK (requested_by IN ('engineer','hospital','founder')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  customer_impact_score int NOT NULL CHECK (customer_impact_score BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ejr_r1756_job ON public.engineer_job_reschedules_r1756(repair_job_id);
CREATE INDEX IF NOT EXISTS idx_ejr_r1756_eng ON public.engineer_job_reschedules_r1756(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ejr_r1756_req_at ON public.engineer_job_reschedules_r1756(requested_at DESC);

ALTER TABLE public.engineer_job_reschedules_r1756 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ejr_r1756 ON public.engineer_job_reschedules_r1756;
CREATE POLICY founder_all_ejr_r1756 ON public.engineer_job_reschedules_r1756
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_reschedule_compensations_r1756 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reschedule_id uuid NOT NULL REFERENCES public.engineer_job_reschedules_r1756(id) ON DELETE CASCADE,
  compensation_type text NOT NULL CHECK (compensation_type IN ('apology_credit','free_service','founder_call','no_action')),
  applied_at timestamptz NOT NULL DEFAULT now(),
  applied_by_email text,
  value_rupees int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_erc_r1756_resch ON public.engineer_reschedule_compensations_r1756(reschedule_id);
CREATE INDEX IF NOT EXISTS idx_erc_r1756_applied ON public.engineer_reschedule_compensations_r1756(applied_at DESC);

ALTER TABLE public.engineer_reschedule_compensations_r1756 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_erc_r1756 ON public.engineer_reschedule_compensations_r1756;
CREATE POLICY founder_all_erc_r1756 ON public.engineer_reschedule_compensations_r1756
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs (7)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.list_reschedules_r1756(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  repair_job_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  original_scheduled_at timestamptz,
  new_scheduled_at timestamptz,
  reschedule_reason text,
  requested_by text,
  requested_at timestamptz,
  customer_impact_score int,
  delay_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.repair_job_id, r.engineer_user_id,
         p.email::text,
         r.original_scheduled_at, r.new_scheduled_at,
         r.reschedule_reason, r.requested_by, r.requested_at,
         r.customer_impact_score,
         ROUND(EXTRACT(EPOCH FROM (r.new_scheduled_at - r.original_scheduled_at))/3600.0, 2)::numeric
  FROM public.engineer_job_reschedules_r1756 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.requested_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reschedule_r1756(
  p_repair_job_id uuid,
  p_engineer_user_id uuid,
  p_original_scheduled_at timestamptz,
  p_new_scheduled_at timestamptz,
  p_reschedule_reason text,
  p_requested_by text,
  p_customer_impact_score int
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
  INSERT INTO public.engineer_job_reschedules_r1756(
    repair_job_id, engineer_user_id, original_scheduled_at,
    new_scheduled_at, reschedule_reason, requested_by, customer_impact_score
  ) VALUES (
    p_repair_job_id, p_engineer_user_id, p_original_scheduled_at,
    p_new_scheduled_at, p_reschedule_reason, p_requested_by, p_customer_impact_score
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reschedule_r1756',
          jsonb_build_object('id', v_id, 'repair_job_id', p_repair_job_id, 'reason', p_reschedule_reason));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_compensations_r1756(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  reschedule_id uuid,
  compensation_type text,
  applied_at timestamptz,
  applied_by_email text,
  value_rupees int,
  engineer_user_id uuid,
  reschedule_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.reschedule_id, c.compensation_type, c.applied_at,
         c.applied_by_email, c.value_rupees,
         r.engineer_user_id, r.reschedule_reason
  FROM public.engineer_reschedule_compensations_r1756 c
  JOIN public.engineer_job_reschedules_r1756 r ON r.id = c.reschedule_id
  ORDER BY c.applied_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_compensation_r1756(
  p_reschedule_id uuid,
  p_compensation_type text,
  p_value_rupees int
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
  INSERT INTO public.engineer_reschedule_compensations_r1756(
    reschedule_id, compensation_type, applied_by_email, value_rupees
  ) VALUES (
    p_reschedule_id, p_compensation_type, (auth.jwt()->>'email'), COALESCE(p_value_rupees, 0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'apply_compensation_r1756',
          jsonb_build_object('id', v_id, 'reschedule_id', p_reschedule_id,
                             'compensation_type', p_compensation_type, 'value_rupees', p_value_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reschedule_summary_r1756()
RETURNS TABLE (
  total_reschedules bigint,
  high_impact_count bigint,
  total_compensation_rupees bigint,
  avg_impact_score numeric,
  engineer_initiated bigint,
  hospital_initiated bigint,
  founder_initiated bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.engineer_job_reschedules_r1756)::bigint,
    (SELECT (COUNT(*) FILTER (WHERE customer_impact_score >= 4)) FROM public.engineer_job_reschedules_r1756)::bigint,
    (SELECT COALESCE(SUM(value_rupees), 0) FROM public.engineer_reschedule_compensations_r1756)::bigint,
    (SELECT COALESCE(ROUND(AVG(customer_impact_score)::numeric, 2), 0) FROM public.engineer_job_reschedules_r1756),
    (SELECT (COUNT(*) FILTER (WHERE requested_by = 'engineer')) FROM public.engineer_job_reschedules_r1756)::bigint,
    (SELECT (COUNT(*) FILTER (WHERE requested_by = 'hospital')) FROM public.engineer_job_reschedules_r1756)::bigint,
    (SELECT (COUNT(*) FILTER (WHERE requested_by = 'founder')) FROM public.engineer_job_reschedules_r1756)::bigint;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_reschedule_engineers_r1756(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  reschedule_count bigint,
  avg_impact numeric,
  high_impact_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_user_id,
         p.email::text,
         COUNT(*)::bigint,
         ROUND(AVG(r.customer_impact_score)::numeric, 2),
         (COUNT(*) FILTER (WHERE r.customer_impact_score >= 4))::bigint
  FROM public.engineer_job_reschedules_r1756 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  GROUP BY r.engineer_user_id, p.email
  ORDER BY COUNT(*) DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.high_impact_reschedules_r1756(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  repair_job_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  reschedule_reason text,
  requested_by text,
  requested_at timestamptz,
  customer_impact_score int,
  delay_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.repair_job_id, r.engineer_user_id,
         p.email::text,
         r.reschedule_reason, r.requested_by, r.requested_at,
         r.customer_impact_score,
         ROUND(EXTRACT(EPOCH FROM (r.new_scheduled_at - r.original_scheduled_at))/3600.0, 2)::numeric
  FROM public.engineer_job_reschedules_r1756 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE r.customer_impact_score >= 4
  ORDER BY r.customer_impact_score DESC, r.requested_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_reschedules_r1756(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reschedule_r1756(uuid, uuid, timestamptz, timestamptz, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_compensations_r1756(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.apply_compensation_r1756(uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reschedule_summary_r1756() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_reschedule_engineers_r1756(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_impact_reschedules_r1756(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reschedules_r1756(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reschedule_r1756(uuid, uuid, timestamptz, timestamptz, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_compensations_r1756(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_compensation_r1756(uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reschedule_summary_r1756() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_reschedule_engineers_r1756(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_impact_reschedules_r1756(int) TO authenticated;

COMMIT;