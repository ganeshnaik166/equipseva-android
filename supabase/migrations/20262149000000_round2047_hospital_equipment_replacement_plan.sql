BEGIN;

-- ============================================================================
-- Round 2047: Hospital Equipment Replacement Plan
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_equipment_replacement_plan_r2047 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_age_years int NOT NULL DEFAULT 0,
  planned_replacement_date date,
  replacement_cost_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','quoted','approved','replaced','deferred')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hospital_equipment_replacement_plan_r2047_hosp_idx
  ON public.hospital_equipment_replacement_plan_r2047(hospital_id);
CREATE INDEX IF NOT EXISTS hospital_equipment_replacement_plan_r2047_date_idx
  ON public.hospital_equipment_replacement_plan_r2047(planned_replacement_date);
CREATE INDEX IF NOT EXISTS hospital_equipment_replacement_plan_r2047_status_idx
  ON public.hospital_equipment_replacement_plan_r2047(status);

CREATE TABLE IF NOT EXISTS public.hospital_replacement_action_log_r2047 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.hospital_equipment_replacement_plan_r2047(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('quote_requested','quote_received','approved','replaced','deferred','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hospital_replacement_action_log_r2047_plan_idx
  ON public.hospital_replacement_action_log_r2047(plan_id);
CREATE INDEX IF NOT EXISTS hospital_replacement_action_log_r2047_taken_idx
  ON public.hospital_replacement_action_log_r2047(taken_at DESC);

ALTER TABLE public.hospital_equipment_replacement_plan_r2047 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_replacement_action_log_r2047 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hospital_equipment_replacement_plan_r2047
  ON public.hospital_equipment_replacement_plan_r2047;
CREATE POLICY founder_all_hospital_equipment_replacement_plan_r2047
  ON public.hospital_equipment_replacement_plan_r2047
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hospital_replacement_action_log_r2047
  ON public.hospital_replacement_action_log_r2047;
CREATE POLICY founder_all_hospital_replacement_action_log_r2047
  ON public.hospital_replacement_action_log_r2047
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. list_plans
CREATE OR REPLACE FUNCTION public.list_replacement_plans_r2047()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  equipment_label text,
  equipment_age_years int,
  planned_replacement_date date,
  replacement_cost_rupees bigint,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_id, pr.email, p.equipment_label, p.equipment_age_years,
         p.planned_replacement_date, p.replacement_cost_rupees, p.status, p.captured_at
  FROM public.hospital_equipment_replacement_plan_r2047 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_id
  ORDER BY COALESCE(p.planned_replacement_date, current_date + 3650) ASC, p.captured_at DESC
  LIMIT 500;
END;
$$;

-- 2. log_plan
CREATE OR REPLACE FUNCTION public.log_replacement_plan_r2047(
  p_hospital_id uuid,
  p_equipment_label text,
  p_equipment_age_years int,
  p_planned_date date,
  p_cost_rupees bigint
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
  INSERT INTO public.hospital_equipment_replacement_plan_r2047
    (hospital_id, equipment_label, equipment_age_years, planned_replacement_date, replacement_cost_rupees)
  VALUES (p_hospital_id, p_equipment_label, COALESCE(p_equipment_age_years, 0),
          p_planned_date, COALESCE(p_cost_rupees, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_replacement_plan_r2047',
          jsonb_build_object('plan_id', v_id, 'hospital_id', p_hospital_id,
                             'equipment_label', p_equipment_label));
  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_replacement_actions_r2047(p_plan_id uuid)
RETURNS TABLE (
  id uuid,
  plan_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.plan_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_replacement_action_log_r2047 a
  WHERE a.plan_id = p_plan_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_replacement_action_r2047(
  p_plan_id uuid,
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
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_replacement_action_log_r2047
    (plan_id, action_type, by_email, notes_md)
  VALUES (p_plan_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_replacement_action_r2047',
          jsonb_build_object('action_id', v_id, 'plan_id', p_plan_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_replacement_status_r2047(
  p_plan_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_replacement_plan_r2047
  SET status = p_status, updated_at = now()
  WHERE id = p_plan_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_replacement_status_r2047',
          jsonb_build_object('plan_id', p_plan_id, 'status', p_status));
END;
$$;

-- 6. due_replacements
CREATE OR REPLACE FUNCTION public.due_replacements_r2047()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  equipment_label text,
  planned_replacement_date date,
  days_until int,
  replacement_cost_rupees bigint,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_id, pr.email, p.equipment_label,
         p.planned_replacement_date,
         (p.planned_replacement_date - current_date)::int,
         p.replacement_cost_rupees, p.status
  FROM public.hospital_equipment_replacement_plan_r2047 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_id
  WHERE p.planned_replacement_date IS NOT NULL
    AND p.status IN ('planned','quoted','approved')
    AND p.planned_replacement_date <= (current_date + 180)
  ORDER BY p.planned_replacement_date ASC
  LIMIT 200;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_replacement_actions_r2047()
RETURNS TABLE (
  id uuid,
  plan_id uuid,
  equipment_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.plan_id, p.equipment_label, a.action_type, a.taken_at, a.by_email
  FROM public.hospital_replacement_action_log_r2047 a
  JOIN public.hospital_equipment_replacement_plan_r2047 p ON p.id = a.plan_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_replacement_plans_r2047() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_replacement_plans_r2047() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_replacement_plan_r2047(uuid, text, int, date, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_replacement_plan_r2047(uuid, text, int, date, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_replacement_actions_r2047(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_replacement_actions_r2047(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_replacement_action_r2047(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_replacement_action_r2047(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_replacement_status_r2047(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_replacement_status_r2047(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.due_replacements_r2047() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.due_replacements_r2047() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_replacement_actions_r2047() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_replacement_actions_r2047() TO authenticated;

COMMIT;
