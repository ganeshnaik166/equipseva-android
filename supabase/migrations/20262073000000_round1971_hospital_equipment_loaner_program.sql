BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_equipment_loaners_r1971 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  loan_value_rupees bigint NOT NULL DEFAULT 0,
  loan_start_date date NOT NULL,
  loan_end_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','returned','extended','written_off','converted_to_sale')),
  signed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_loaner_action_log_r1971 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loaner_id uuid NOT NULL REFERENCES public.hospital_equipment_loaners_r1971(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('issued','extended','inspected','returned','written_off','converted_to_sale')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  condition_md text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_equipment_loaners_r1971 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_loaner_action_log_r1971 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_loaners_r1971 ON public.hospital_equipment_loaners_r1971;
CREATE POLICY founder_all_loaners_r1971 ON public.hospital_equipment_loaners_r1971
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_loaner_log_r1971 ON public.hospital_loaner_action_log_r1971;
CREATE POLICY founder_all_loaner_log_r1971 ON public.hospital_loaner_action_log_r1971
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_loaners
CREATE OR REPLACE FUNCTION public.list_loaners_r1971()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, equipment_name text, loan_value_rupees bigint, loan_start_date date, loan_end_date date, status text, signed_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.hospital_id, o.name, l.equipment_name, l.loan_value_rupees, l.loan_start_date, l.loan_end_date, l.status, l.signed_at, l.created_at
  FROM public.hospital_equipment_loaners_r1971 l
  LEFT JOIN public.organizations o ON o.id = l.hospital_id
  ORDER BY l.created_at DESC
  LIMIT 200;
END $$;

-- RPC 2: log_loaner
CREATE OR REPLACE FUNCTION public.log_loaner_r1971(p_hospital_id uuid, p_equipment_name text, p_loan_value_rupees bigint, p_loan_start_date date, p_loan_end_date date, p_signed_at timestamptz)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_equipment_loaners_r1971(hospital_id, equipment_name, loan_value_rupees, loan_start_date, loan_end_date, signed_at)
  VALUES (p_hospital_id, p_equipment_name, p_loan_value_rupees, p_loan_start_date, p_loan_end_date, p_signed_at)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_loaner_r1971', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'equipment_name', p_equipment_name));
  RETURN v_id;
END $$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1971(p_loaner_id uuid)
RETURNS TABLE(id uuid, loaner_id uuid, action_type text, taken_at timestamptz, by_email text, condition_md text, notes_md text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.loaner_id, a.action_type, a.taken_at, a.by_email, a.condition_md, a.notes_md, a.created_at
  FROM public.hospital_loaner_action_log_r1971 a
  WHERE a.loaner_id = p_loaner_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END $$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r1971(p_loaner_id uuid, p_action_type text, p_by_email text, p_condition_md text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_loaner_action_log_r1971(loaner_id, action_type, by_email, condition_md, notes_md)
  VALUES (p_loaner_id, p_action_type, p_by_email, p_condition_md, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1971', jsonb_build_object('id', v_id, 'loaner_id', p_loaner_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1971(p_loaner_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_loaners_r1971 SET status = p_status, updated_at = now() WHERE id = p_loaner_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1971', jsonb_build_object('id', p_loaner_id, 'status', p_status));
END $$;

-- RPC 6: active_loaners_by_hospital
CREATE OR REPLACE FUNCTION public.active_loaners_by_hospital_r1971()
RETURNS TABLE(hospital_id uuid, hospital_name text, active_count bigint, total_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.hospital_id, o.name, COUNT(*)::bigint, COALESCE(SUM(l.loan_value_rupees),0)::bigint
  FROM public.hospital_equipment_loaners_r1971 l
  LEFT JOIN public.organizations o ON o.id = l.hospital_id
  WHERE l.status = 'active'
  GROUP BY l.hospital_id, o.name
  ORDER BY COUNT(*) DESC
  LIMIT 100;
END $$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r1971()
RETURNS TABLE(id uuid, loaner_id uuid, equipment_name text, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.loaner_id, l.equipment_name, a.action_type, a.taken_at, a.by_email
  FROM public.hospital_loaner_action_log_r1971 a
  LEFT JOIN public.hospital_equipment_loaners_r1971 l ON l.id = a.loaner_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_loaners_r1971() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_loaner_r1971(uuid, text, bigint, date, date, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1971(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1971(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1971(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_loaners_by_hospital_r1971() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1971() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_loaners_r1971() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_loaner_r1971(uuid, text, bigint, date, date, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1971(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1971(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1971(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_loaners_by_hospital_r1971() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1971() TO authenticated;

COMMIT;
