BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_energy_audits_r1942 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  total_hours int NOT NULL DEFAULT 0,
  deep_work_hours int NOT NULL DEFAULT 0,
  meetings_hours int NOT NULL DEFAULT 0,
  ops_hours int NOT NULL DEFAULT 0,
  sales_hours int NOT NULL DEFAULT 0,
  recovery_hours int NOT NULL DEFAULT 0,
  energy_level int NOT NULL DEFAULT 5 CHECK (energy_level BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','locked','archived')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_energy_followup_log_r1942 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.founder_energy_audits_r1942(id) ON DELETE CASCADE,
  followup_type text NOT NULL CHECK (followup_type IN ('delegation_action','calendar_block','meeting_kill','recovery_plan','personal_decision')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_energy_audits_r1942 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_energy_followup_log_r1942 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_audits_r1942 ON public.founder_energy_audits_r1942;
CREATE POLICY founder_all_audits_r1942 ON public.founder_energy_audits_r1942
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_followup_r1942 ON public.founder_energy_followup_log_r1942;
CREATE POLICY founder_all_followup_r1942 ON public.founder_energy_followup_log_r1942
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_audits_r1942()
RETURNS TABLE (
  id uuid,
  week_start date,
  total_hours int,
  deep_work_hours int,
  meetings_hours int,
  ops_hours int,
  sales_hours int,
  recovery_hours int,
  energy_level int,
  status text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.week_start, a.total_hours, a.deep_work_hours, a.meetings_hours,
         a.ops_hours, a.sales_hours, a.recovery_hours, a.energy_level, a.status, a.recorded_at
  FROM public.founder_energy_audits_r1942 a
  ORDER BY a.week_start DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_audit_r1942(
  p_week_start date,
  p_total_hours int,
  p_deep_work_hours int,
  p_meetings_hours int,
  p_ops_hours int,
  p_sales_hours int,
  p_recovery_hours int,
  p_energy_level int
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
  INSERT INTO public.founder_energy_audits_r1942(
    week_start, total_hours, deep_work_hours, meetings_hours, ops_hours,
    sales_hours, recovery_hours, energy_level
  ) VALUES (
    p_week_start, p_total_hours, p_deep_work_hours, p_meetings_hours, p_ops_hours,
    p_sales_hours, p_recovery_hours, p_energy_level
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1942.log_audit',
    jsonb_build_object('id', v_id, 'week_start', p_week_start, 'energy', p_energy_level));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_followups_r1942(p_audit_id uuid)
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  followup_type text,
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
  SELECT f.id, f.audit_id, f.followup_type, f.taken_at, f.by_email, f.notes_md
  FROM public.founder_energy_followup_log_r1942 f
  WHERE f.audit_id = p_audit_id
  ORDER BY f.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_followup_r1942(
  p_audit_id uuid,
  p_followup_type text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_energy_followup_log_r1942(audit_id, followup_type, by_email, notes_md)
  VALUES (p_audit_id, p_followup_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'r1942.log_followup',
    jsonb_build_object('id', v_id, 'audit_id', p_audit_id, 'type', p_followup_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1942(p_audit_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('draft','locked','archived') THEN
    RAISE EXCEPTION 'bad_status';
  END IF;
  UPDATE public.founder_energy_audits_r1942
    SET status = p_status, updated_at = now()
    WHERE id = p_audit_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1942.mark_status',
    jsonb_build_object('id', p_audit_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.energy_trend_r1942()
RETURNS TABLE (
  week_start date,
  energy_level int,
  total_hours int,
  deep_work_hours int,
  meetings_hours int,
  recovery_hours int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.week_start, a.energy_level, a.total_hours, a.deep_work_hours,
         a.meetings_hours, a.recovery_hours
  FROM public.founder_energy_audits_r1942 a
  ORDER BY a.week_start DESC
  LIMIT 26;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_followups_r1942()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  week_start date,
  followup_type text,
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
  SELECT f.id, f.audit_id, a.week_start, f.followup_type, f.taken_at, f.by_email, f.notes_md
  FROM public.founder_energy_followup_log_r1942 f
  JOIN public.founder_energy_audits_r1942 a ON a.id = f.audit_id
  ORDER BY f.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_audits_r1942() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_audit_r1942(date,int,int,int,int,int,int,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_followups_r1942(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_followup_r1942(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1942(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.energy_trend_r1942() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_followups_r1942() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audits_r1942() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_audit_r1942(date,int,int,int,int,int,int,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_followups_r1942(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_followup_r1942(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1942(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.energy_trend_r1942() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_followups_r1942() TO authenticated;

COMMIT;
