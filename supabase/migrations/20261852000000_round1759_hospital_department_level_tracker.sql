BEGIN;

-- Round 1759 — Hospital Department-Level Tracker
-- HEAVY founder console feature: per-hospital department breakdown (OPD, ICU, ED, OT, lab, radiology, dialysis)
-- of equipment + service revenue, with action items per department.

CREATE TABLE IF NOT EXISTS public.hospital_departments_r1759 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  department_name text NOT NULL,
  department_type text NOT NULL CHECK (department_type IN ('opd','icu','ed','ot','lab','radiology','dialysis')),
  equipment_count int NOT NULL DEFAULT 0 CHECK (equipment_count >= 0),
  monthly_service_revenue_rupees bigint NOT NULL DEFAULT 0 CHECK (monthly_service_revenue_rupees >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_audited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_departments_r1759_hospital ON public.hospital_departments_r1759(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hospital_departments_r1759_type ON public.hospital_departments_r1759(department_type);
CREATE INDEX IF NOT EXISTS idx_hospital_departments_r1759_status ON public.hospital_departments_r1759(status);

ALTER TABLE public.hospital_departments_r1759 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hospital_departments_r1759_founder_all ON public.hospital_departments_r1759;
CREATE POLICY hospital_departments_r1759_founder_all
  ON public.hospital_departments_r1759
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_department_action_items_r1759 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid NOT NULL REFERENCES public.hospital_departments_r1759(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_department_action_items_r1759_dept ON public.hospital_department_action_items_r1759(department_id);
CREATE INDEX IF NOT EXISTS idx_hospital_department_action_items_r1759_status ON public.hospital_department_action_items_r1759(status);

ALTER TABLE public.hospital_department_action_items_r1759 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hospital_department_action_items_r1759_founder_all ON public.hospital_department_action_items_r1759;
CREATE POLICY hospital_department_action_items_r1759_founder_all
  ON public.hospital_department_action_items_r1759
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_departments_r1759
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_departments_r1759()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  hospital_city text,
  department_name text,
  department_type text,
  equipment_count int,
  monthly_service_revenue_rupees bigint,
  status text,
  last_audited_at timestamptz,
  open_action_count int,
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
    d.id,
    d.hospital_user_id,
    COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
    o.city AS hospital_city,
    d.department_name,
    d.department_type,
    d.equipment_count,
    d.monthly_service_revenue_rupees,
    d.status,
    d.last_audited_at,
    (COUNT(a.id) FILTER (WHERE a.status = 'open'))::int AS open_action_count,
    d.created_at
  FROM public.hospital_departments_r1759 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  LEFT JOIN public.hospital_department_action_items_r1759 a ON a.department_id = d.id
  GROUP BY d.id, o.name, p.full_name, o.city
  ORDER BY d.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_departments_r1759() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_departments_r1759() TO authenticated;

-- ============================================================================
-- RPC 2: add_department_r1759
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_department_r1759(
  p_hospital_user_id uuid,
  p_department_name text,
  p_department_type text,
  p_equipment_count int,
  p_monthly_service_revenue_rupees bigint
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

  IF p_department_type NOT IN ('opd','icu','ed','ot','lab','radiology','dialysis') THEN
    RAISE EXCEPTION 'invalid department_type: %', p_department_type;
  END IF;

  INSERT INTO public.hospital_departments_r1759 (
    hospital_user_id, department_name, department_type,
    equipment_count, monthly_service_revenue_rupees
  )
  VALUES (
    p_hospital_user_id, p_department_name, p_department_type,
    COALESCE(p_equipment_count, 0), COALESCE(p_monthly_service_revenue_rupees, 0)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_department_r1759',
    jsonb_build_object(
      'department_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'department_name', p_department_name,
      'department_type', p_department_type
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_department_r1759(uuid, text, text, int, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_department_r1759(uuid, text, text, int, bigint) TO authenticated;

-- ============================================================================
-- RPC 3: list_actions_r1759
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1759()
RETURNS TABLE (
  id uuid,
  department_id uuid,
  department_name text,
  hospital_name text,
  action_text text,
  owner_email text,
  due_date date,
  status text,
  days_until_due int,
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
    a.department_id,
    d.department_name,
    COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
    a.action_text,
    a.owner_email,
    a.due_date,
    a.status,
    CASE WHEN a.due_date IS NULL THEN NULL
         ELSE (a.due_date - CURRENT_DATE)::int
    END AS days_until_due,
    a.created_at
  FROM public.hospital_department_action_items_r1759 a
  JOIN public.hospital_departments_r1759 d ON d.id = a.department_id
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY
    CASE WHEN a.status = 'open' THEN 0 ELSE 1 END,
    a.due_date NULLS LAST,
    a.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r1759() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r1759() TO authenticated;

-- ============================================================================
-- RPC 4: add_action_r1759
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_action_r1759(
  p_department_id uuid,
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

  INSERT INTO public.hospital_department_action_items_r1759 (
    department_id, action_text, owner_email, due_date
  )
  VALUES (
    p_department_id, p_action_text, p_owner_email, p_due_date
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_action_r1759',
    jsonb_build_object(
      'action_id', v_id,
      'department_id', p_department_id,
      'action_text', p_action_text,
      'owner_email', p_owner_email,
      'due_date', p_due_date
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_action_r1759(uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_action_r1759(uuid, text, text, date) TO authenticated;

-- ============================================================================
-- RPC 5: complete_action_r1759
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_action_r1759(
  p_action_id uuid,
  p_status text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('done','dropped') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE public.hospital_department_action_items_r1759
  SET status = p_status,
      updated_at = now()
  WHERE id = p_action_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'complete_action_r1759',
    jsonb_build_object(
      'action_id', p_action_id,
      'new_status', p_status
    )
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.complete_action_r1759(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_action_r1759(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: dept_revenue_summary_r1759
-- ============================================================================
CREATE OR REPLACE FUNCTION public.dept_revenue_summary_r1759()
RETURNS TABLE (
  department_type text,
  dept_count int,
  total_equipment int,
  total_monthly_revenue_rupees bigint,
  avg_monthly_revenue_rupees bigint,
  active_count int,
  inactive_count int
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
    d.department_type,
    COUNT(*)::int AS dept_count,
    COALESCE(SUM(d.equipment_count), 0)::int AS total_equipment,
    COALESCE(SUM(d.monthly_service_revenue_rupees), 0)::bigint AS total_monthly_revenue_rupees,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE (COALESCE(SUM(d.monthly_service_revenue_rupees), 0) / COUNT(*))::bigint
    END AS avg_monthly_revenue_rupees,
    (COUNT(*) FILTER (WHERE d.status = 'active'))::int AS active_count,
    (COUNT(*) FILTER (WHERE d.status = 'inactive'))::int AS inactive_count
  FROM public.hospital_departments_r1759 d
  GROUP BY d.department_type
  ORDER BY total_monthly_revenue_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.dept_revenue_summary_r1759() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dept_revenue_summary_r1759() TO authenticated;

-- ============================================================================
-- RPC 7: departments_needing_audit_r1759
-- ============================================================================
CREATE OR REPLACE FUNCTION public.departments_needing_audit_r1759()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  department_name text,
  department_type text,
  last_audited_at timestamptz,
  days_since_audit int,
  equipment_count int,
  monthly_service_revenue_rupees bigint
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
    d.id,
    COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
    d.department_name,
    d.department_type,
    d.last_audited_at,
    CASE WHEN d.last_audited_at IS NULL THEN NULL
         ELSE EXTRACT(DAY FROM (now() - d.last_audited_at))::int
    END AS days_since_audit,
    d.equipment_count,
    d.monthly_service_revenue_rupees
  FROM public.hospital_departments_r1759 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE d.status = 'active'
    AND (d.last_audited_at IS NULL OR d.last_audited_at < now() - interval '90 days')
  ORDER BY d.last_audited_at NULLS FIRST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.departments_needing_audit_r1759() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.departments_needing_audit_r1759() TO authenticated;

COMMIT;