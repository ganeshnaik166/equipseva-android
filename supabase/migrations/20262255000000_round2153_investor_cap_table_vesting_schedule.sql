BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_vesting_schedule_r2153 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_label text NOT NULL,
  total_shares bigint NOT NULL DEFAULT 0,
  vested_shares bigint NOT NULL DEFAULT 0,
  vesting_start_date date,
  vesting_end_date date,
  cliff_months int NOT NULL DEFAULT 12,
  status text NOT NULL DEFAULT 'vesting' CHECK (status IN ('vesting','fully_vested','terminated','accelerated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_vesting_action_log_r2153 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.investor_cap_table_vesting_schedule_r2153(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','vested','accelerated','terminated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_vested bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_vesting_schedule_r2153 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_vesting_action_log_r2153 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_schedule_r2153 ON public.investor_cap_table_vesting_schedule_r2153;
CREATE POLICY founder_all_schedule_r2153 ON public.investor_cap_table_vesting_schedule_r2153
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2153 ON public.investor_vesting_action_log_r2153;
CREATE POLICY founder_all_action_r2153 ON public.investor_vesting_action_log_r2153
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_vesting_schedules_r2153()
RETURNS SETOF public.investor_cap_table_vesting_schedule_r2153
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_vesting_schedule_r2153 ORDER BY captured_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_vesting_schedule_r2153(
  p_recipient_label text,
  p_total_shares bigint,
  p_vested_shares bigint,
  p_vesting_start_date date,
  p_vesting_end_date date,
  p_cliff_months int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_vesting_schedule_r2153(recipient_label,total_shares,vested_shares,vesting_start_date,vesting_end_date,cliff_months,status)
  VALUES (p_recipient_label,p_total_shares,p_vested_shares,p_vesting_start_date,p_vesting_end_date,COALESCE(p_cliff_months,12),COALESCE(p_status,'vesting'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_vesting_schedule_r2153', jsonb_build_object('schedule_id', v_id, 'recipient', p_recipient_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_vesting_actions_r2153(p_schedule_id uuid)
RETURNS SETOF public.investor_vesting_action_log_r2153
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_vesting_action_log_r2153 WHERE schedule_id = p_schedule_id ORDER BY taken_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_vesting_action_r2153(
  p_schedule_id uuid,
  p_action_type text,
  p_by_email text,
  p_shares_vested bigint,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_vesting_action_log_r2153(schedule_id,action_type,by_email,shares_vested,notes_md)
  VALUES (p_schedule_id,p_action_type,p_by_email,COALESCE(p_shares_vested,0),p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_vesting_action_r2153', jsonb_build_object('action_id', v_id, 'schedule_id', p_schedule_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_vesting_status_r2153(p_schedule_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_vesting_schedule_r2153 SET status = p_status, updated_at = now() WHERE id = p_schedule_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_vesting_status_r2153', jsonb_build_object('schedule_id', p_schedule_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.list_fully_vested_r2153()
RETURNS SETOF public.investor_cap_table_vesting_schedule_r2153
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_vesting_schedule_r2153 WHERE status = 'fully_vested' ORDER BY captured_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_recent_vesting_actions_r2153()
RETURNS SETOF public.investor_vesting_action_log_r2153
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_vesting_action_log_r2153 ORDER BY taken_at DESC LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_vesting_schedules_r2153() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_vesting_schedule_r2153(text,bigint,bigint,date,date,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_vesting_actions_r2153(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_vesting_action_r2153(uuid,text,text,bigint,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_vesting_status_r2153(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_fully_vested_r2153() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_recent_vesting_actions_r2153() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_vesting_schedules_r2153() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_vesting_schedule_r2153(text,bigint,bigint,date,date,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_vesting_actions_r2153(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_vesting_action_r2153(uuid,text,text,bigint,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_vesting_status_r2153(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_fully_vested_r2153() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_recent_vesting_actions_r2153() TO authenticated;

COMMIT;
