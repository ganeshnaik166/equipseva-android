BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_safety_incidents_r1684 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  hospital_id uuid REFERENCES public.organizations(id),
  incident_type text NOT NULL CHECK (incident_type IN ('injury','near_miss','exposure','equipment_strike')),
  severity text NOT NULL CHECK (severity IN ('minor','moderate','severe','fatal')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  description_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_safety_rca_actions_r1684 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.engineer_safety_incidents_r1684(id) ON DELETE CASCADE,
  root_cause text NOT NULL DEFAULT '',
  corrective_action text NOT NULL DEFAULT '',
  owner_email text NOT NULL DEFAULT '',
  due_date date,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.engineer_safety_incidents_r1684 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_safety_rca_actions_r1684 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_incidents_r1684_founder ON public.engineer_safety_incidents_r1684;
CREATE POLICY p_incidents_r1684_founder ON public.engineer_safety_incidents_r1684
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_rca_r1684_founder ON public.engineer_safety_rca_actions_r1684;
CREATE POLICY p_rca_r1684_founder ON public.engineer_safety_rca_actions_r1684
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_incidents
CREATE OR REPLACE FUNCTION public.list_incidents_r1684()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  incident_type text,
  severity text,
  occurred_at timestamptz,
  description_md text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.engineer_user_id, p.email::text, i.hospital_id, o.name::text,
           i.incident_type, i.severity, i.occurred_at, i.description_md, i.status, i.created_at
      FROM public.engineer_safety_incidents_r1684 i
      LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
      LEFT JOIN public.organizations o ON o.id = i.hospital_id
     ORDER BY i.occurred_at DESC
     LIMIT 500;
END;
$$;

-- RPC 2: log_incident
CREATE OR REPLACE FUNCTION public.log_incident_r1684(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_incident_type text,
  p_severity text,
  p_occurred_at timestamptz,
  p_description_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_safety_incidents_r1684(engineer_user_id, hospital_id, incident_type, severity, occurred_at, description_md)
  VALUES (p_engineer_user_id, p_hospital_id, p_incident_type, p_severity, COALESCE(p_occurred_at, now()), COALESCE(p_description_md,''))
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1684_log_incident',
          jsonb_build_object('incident_id', v_id, 'engineer_user_id', p_engineer_user_id, 'severity', p_severity, 'type', p_incident_type));
  RETURN v_id;
END;
$$;

-- RPC 3: list_rca
CREATE OR REPLACE FUNCTION public.list_rca_r1684(p_incident_id uuid)
RETURNS TABLE(
  id uuid,
  incident_id uuid,
  root_cause text,
  corrective_action text,
  owner_email text,
  due_date date,
  completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.incident_id, a.root_cause, a.corrective_action, a.owner_email, a.due_date, a.completed_at, a.created_at
      FROM public.engineer_safety_rca_actions_r1684 a
     WHERE a.incident_id = p_incident_id
     ORDER BY a.created_at DESC;
END;
$$;

-- RPC 4: add_rca_action
CREATE OR REPLACE FUNCTION public.add_rca_action_r1684(
  p_incident_id uuid,
  p_root_cause text,
  p_corrective_action text,
  p_owner_email text,
  p_due_date date
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_safety_rca_actions_r1684(incident_id, root_cause, corrective_action, owner_email, due_date)
  VALUES (p_incident_id, COALESCE(p_root_cause,''), COALESCE(p_corrective_action,''), COALESCE(p_owner_email,''), p_due_date)
  RETURNING id INTO v_id;
  UPDATE public.engineer_safety_incidents_r1684 SET status='investigating', updated_at=now()
    WHERE id = p_incident_id AND status='open';
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1684_add_rca_action',
          jsonb_build_object('action_id', v_id, 'incident_id', p_incident_id, 'owner_email', p_owner_email));
  RETURN v_id;
END;
$$;

-- RPC 5: complete_rca
CREATE OR REPLACE FUNCTION public.complete_rca_r1684(p_action_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_incident uuid; v_open int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_safety_rca_actions_r1684
     SET completed_at = now(), updated_at = now()
   WHERE id = p_action_id
   RETURNING incident_id INTO v_incident;
  SELECT COUNT(*) INTO v_open FROM public.engineer_safety_rca_actions_r1684
   WHERE incident_id = v_incident AND completed_at IS NULL;
  IF v_open = 0 AND v_incident IS NOT NULL THEN
    UPDATE public.engineer_safety_incidents_r1684 SET status='closed', updated_at=now() WHERE id = v_incident;
  END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1684_complete_rca',
          jsonb_build_object('action_id', p_action_id, 'incident_id', v_incident));
END;
$$;

-- RPC 6: severity_distribution
CREATE OR REPLACE FUNCTION public.severity_distribution_r1684()
RETURNS TABLE(severity text, cnt int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.severity, COUNT(*)::int
      FROM public.engineer_safety_incidents_r1684 i
     GROUP BY i.severity
     ORDER BY i.severity;
END;
$$;

-- RPC 7: open_incidents_top_n
CREATE OR REPLACE FUNCTION public.open_incidents_top_n_r1684(p_limit int)
RETURNS TABLE(
  id uuid,
  engineer_email text,
  hospital_name text,
  incident_type text,
  severity text,
  occurred_at timestamptz,
  status text,
  open_actions int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id,
           p.email::text,
           o.name::text,
           i.incident_type,
           i.severity,
           i.occurred_at,
           i.status,
           (SELECT (COUNT(*) FILTER (WHERE a.completed_at IS NULL))::int
              FROM public.engineer_safety_rca_actions_r1684 a WHERE a.incident_id = i.id) AS open_rca_count
      FROM public.engineer_safety_incidents_r1684 i
      LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
      LEFT JOIN public.organizations o ON o.id = i.hospital_id
     WHERE i.status IN ('open','investigating')
     ORDER BY
       CASE i.severity WHEN 'fatal' THEN 0 WHEN 'severe' THEN 1 WHEN 'moderate' THEN 2 ELSE 3 END,
       i.occurred_at DESC
     LIMIT COALESCE(p_limit, 25);
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_incidents_r1684() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_incident_r1684(uuid, uuid, text, text, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_rca_r1684(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_rca_action_r1684(uuid, text, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_rca_r1684(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.severity_distribution_r1684() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_incidents_top_n_r1684(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_incidents_r1684() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_incident_r1684(uuid, uuid, text, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_rca_r1684(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_rca_action_r1684(uuid, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_rca_r1684(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.severity_distribution_r1684() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_incidents_top_n_r1684(int) TO authenticated;

COMMIT;