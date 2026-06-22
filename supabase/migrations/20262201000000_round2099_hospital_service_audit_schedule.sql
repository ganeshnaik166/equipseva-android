BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_service_audit_schedule_r2099 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  audit_type text NOT NULL CHECK (audit_type IN ('operational','financial','quality','safety','regulatory','customer_satisfaction')),
  scheduled_date date NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','escalated')),
  completed_at timestamptz,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_audit_action_log_r2099 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.hospital_service_audit_schedule_r2099(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('started','findings_logged','escalation','closed','superseded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsas_r2099_hospital ON public.hospital_service_audit_schedule_r2099(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hsas_r2099_status ON public.hospital_service_audit_schedule_r2099(status);
CREATE INDEX IF NOT EXISTS idx_hsas_r2099_scheduled ON public.hospital_service_audit_schedule_r2099(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_haal_r2099_schedule ON public.hospital_audit_action_log_r2099(schedule_id);
CREATE INDEX IF NOT EXISTS idx_haal_r2099_taken ON public.hospital_audit_action_log_r2099(taken_at);

-- RLS
ALTER TABLE public.hospital_service_audit_schedule_r2099 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_audit_action_log_r2099 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsas_r2099_founder_all ON public.hospital_service_audit_schedule_r2099;
CREATE POLICY hsas_r2099_founder_all ON public.hospital_service_audit_schedule_r2099
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS haal_r2099_founder_all ON public.hospital_audit_action_log_r2099;
CREATE POLICY haal_r2099_founder_all ON public.hospital_audit_action_log_r2099
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_audits
CREATE OR REPLACE FUNCTION public.list_audits_r2099()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, audit_type text, scheduled_date date, status text, completed_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.hospital_id,
           COALESCE(o.name, p.email, s.hospital_id::text) AS hospital_name,
           s.audit_type, s.scheduled_date, s.status, s.completed_at, s.created_at
    FROM public.hospital_service_audit_schedule_r2099 s
    LEFT JOIN public.profiles p ON p.id = s.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY s.scheduled_date DESC, s.created_at DESC
    LIMIT 500;
END;
$$;

-- RPC 2: log_audit
CREATE OR REPLACE FUNCTION public.log_audit_r2099(p_hospital_id uuid, p_audit_type text, p_scheduled_date date, p_notes text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_audit_schedule_r2099(hospital_id, audit_type, scheduled_date, notes_md)
    VALUES (p_hospital_id, p_audit_type, p_scheduled_date, p_notes)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_audit_r2099',
            jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'audit_type', p_audit_type, 'scheduled_date', p_scheduled_date));
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2099(p_schedule_id uuid)
RETURNS TABLE(id uuid, schedule_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.schedule_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_audit_action_log_r2099 a
    WHERE a.schedule_id = p_schedule_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r2099(p_schedule_id uuid, p_action_type text, p_notes text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_audit_action_log_r2099(schedule_id, action_type, by_email, notes_md)
    VALUES (p_schedule_id, p_action_type, (auth.jwt()->>'email'), p_notes)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2099',
            jsonb_build_object('id', v_id, 'schedule_id', p_schedule_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2099(p_schedule_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_audit_schedule_r2099
    SET status = p_status,
        completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
        updated_at = now()
    WHERE id = p_schedule_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2099',
            jsonb_build_object('id', p_schedule_id, 'status', p_status));
END;
$$;

-- RPC 6: upcoming
CREATE OR REPLACE FUNCTION public.upcoming_r2099()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, audit_type text, scheduled_date date, status text, days_until int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.hospital_id,
           COALESCE(o.name, p.email, s.hospital_id::text) AS hospital_name,
           s.audit_type, s.scheduled_date, s.status,
           (s.scheduled_date - CURRENT_DATE)::int AS days_until
    FROM public.hospital_service_audit_schedule_r2099 s
    LEFT JOIN public.profiles p ON p.id = s.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    WHERE s.status IN ('planned','in_progress')
      AND s.scheduled_date >= CURRENT_DATE
    ORDER BY s.scheduled_date ASC
    LIMIT 200;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2099()
RETURNS TABLE(id uuid, schedule_id uuid, action_type text, taken_at timestamptz, by_email text, audit_type text, hospital_name text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.schedule_id, a.action_type, a.taken_at, a.by_email,
           s.audit_type,
           COALESCE(o.name, p.email, s.hospital_id::text) AS hospital_name
    FROM public.hospital_audit_action_log_r2099 a
    JOIN public.hospital_service_audit_schedule_r2099 s ON s.id = a.schedule_id
    LEFT JOIN public.profiles p ON p.id = s.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_audits_r2099() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_audit_r2099(uuid, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2099(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2099(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2099(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_r2099() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2099() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audits_r2099() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_audit_r2099(uuid, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2099(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2099(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2099(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_r2099() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2099() TO authenticated;

COMMIT;
