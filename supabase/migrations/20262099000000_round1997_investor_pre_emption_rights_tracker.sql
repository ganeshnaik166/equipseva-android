BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.investor_pre_emption_rights_r1997 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  round_label text NOT NULL,
  pre_emption_pct_entitled numeric(8,4) NOT NULL DEFAULT 0,
  pre_emption_shares_entitled bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exercised','waived','expired')),
  expires_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_pre_emption_action_log_r1997 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  right_id uuid NOT NULL REFERENCES public.investor_pre_emption_rights_r1997(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('exercise','waive','expire','notified','extension_requested')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_taken bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.investor_pre_emption_rights_r1997 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_pre_emption_action_log_r1997 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_rights_r1997 ON public.investor_pre_emption_rights_r1997;
CREATE POLICY founder_all_rights_r1997 ON public.investor_pre_emption_rights_r1997
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1997 ON public.investor_pre_emption_action_log_r1997;
CREATE POLICY founder_all_actions_r1997 ON public.investor_pre_emption_action_log_r1997
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_rights
CREATE OR REPLACE FUNCTION public.list_pre_emption_rights_r1997()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  round_label text,
  pre_emption_pct_entitled numeric,
  pre_emption_shares_entitled bigint,
  status text,
  expires_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_id, r.round_label, r.pre_emption_pct_entitled,
         r.pre_emption_shares_entitled, r.status, r.expires_at, r.decided_at, r.created_at
  FROM public.investor_pre_emption_rights_r1997 r
  ORDER BY r.created_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: log_right
CREATE OR REPLACE FUNCTION public.log_pre_emption_right_r1997(
  p_investor_id uuid,
  p_round_label text,
  p_pct numeric,
  p_shares bigint,
  p_expires_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_pre_emption_rights_r1997(
    investor_id, round_label, pre_emption_pct_entitled, pre_emption_shares_entitled, expires_at
  ) VALUES (
    p_investor_id, p_round_label, COALESCE(p_pct,0), COALESCE(p_shares,0), p_expires_at
  ) RETURNING id INTO new_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pre_emption_right_r1997',
    jsonb_build_object('right_id', new_id, 'investor_id', p_investor_id, 'round_label', p_round_label));

  RETURN new_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_pre_emption_actions_r1997(p_right_id uuid)
RETURNS TABLE (
  id uuid,
  right_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_taken bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.right_id, a.action_type, a.taken_at, a.by_email, a.shares_taken, a.notes_md
  FROM public.investor_pre_emption_action_log_r1997 a
  WHERE a.right_id = p_right_id
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_pre_emption_action_r1997(
  p_right_id uuid,
  p_action_type text,
  p_by_email text,
  p_shares_taken bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_pre_emption_action_log_r1997(
    right_id, action_type, by_email, shares_taken, notes_md
  ) VALUES (
    p_right_id, p_action_type, p_by_email, p_shares_taken, p_notes_md
  ) RETURNING id INTO new_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pre_emption_action_r1997',
    jsonb_build_object('action_id', new_id, 'right_id', p_right_id, 'action_type', p_action_type));

  RETURN new_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_pre_emption_status_r1997(
  p_right_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','exercised','waived','expired') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.investor_pre_emption_rights_r1997
  SET status = p_status,
      decided_at = CASE WHEN p_status IN ('exercised','waived','expired') THEN now() ELSE decided_at END,
      updated_at = now()
  WHERE id = p_right_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_pre_emption_status_r1997',
    jsonb_build_object('right_id', p_right_id, 'status', p_status));
END;
$$;

-- RPC 6: expiring_soon
CREATE OR REPLACE FUNCTION public.list_pre_emption_expiring_soon_r1997()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  round_label text,
  status text,
  expires_at timestamptz,
  days_left integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_id, r.round_label, r.status, r.expires_at,
         GREATEST(0, EXTRACT(DAY FROM (r.expires_at - now()))::integer) AS days_left
  FROM public.investor_pre_emption_rights_r1997 r
  WHERE r.status = 'active'
    AND r.expires_at IS NOT NULL
    AND r.expires_at BETWEEN now() AND now() + interval '30 days'
  ORDER BY r.expires_at ASC
  LIMIT 200;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.list_pre_emption_recent_actions_r1997()
RETURNS TABLE (
  id uuid,
  right_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_taken bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.right_id, a.action_type, a.taken_at, a.by_email, a.shares_taken
  FROM public.investor_pre_emption_action_log_r1997 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_pre_emption_rights_r1997() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pre_emption_right_r1997(uuid, text, numeric, bigint, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_pre_emption_actions_r1997(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pre_emption_action_r1997(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_pre_emption_status_r1997(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_pre_emption_expiring_soon_r1997() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_pre_emption_recent_actions_r1997() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pre_emption_rights_r1997() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pre_emption_right_r1997(uuid, text, numeric, bigint, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pre_emption_actions_r1997(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pre_emption_action_r1997(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_pre_emption_status_r1997(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pre_emption_expiring_soon_r1997() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pre_emption_recent_actions_r1997() TO authenticated;

COMMIT;
