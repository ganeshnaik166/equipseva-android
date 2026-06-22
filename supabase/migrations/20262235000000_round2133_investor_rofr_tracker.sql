BEGIN;

-- Table 1: ROFR tracker
CREATE TABLE IF NOT EXISTS public.investor_rofr_tracker_r2133 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rofr_label text NOT NULL,
  max_rofr_shares bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exercised','waived','expired')),
  expires_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irt_r2133_investor ON public.investor_rofr_tracker_r2133(investor_id);
CREATE INDEX IF NOT EXISTS idx_irt_r2133_status ON public.investor_rofr_tracker_r2133(status);
CREATE INDEX IF NOT EXISTS idx_irt_r2133_expires ON public.investor_rofr_tracker_r2133(expires_at);
CREATE INDEX IF NOT EXISTS idx_irt_r2133_captured ON public.investor_rofr_tracker_r2133(captured_at DESC);

ALTER TABLE public.investor_rofr_tracker_r2133 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS irt_r2133_founder_all ON public.investor_rofr_tracker_r2133;
CREATE POLICY irt_r2133_founder_all ON public.investor_rofr_tracker_r2133
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: Action log
CREATE TABLE IF NOT EXISTS public.investor_rofr_action_log_r2133 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rofr_id uuid NOT NULL REFERENCES public.investor_rofr_tracker_r2133(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','exercised','waived','expired','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_used bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iral_r2133_rofr ON public.investor_rofr_action_log_r2133(rofr_id);
CREATE INDEX IF NOT EXISTS idx_iral_r2133_taken ON public.investor_rofr_action_log_r2133(taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_iral_r2133_type ON public.investor_rofr_action_log_r2133(action_type);

ALTER TABLE public.investor_rofr_action_log_r2133 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iral_r2133_founder_all ON public.investor_rofr_action_log_r2133;
CREATE POLICY iral_r2133_founder_all ON public.investor_rofr_action_log_r2133
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list rofrs
CREATE OR REPLACE FUNCTION public.list_investor_rofrs_r2133()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  rofr_label text,
  max_rofr_shares bigint,
  status text,
  expires_at timestamptz,
  captured_at timestamptz,
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
  SELECT r.id, r.investor_id, p.email::text, r.rofr_label, r.max_rofr_shares, r.status, r.expires_at, r.captured_at, r.created_at
  FROM public.investor_rofr_tracker_r2133 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY r.captured_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: log rofr
CREATE OR REPLACE FUNCTION public.log_investor_rofr_r2133(
  p_investor_id uuid,
  p_rofr_label text,
  p_max_rofr_shares bigint,
  p_expires_at timestamptz
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
  INSERT INTO public.investor_rofr_tracker_r2133(investor_id, rofr_label, max_rofr_shares, expires_at)
  VALUES (p_investor_id, p_rofr_label, p_max_rofr_shares, p_expires_at)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_rofr_r2133',
    jsonb_build_object('rofr_id', v_id, 'investor_id', p_investor_id, 'rofr_label', p_rofr_label, 'max_rofr_shares', p_max_rofr_shares));
  RETURN v_id;
END;
$$;

-- RPC 3: list actions
CREATE OR REPLACE FUNCTION public.list_investor_rofr_actions_r2133()
RETURNS TABLE (
  id uuid,
  rofr_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_used bigint,
  notes_md text,
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
  SELECT a.id, a.rofr_id, a.action_type, a.taken_at, a.by_email, a.shares_used, a.notes_md, a.created_at
  FROM public.investor_rofr_action_log_r2133 a
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log action
CREATE OR REPLACE FUNCTION public.log_investor_rofr_action_r2133(
  p_rofr_id uuid,
  p_action_type text,
  p_shares_used bigint,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.investor_rofr_action_log_r2133(rofr_id, action_type, by_email, shares_used, notes_md)
  VALUES (p_rofr_id, p_action_type, v_email, p_shares_used, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_investor_rofr_action_r2133',
    jsonb_build_object('action_id', v_id, 'rofr_id', p_rofr_id, 'action_type', p_action_type, 'shares_used', p_shares_used));
  RETURN v_id;
END;
$$;

-- RPC 5: mark status
CREATE OR REPLACE FUNCTION public.mark_investor_rofr_status_r2133(
  p_rofr_id uuid,
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
  UPDATE public.investor_rofr_tracker_r2133
  SET status = p_status, updated_at = now()
  WHERE id = p_rofr_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_investor_rofr_status_r2133',
    jsonb_build_object('rofr_id', p_rofr_id, 'status', p_status));
END;
$$;

-- RPC 6: expiring soon (next 30 days, active)
CREATE OR REPLACE FUNCTION public.list_investor_rofr_expiring_soon_r2133()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  rofr_label text,
  max_rofr_shares bigint,
  status text,
  expires_at timestamptz,
  days_remaining int
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
  SELECT r.id, r.investor_id, p.email::text, r.rofr_label, r.max_rofr_shares, r.status, r.expires_at,
    GREATEST(0, EXTRACT(DAY FROM (r.expires_at - now()))::int) AS days_remaining
  FROM public.investor_rofr_tracker_r2133 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  WHERE r.status = 'active'
    AND r.expires_at IS NOT NULL
    AND r.expires_at >= now()
    AND r.expires_at <= now() + interval '30 days'
  ORDER BY r.expires_at ASC
  LIMIT 200;
END;
$$;

-- RPC 7: recent actions (last 14 days)
CREATE OR REPLACE FUNCTION public.list_investor_rofr_recent_actions_r2133()
RETURNS TABLE (
  id uuid,
  rofr_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_used bigint,
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
  SELECT a.id, a.rofr_id, a.action_type, a.taken_at, a.by_email, a.shares_used, a.notes_md
  FROM public.investor_rofr_action_log_r2133 a
  WHERE a.taken_at >= now() - interval '14 days'
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_investor_rofrs_r2133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_rofrs_r2133() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_rofr_r2133(uuid, text, bigint, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_rofr_r2133(uuid, text, bigint, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_rofr_actions_r2133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_rofr_actions_r2133() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_rofr_action_r2133(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_rofr_action_r2133(uuid, text, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_investor_rofr_status_r2133(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_investor_rofr_status_r2133(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_rofr_expiring_soon_r2133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_rofr_expiring_soon_r2133() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_rofr_recent_actions_r2133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_rofr_recent_actions_r2133() TO authenticated;

COMMIT;
