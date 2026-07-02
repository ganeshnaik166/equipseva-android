BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_safety_incidents_r2338 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  incident_type text NOT NULL CHECK (incident_type IN ('slip_trip_fall','electric_shock','biohazard','sharps_injury','chemical_exposure','radiation_exposure','lifting_strain','vehicle','other')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  site_location text NOT NULL DEFAULT '',
  job_id uuid,
  severity text NOT NULL DEFAULT 'minor' CHECK (severity IN ('near_miss','minor','moderate','serious','critical')),
  description_md text NOT NULL DEFAULT '',
  immediate_action_md text NOT NULL DEFAULT '',
  reported_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','under_rca','mitigated','closed')),
  rca_summary_md text NOT NULL DEFAULT '',
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_safety_mitigations_r2338 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.engineer_safety_incidents_r2338(id) ON DELETE CASCADE,
  mitigation_text text NOT NULL,
  category text NOT NULL DEFAULT 'process' CHECK (category IN ('ppe','training','process','equipment','policy','other')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_date date,
  applied_at timestamptz,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','applied','verified','dropped')),
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_safety_incidents_r2338 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_safety_mitigations_r2338 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_incidents_r2338 ON public.engineer_safety_incidents_r2338;
CREATE POLICY founder_all_incidents_r2338 ON public.engineer_safety_incidents_r2338
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_mitig_r2338 ON public.engineer_safety_mitigations_r2338;
CREATE POLICY founder_all_mitig_r2338 ON public.engineer_safety_mitigations_r2338
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_incidents
CREATE OR REPLACE FUNCTION public.list_incidents_r2338()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  incident_type text,
  occurred_at timestamptz,
  site_location text,
  severity text,
  status text,
  mitigation_count int,
  applied_mitigation_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, p.email, i.incident_type, i.occurred_at, i.site_location, i.severity, i.status,
    (SELECT (COUNT(*))::int FROM public.engineer_safety_mitigations_r2338 m WHERE m.incident_id = i.id) AS mitigation_count,
    (SELECT (COUNT(*))::int FROM public.engineer_safety_mitigations_r2338 m WHERE m.incident_id = i.id AND m.status IN ('applied','verified')) AS applied_mitigation_count
  FROM public.engineer_safety_incidents_r2338 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_id
  ORDER BY i.occurred_at DESC;
END;
$$;

-- RPC 2: log_incident
CREATE OR REPLACE FUNCTION public.log_incident_r2338(
  p_engineer_id uuid,
  p_incident_type text,
  p_occurred_at timestamptz,
  p_site_location text,
  p_job_id uuid,
  p_severity text,
  p_description_md text,
  p_immediate_action_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_safety_incidents_r2338 (engineer_id, incident_type, occurred_at, site_location, job_id, severity, description_md, immediate_action_md)
  VALUES (p_engineer_id, p_incident_type, COALESCE(p_occurred_at, now()), COALESCE(p_site_location,''), p_job_id, COALESCE(p_severity,'minor'), COALESCE(p_description_md,''), COALESCE(p_immediate_action_md,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_incident_r2338', jsonb_build_object('incident_id', v_id, 'engineer_id', p_engineer_id, 'type', p_incident_type, 'severity', p_severity));
  RETURN v_id;
END;
$$;

-- RPC 3: list_mitigations
CREATE OR REPLACE FUNCTION public.list_mitigations_r2338(p_incident_id uuid)
RETURNS TABLE (
  id uuid,
  incident_id uuid,
  mitigation_text text,
  category text,
  owner_user_id uuid,
  owner_email text,
  target_date date,
  applied_at timestamptz,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.incident_id, m.mitigation_text, m.category, m.owner_user_id, p.email, m.target_date, m.applied_at, m.status
  FROM public.engineer_safety_mitigations_r2338 m
  LEFT JOIN public.profiles p ON p.id = m.owner_user_id
  WHERE m.incident_id = p_incident_id
  ORDER BY COALESCE(m.target_date, '9999-12-31'::date) ASC;
END;
$$;

-- RPC 4: add_mitigation
CREATE OR REPLACE FUNCTION public.add_mitigation_r2338(
  p_incident_id uuid,
  p_mitigation_text text,
  p_category text,
  p_owner_user_id uuid,
  p_target_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_safety_mitigations_r2338 (incident_id, mitigation_text, category, owner_user_id, target_date)
  VALUES (p_incident_id, p_mitigation_text, COALESCE(p_category,'process'), p_owner_user_id, p_target_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_mitigation_r2338', jsonb_build_object('mitigation_id', v_id, 'incident_id', p_incident_id, 'category', p_category));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_mitigation_applied
CREATE OR REPLACE FUNCTION public.mark_mitigation_applied_r2338(p_mitigation_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_safety_mitigations_r2338
  SET status='applied', applied_at=now(), updated_at=now()
  WHERE id = p_mitigation_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_mitigation_applied_r2338', jsonb_build_object('mitigation_id', p_mitigation_id));
END;
$$;

-- RPC 6: incident_type_breakdown
CREATE OR REPLACE FUNCTION public.incident_type_breakdown_r2338()
RETURNS TABLE (
  incident_type text,
  total_count int,
  open_count int,
  closed_count int,
  serious_or_critical_count int,
  last_occurred timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.incident_type,
    (COUNT(*))::int AS total_count,
    (COUNT(*) FILTER (WHERE i.status IN ('open','under_rca')))::int AS open_count,
    (COUNT(*) FILTER (WHERE i.status = 'closed'))::int AS closed_count,
    (COUNT(*) FILTER (WHERE i.severity IN ('serious','critical')))::int AS serious_or_critical_count,
    MAX(i.occurred_at) AS last_occurred
  FROM public.engineer_safety_incidents_r2338 i
  GROUP BY i.incident_type
  ORDER BY total_count DESC;
END;
$$;

-- RPC 7: open_rca_queue
CREATE OR REPLACE FUNCTION public.open_rca_queue_r2338()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  incident_type text,
  occurred_at timestamptz,
  severity text,
  status text,
  days_open int,
  pending_mitigations int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, p.email, i.incident_type, i.occurred_at, i.severity, i.status,
    GREATEST(0, (CURRENT_DATE - i.occurred_at::date))::int AS days_open,
    (SELECT (COUNT(*))::int FROM public.engineer_safety_mitigations_r2338 m WHERE m.incident_id = i.id AND m.status IN ('planned','in_progress')) AS pending_mitigations
  FROM public.engineer_safety_incidents_r2338 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_id
  WHERE i.status IN ('open','under_rca')
  ORDER BY (CASE i.severity WHEN 'critical' THEN 1 WHEN 'serious' THEN 2 WHEN 'moderate' THEN 3 WHEN 'minor' THEN 4 ELSE 5 END), i.occurred_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_incidents_r2338() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_incident_r2338(uuid, text, timestamptz, text, uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_mitigations_r2338(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_mitigation_r2338(uuid, text, text, uuid, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_mitigation_applied_r2338(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.incident_type_breakdown_r2338() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_rca_queue_r2338() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_incidents_r2338() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_incident_r2338(uuid, text, timestamptz, text, uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_mitigations_r2338(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_mitigation_r2338(uuid, text, text, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_mitigation_applied_r2338(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.incident_type_breakdown_r2338() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_rca_queue_r2338() TO authenticated;

COMMIT;
