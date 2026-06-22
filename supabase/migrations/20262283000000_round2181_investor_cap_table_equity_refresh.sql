BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_equity_refresh_r2181 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_label text NOT NULL,
  refresh_event_label text NOT NULL,
  refresh_shares bigint NOT NULL DEFAULT 0,
  refresh_date date,
  vesting_start_date date,
  status text NOT NULL DEFAULT 'granted' CHECK (status IN ('granted','vesting','cliffed','superseded','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_equity_refresh_action_log_r2181 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  refresh_id uuid NOT NULL REFERENCES public.investor_cap_table_equity_refresh_r2181(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','vested','escalated','superseded','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_change bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_equity_refresh_r2181 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_equity_refresh_action_log_r2181 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2181_refresh ON public.investor_cap_table_equity_refresh_r2181;
CREATE POLICY founder_all_r2181_refresh ON public.investor_cap_table_equity_refresh_r2181
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2181_actions ON public.investor_equity_refresh_action_log_r2181;
CREATE POLICY founder_all_r2181_actions ON public.investor_equity_refresh_action_log_r2181
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_refreshes
DROP FUNCTION IF EXISTS public.list_refreshes_r2181();
CREATE OR REPLACE FUNCTION public.list_refreshes_r2181()
RETURNS TABLE (
  id uuid,
  recipient_label text,
  refresh_event_label text,
  refresh_shares bigint,
  refresh_date date,
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
  SELECT r.id, r.recipient_label, r.refresh_event_label, r.refresh_shares, r.refresh_date, r.vesting_start_date, r.status, r.captured_at
  FROM public.investor_cap_table_equity_refresh_r2181 r
  ORDER BY r.captured_at DESC
  LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_refreshes_r2181() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_refreshes_r2181() TO authenticated;

-- 2. log_refresh
DROP FUNCTION IF EXISTS public.log_refresh_r2181(text, text, bigint, date, date, text);
CREATE OR REPLACE FUNCTION public.log_refresh_r2181(
  p_recipient_label text,
  p_refresh_event_label text,
  p_refresh_shares bigint,
  p_refresh_date date,
  p_vesting_start_date date,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_equity_refresh_r2181 (recipient_label, refresh_event_label, refresh_shares, refresh_date, vesting_start_date, status)
  VALUES (p_recipient_label, p_refresh_event_label, p_refresh_shares, p_refresh_date, p_vesting_start_date, COALESCE(p_status,'granted'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_refresh_r2181', jsonb_build_object('id', v_id, 'recipient', p_recipient_label, 'shares', p_refresh_shares), now());

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_refresh_r2181(text, text, bigint, date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_refresh_r2181(text, text, bigint, date, date, text) TO authenticated;

-- 3. list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2181(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2181(p_refresh_id uuid)
RETURNS TABLE (
  id uuid,
  refresh_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_change bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.refresh_id, a.action_type, a.taken_at, a.by_email, a.shares_change, a.notes_md
  FROM public.investor_equity_refresh_action_log_r2181 a
  WHERE a.refresh_id = p_refresh_id
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2181(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2181(uuid) TO authenticated;

-- 4. log_action
DROP FUNCTION IF EXISTS public.log_action_r2181(uuid, text, text, bigint, text);
CREATE OR REPLACE FUNCTION public.log_action_r2181(
  p_refresh_id uuid,
  p_action_type text,
  p_by_email text,
  p_shares_change bigint,
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
  INSERT INTO public.investor_equity_refresh_action_log_r2181 (refresh_id, action_type, by_email, shares_change, notes_md)
  VALUES (p_refresh_id, p_action_type, p_by_email, COALESCE(p_shares_change,0), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2181', jsonb_build_object('id', v_id, 'refresh_id', p_refresh_id, 'action_type', p_action_type), now());

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2181(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2181(uuid, text, text, bigint, text) TO authenticated;

-- 5. mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2181(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2181(p_refresh_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_equity_refresh_r2181
  SET status = p_status, updated_at = now()
  WHERE id = p_refresh_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2181', jsonb_build_object('refresh_id', p_refresh_id, 'status', p_status), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2181(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2181(uuid, text) TO authenticated;

-- 6. recent_refreshes
DROP FUNCTION IF EXISTS public.recent_refreshes_r2181(int);
CREATE OR REPLACE FUNCTION public.recent_refreshes_r2181(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  recipient_label text,
  refresh_event_label text,
  refresh_shares bigint,
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
  SELECT r.id, r.recipient_label, r.refresh_event_label, r.refresh_shares, r.status, r.captured_at
  FROM public.investor_cap_table_equity_refresh_r2181 r
  ORDER BY r.captured_at DESC
  LIMIT GREATEST(COALESCE(p_limit,20), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_refreshes_r2181(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_refreshes_r2181(int) TO authenticated;

-- 7. recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2181(int);
CREATE OR REPLACE FUNCTION public.recent_actions_r2181(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  refresh_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_change bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.refresh_id, a.action_type, a.taken_at, a.by_email, a.shares_change
  FROM public.investor_equity_refresh_action_log_r2181 a
  ORDER BY a.taken_at DESC
  LIMIT GREATEST(COALESCE(p_limit,20), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2181(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2181(int) TO authenticated;

COMMIT;
