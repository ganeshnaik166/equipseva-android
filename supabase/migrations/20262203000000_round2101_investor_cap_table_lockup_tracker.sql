BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_lockup_r2101 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  lockup_label text NOT NULL,
  locked_shares_count bigint NOT NULL DEFAULT 0,
  lockup_starts_at date,
  lockup_ends_at date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','extended','released_early','disputed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_lockup_action_log_r2101 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lockup_id uuid NOT NULL REFERENCES public.investor_cap_table_lockup_r2101(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('locked','extended','released','released_early','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_released bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_lockup_r2101 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_lockup_action_log_r2101 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_lockup_r2101 ON public.investor_cap_table_lockup_r2101;
CREATE POLICY founder_all_lockup_r2101 ON public.investor_cap_table_lockup_r2101
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_lockup_action_r2101 ON public.investor_lockup_action_log_r2101;
CREATE POLICY founder_all_lockup_action_r2101 ON public.investor_lockup_action_log_r2101
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_lockups_r2101()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  lockup_label text,
  locked_shares_count bigint,
  lockup_starts_at date,
  lockup_ends_at date,
  status text,
  captured_at timestamptz
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
    SELECT l.id, l.investor_id, l.lockup_label, l.locked_shares_count,
           l.lockup_starts_at, l.lockup_ends_at, l.status, l.captured_at
    FROM public.investor_cap_table_lockup_r2101 l
    ORDER BY l.lockup_ends_at NULLS LAST, l.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_lockup_r2101(
  p_investor_id uuid,
  p_lockup_label text,
  p_locked_shares bigint,
  p_lockup_starts_at date,
  p_lockup_ends_at date
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
  INSERT INTO public.investor_cap_table_lockup_r2101 (
    investor_id, lockup_label, locked_shares_count, lockup_starts_at, lockup_ends_at, status
  ) VALUES (
    p_investor_id, p_lockup_label, COALESCE(p_locked_shares, 0), p_lockup_starts_at, p_lockup_ends_at, 'active'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lockup_r2101',
          jsonb_build_object('lockup_id', v_id, 'investor_id', p_investor_id, 'shares', p_locked_shares));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2101(p_lockup_id uuid)
RETURNS TABLE (
  id uuid,
  lockup_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_released bigint,
  notes_md text
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
    SELECT a.id, a.lockup_id, a.action_type, a.taken_at, a.by_email, a.shares_released, a.notes_md
    FROM public.investor_lockup_action_log_r2101 a
    WHERE a.lockup_id = p_lockup_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2101(
  p_lockup_id uuid,
  p_action_type text,
  p_shares_released bigint,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_lockup_action_log_r2101 (
    lockup_id, action_type, by_email, shares_released, notes_md
  ) VALUES (
    p_lockup_id, p_action_type, (auth.jwt()->>'email'), COALESCE(p_shares_released, 0), p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2101',
          jsonb_build_object('action_id', v_id, 'lockup_id', p_lockup_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2101(
  p_lockup_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_cap_table_lockup_r2101
     SET status = p_status, updated_at = now()
   WHERE id = p_lockup_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2101',
          jsonb_build_object('lockup_id', p_lockup_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.expiring_soon_r2101()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  lockup_label text,
  locked_shares_count bigint,
  lockup_ends_at date,
  status text,
  days_remaining integer
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
    SELECT l.id, l.investor_id, l.lockup_label, l.locked_shares_count,
           l.lockup_ends_at, l.status,
           (l.lockup_ends_at - CURRENT_DATE)::integer AS days_remaining
    FROM public.investor_cap_table_lockup_r2101 l
    WHERE l.status = 'active'
      AND l.lockup_ends_at IS NOT NULL
      AND l.lockup_ends_at <= (CURRENT_DATE + INTERVAL '90 days')::date
    ORDER BY l.lockup_ends_at ASC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2101()
RETURNS TABLE (
  id uuid,
  lockup_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_released bigint,
  notes_md text
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
    SELECT a.id, a.lockup_id, a.action_type, a.taken_at, a.by_email, a.shares_released, a.notes_md
    FROM public.investor_lockup_action_log_r2101 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_lockups_r2101() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lockup_r2101(uuid, text, bigint, date, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2101(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2101(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2101(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_soon_r2101() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2101() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_lockups_r2101() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lockup_r2101(uuid, text, bigint, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2101(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2101(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2101(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_soon_r2101() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2101() TO authenticated;

COMMIT;
