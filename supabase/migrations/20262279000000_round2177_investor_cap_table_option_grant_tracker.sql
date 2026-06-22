BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_option_grant_r2177 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grantee_label text NOT NULL,
  grant_type text NOT NULL CHECK (grant_type IN ('ISO','NSO','RSU','RSA')),
  total_options bigint NOT NULL,
  exercise_price_rupees numeric(14,2) NOT NULL DEFAULT 0,
  vesting_start_date date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exercised','forfeited','expired')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_option_grant_action_log_r2177 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grant_id uuid NOT NULL REFERENCES public.investor_cap_table_option_grant_r2177(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','vested','exercised','forfeited','expired')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  options_change bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_option_grant_r2177 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_option_grant_action_log_r2177 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_grants_r2177 ON public.investor_cap_table_option_grant_r2177;
CREATE POLICY founder_all_grants_r2177 ON public.investor_cap_table_option_grant_r2177
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2177 ON public.investor_option_grant_action_log_r2177;
CREATE POLICY founder_all_actions_r2177 ON public.investor_option_grant_action_log_r2177
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_grants
DROP FUNCTION IF EXISTS public.list_grants_r2177();
CREATE OR REPLACE FUNCTION public.list_grants_r2177()
RETURNS TABLE (
  id uuid,
  grantee_label text,
  grant_type text,
  total_options bigint,
  exercise_price_rupees numeric,
  vesting_start_date date,
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
  SELECT g.id, g.grantee_label, g.grant_type, g.total_options, g.exercise_price_rupees,
         g.vesting_start_date, g.status, g.captured_at
  FROM public.investor_cap_table_option_grant_r2177 g
  ORDER BY g.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_grants_r2177() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_grants_r2177() TO authenticated;

-- 2. log_grant
DROP FUNCTION IF EXISTS public.log_grant_r2177(text, text, bigint, numeric, date);
CREATE OR REPLACE FUNCTION public.log_grant_r2177(
  p_grantee_label text,
  p_grant_type text,
  p_total_options bigint,
  p_exercise_price_rupees numeric,
  p_vesting_start_date date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_option_grant_r2177(
    grantee_label, grant_type, total_options, exercise_price_rupees, vesting_start_date
  ) VALUES (p_grantee_label, p_grant_type, p_total_options, p_exercise_price_rupees, p_vesting_start_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'log_grant_r2177',
          jsonb_build_object('grant_id', v_id, 'grantee', p_grantee_label, 'type', p_grant_type, 'options', p_total_options));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_grant_r2177(text, text, bigint, numeric, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_grant_r2177(text, text, bigint, numeric, date) TO authenticated;

-- 3. list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2177(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2177(p_grant_id uuid)
RETURNS TABLE (
  id uuid,
  grant_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  options_change bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.grant_id, a.action_type, a.taken_at, a.by_email, a.options_change, a.notes_md
  FROM public.investor_option_grant_action_log_r2177 a
  WHERE a.grant_id = p_grant_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2177(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2177(uuid) TO authenticated;

-- 4. log_action
DROP FUNCTION IF EXISTS public.log_action_r2177(uuid, text, text, bigint, text);
CREATE OR REPLACE FUNCTION public.log_action_r2177(
  p_grant_id uuid,
  p_action_type text,
  p_by_email text,
  p_options_change bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_option_grant_action_log_r2177(
    grant_id, action_type, by_email, options_change, notes_md
  ) VALUES (p_grant_id, p_action_type, p_by_email, p_options_change, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'log_action_r2177',
          jsonb_build_object('action_id', v_id, 'grant_id', p_grant_id, 'action', p_action_type, 'change', p_options_change));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2177(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2177(uuid, text, text, bigint, text) TO authenticated;

-- 5. mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2177(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2177(p_grant_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_option_grant_r2177
  SET status = p_status, updated_at = now()
  WHERE id = p_grant_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'mark_status_r2177',
          jsonb_build_object('grant_id', p_grant_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2177(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2177(uuid, text) TO authenticated;

-- 6. active_grants
DROP FUNCTION IF EXISTS public.active_grants_r2177();
CREATE OR REPLACE FUNCTION public.active_grants_r2177()
RETURNS TABLE (
  id uuid,
  grantee_label text,
  grant_type text,
  total_options bigint,
  exercise_price_rupees numeric,
  vesting_start_date date,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.grantee_label, g.grant_type, g.total_options, g.exercise_price_rupees,
         g.vesting_start_date, g.captured_at
  FROM public.investor_cap_table_option_grant_r2177 g
  WHERE g.status = 'active'
  ORDER BY g.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.active_grants_r2177() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_grants_r2177() TO authenticated;

-- 7. recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2177();
CREATE OR REPLACE FUNCTION public.recent_actions_r2177()
RETURNS TABLE (
  id uuid,
  grant_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  options_change bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.grant_id, a.action_type, a.taken_at, a.by_email, a.options_change, a.notes_md
  FROM public.investor_option_grant_action_log_r2177 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2177() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2177() TO authenticated;

COMMIT;
