BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_brand_standards_r1763 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  standard_type text NOT NULL CHECK (standard_type IN ('signage','uniform','materials','equipment_decals','website_link')),
  compliance_score int NOT NULL DEFAULT 0 CHECK (compliance_score >= 0 AND compliance_score <= 100),
  last_audited_at timestamptz,
  status text NOT NULL DEFAULT 'partial' CHECK (status IN ('compliant','partial','non_compliant')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_brand_remediation_actions_r1763 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  standard_id uuid NOT NULL REFERENCES public.hospital_brand_standards_r1763(id) ON DELETE CASCADE,
  action text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','cancelled')),
  cost_rupees int NOT NULL DEFAULT 0,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_brand_standards_r1763 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_brand_remediation_actions_r1763 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_brand_standards_r1763 ON public.hospital_brand_standards_r1763;
CREATE POLICY founder_all_brand_standards_r1763 ON public.hospital_brand_standards_r1763
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_brand_actions_r1763 ON public.hospital_brand_remediation_actions_r1763;
CREATE POLICY founder_all_brand_actions_r1763 ON public.hospital_brand_remediation_actions_r1763
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_brand_standards_r1763_hospital ON public.hospital_brand_standards_r1763(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_brand_standards_r1763_status ON public.hospital_brand_standards_r1763(status);
CREATE INDEX IF NOT EXISTS idx_brand_standards_r1763_type ON public.hospital_brand_standards_r1763(standard_type);
CREATE INDEX IF NOT EXISTS idx_brand_actions_r1763_standard ON public.hospital_brand_remediation_actions_r1763(standard_id);
CREATE INDEX IF NOT EXISTS idx_brand_actions_r1763_status ON public.hospital_brand_remediation_actions_r1763(status);

DROP FUNCTION IF EXISTS public.list_standards_r1763();
CREATE OR REPLACE FUNCTION public.list_standards_r1763()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  hospital_city text,
  standard_type text,
  compliance_score int,
  last_audited_at timestamptz,
  status text,
  notes text,
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
    s.id,
    s.hospital_user_id,
    COALESCE(o.name, p.email) AS hospital_name,
    o.city AS hospital_city,
    s.standard_type,
    s.compliance_score,
    s.last_audited_at,
    s.status,
    s.notes,
    s.created_at
  FROM public.hospital_brand_standards_r1763 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.compliance_score ASC, s.created_at DESC
  LIMIT 500;
END;
$$;

DROP FUNCTION IF EXISTS public.audit_standard_r1763(uuid, uuid, text, int, text, text);
CREATE OR REPLACE FUNCTION public.audit_standard_r1763(
  p_id uuid,
  p_hospital_user_id uuid,
  p_standard_type text,
  p_compliance_score int,
  p_status text,
  p_notes text
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

  IF p_id IS NULL THEN
    INSERT INTO public.hospital_brand_standards_r1763 (
      hospital_user_id, standard_type, compliance_score, last_audited_at, status, notes
    ) VALUES (
      p_hospital_user_id, p_standard_type, p_compliance_score, now(), p_status, p_notes
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.hospital_brand_standards_r1763
    SET compliance_score = p_compliance_score,
        status = p_status,
        notes = p_notes,
        last_audited_at = now(),
        updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'audit_standard_r1763',
    jsonb_build_object(
      'id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'standard_type', p_standard_type,
      'compliance_score', p_compliance_score,
      'status', p_status
    )
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_actions_r1763();
CREATE OR REPLACE FUNCTION public.list_actions_r1763()
RETURNS TABLE (
  id uuid,
  standard_id uuid,
  standard_type text,
  hospital_name text,
  action text,
  owner_email text,
  due_date date,
  status text,
  cost_rupees int,
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
    a.standard_id,
    s.standard_type,
    COALESCE(o.name, p.email) AS hospital_name,
    a.action,
    a.owner_email,
    a.due_date,
    a.status,
    a.cost_rupees,
    a.completed_at,
    a.created_at
  FROM public.hospital_brand_remediation_actions_r1763 a
  LEFT JOIN public.hospital_brand_standards_r1763 s ON s.id = a.standard_id
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY
    CASE a.status WHEN 'open' THEN 0 WHEN 'done' THEN 1 ELSE 2 END,
    a.due_date NULLS LAST
  LIMIT 500;
END;
$$;

DROP FUNCTION IF EXISTS public.log_action_r1763(uuid, text, text, date, int);
CREATE OR REPLACE FUNCTION public.log_action_r1763(
  p_standard_id uuid,
  p_action text,
  p_owner_email text,
  p_due_date date,
  p_cost_rupees int
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

  INSERT INTO public.hospital_brand_remediation_actions_r1763 (
    standard_id, action, owner_email, due_date, cost_rupees
  ) VALUES (
    p_standard_id, p_action, p_owner_email, p_due_date, COALESCE(p_cost_rupees, 0)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_action_r1763',
    jsonb_build_object(
      'id', v_id,
      'standard_id', p_standard_id,
      'action', p_action,
      'owner_email', p_owner_email,
      'due_date', p_due_date,
      'cost_rupees', p_cost_rupees
    )
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.complete_action_r1763(uuid, text);
CREATE OR REPLACE FUNCTION public.complete_action_r1763(
  p_id uuid,
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

  IF p_status NOT IN ('open','done','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.hospital_brand_remediation_actions_r1763
  SET status = p_status,
      completed_at = CASE WHEN p_status = 'done' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_id
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'complete_action_r1763',
    jsonb_build_object('id', v_id, 'status', p_status)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.compliance_summary_r1763();
CREATE OR REPLACE FUNCTION public.compliance_summary_r1763()
RETURNS TABLE (
  standard_type text,
  total_count int,
  compliant_count int,
  partial_count int,
  non_compliant_count int,
  avg_score numeric,
  open_actions int,
  total_cost_rupees bigint
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
    s.standard_type,
    COUNT(*)::int AS total_count,
    (COUNT(*) FILTER (WHERE s.status = 'compliant'))::int AS compliant_count,
    (COUNT(*) FILTER (WHERE s.status = 'partial'))::int AS partial_count,
    (COUNT(*) FILTER (WHERE s.status = 'non_compliant'))::int AS non_compliant_count,
    ROUND(AVG(s.compliance_score)::numeric, 1) AS avg_score,
    (SELECT COUNT(*) FROM public.hospital_brand_remediation_actions_r1763 a
       WHERE a.status = 'open'
         AND a.standard_id IN (
           SELECT id FROM public.hospital_brand_standards_r1763 s2
           WHERE s2.standard_type = s.standard_type
         ))::int AS open_actions,
    COALESCE((SELECT SUM(a.cost_rupees) FROM public.hospital_brand_remediation_actions_r1763 a
       WHERE a.standard_id IN (
         SELECT id FROM public.hospital_brand_standards_r1763 s3
         WHERE s3.standard_type = s.standard_type
       )), 0)::bigint AS total_cost_rupees
  FROM public.hospital_brand_standards_r1763 s
  GROUP BY s.standard_type
  ORDER BY avg_score ASC NULLS FIRST;
END;
$$;

DROP FUNCTION IF EXISTS public.top_non_compliant_r1763();
CREATE OR REPLACE FUNCTION public.top_non_compliant_r1763()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_name text,
  hospital_city text,
  audited_count int,
  avg_score numeric,
  non_compliant_count int,
  open_actions int,
  last_audited_at timestamptz
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
    s.hospital_user_id,
    COALESCE(o.name, p.email) AS hospital_name,
    o.city AS hospital_city,
    COUNT(*)::int AS audited_count,
    ROUND(AVG(s.compliance_score)::numeric, 1) AS avg_score,
    (COUNT(*) FILTER (WHERE s.status = 'non_compliant'))::int AS non_compliant_count,
    (SELECT COUNT(*) FROM public.hospital_brand_remediation_actions_r1763 a
       WHERE a.status = 'open'
         AND a.standard_id IN (
           SELECT id FROM public.hospital_brand_standards_r1763 s2
           WHERE s2.hospital_user_id = s.hospital_user_id
         ))::int AS open_actions,
    MAX(s.last_audited_at) AS last_audited_at
  FROM public.hospital_brand_standards_r1763 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  GROUP BY s.hospital_user_id, o.name, p.email, o.city
  ORDER BY avg_score ASC NULLS FIRST, non_compliant_count DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_standards_r1763() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.audit_standard_r1763(uuid, uuid, text, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1763() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1763(uuid, text, text, date, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_action_r1763(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.compliance_summary_r1763() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_non_compliant_r1763() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_standards_r1763() TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_standard_r1763(uuid, uuid, text, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1763() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1763(uuid, text, text, date, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_action_r1763(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.compliance_summary_r1763() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_non_compliant_r1763() TO authenticated;

COMMIT;