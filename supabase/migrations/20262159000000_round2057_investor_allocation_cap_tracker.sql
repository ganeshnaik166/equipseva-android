BEGIN;

-- ============================================================
-- Round 2057 — Investor Allocation Cap Tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_allocation_cap_r2057 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  round_label text NOT NULL,
  allocation_cap_rupees bigint NOT NULL CHECK (allocation_cap_rupees >= 0),
  allocation_used_rupees bigint NOT NULL DEFAULT 0 CHECK (allocation_used_rupees >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exceeded','superseded','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_alloc_cap_r2057_investor ON public.investor_allocation_cap_r2057(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_alloc_cap_r2057_status ON public.investor_allocation_cap_r2057(status);
CREATE INDEX IF NOT EXISTS idx_inv_alloc_cap_r2057_captured ON public.investor_allocation_cap_r2057(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.investor_allocation_action_log_r2057 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cap_id uuid NOT NULL REFERENCES public.investor_allocation_cap_r2057(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('cap_set','allocation_increased','allocation_used','exceeded','closed','superseded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_alloc_action_r2057_cap ON public.investor_allocation_action_log_r2057(cap_id);
CREATE INDEX IF NOT EXISTS idx_inv_alloc_action_r2057_taken ON public.investor_allocation_action_log_r2057(taken_at DESC);

ALTER TABLE public.investor_allocation_cap_r2057 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_allocation_action_log_r2057 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_cap_r2057 ON public.investor_allocation_cap_r2057;
CREATE POLICY p_founder_cap_r2057 ON public.investor_allocation_cap_r2057
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_action_r2057 ON public.investor_allocation_action_log_r2057;
CREATE POLICY p_founder_action_r2057 ON public.investor_allocation_action_log_r2057
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_caps
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_caps_r2057()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  round_label text,
  allocation_cap_rupees bigint,
  allocation_used_rupees bigint,
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
  SELECT c.id, c.investor_id, p.email, c.round_label,
         c.allocation_cap_rupees, c.allocation_used_rupees,
         c.status, c.captured_at
  FROM public.investor_allocation_cap_r2057 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY c.captured_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================
-- RPC 2: log_cap
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_cap_r2057(
  p_investor_id uuid,
  p_round_label text,
  p_allocation_cap_rupees bigint,
  p_allocation_used_rupees bigint,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_allocation_cap_r2057
    (investor_id, round_label, allocation_cap_rupees, allocation_used_rupees, status)
  VALUES
    (p_investor_id, p_round_label, p_allocation_cap_rupees,
     COALESCE(p_allocation_used_rupees, 0), COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cap_r2057',
          jsonb_build_object('cap_id', v_id, 'investor_id', p_investor_id,
                             'round_label', p_round_label,
                             'cap_rupees', p_allocation_cap_rupees),
          now());
  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_actions
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_actions_r2057(p_cap_id uuid)
RETURNS TABLE (
  id uuid,
  cap_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
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
  SELECT a.id, a.cap_id, a.action_type, a.taken_at, a.by_email,
         a.amount_rupees, a.notes_md
  FROM public.investor_allocation_action_log_r2057 a
  WHERE a.cap_id = p_cap_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================
-- RPC 4: log_action
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_action_r2057(
  p_cap_id uuid,
  p_action_type text,
  p_by_email text,
  p_amount_rupees bigint,
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
  INSERT INTO public.investor_allocation_action_log_r2057
    (cap_id, action_type, by_email, amount_rupees, notes_md)
  VALUES
    (p_cap_id, p_action_type, p_by_email, p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2057',
          jsonb_build_object('action_id', v_id, 'cap_id', p_cap_id,
                             'action_type', p_action_type,
                             'amount_rupees', p_amount_rupees),
          now());
  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: mark_status
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2057(
  p_cap_id uuid,
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
  IF p_status NOT IN ('active','exceeded','superseded','closed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_allocation_cap_r2057
  SET status = p_status, updated_at = now()
  WHERE id = p_cap_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2057',
          jsonb_build_object('cap_id', p_cap_id, 'status', p_status),
          now());
END;
$$;

-- ============================================================
-- RPC 6: near_cap — investors within 90 percent of cap
-- ============================================================
CREATE OR REPLACE FUNCTION public.near_cap_r2057()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  round_label text,
  allocation_cap_rupees bigint,
  allocation_used_rupees bigint,
  pct_used numeric,
  status text
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
  SELECT c.id, c.investor_id, p.email, c.round_label,
         c.allocation_cap_rupees, c.allocation_used_rupees,
         CASE WHEN c.allocation_cap_rupees > 0
              THEN ROUND((c.allocation_used_rupees::numeric * 100.0) / c.allocation_cap_rupees::numeric, 2)
              ELSE 0 END,
         c.status
  FROM public.investor_allocation_cap_r2057 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  WHERE c.status = 'active'
    AND c.allocation_cap_rupees > 0
    AND (c.allocation_used_rupees::numeric / c.allocation_cap_rupees::numeric) >= 0.90
  ORDER BY (c.allocation_used_rupees::numeric / NULLIF(c.allocation_cap_rupees, 0)::numeric) DESC
  LIMIT 100;
END;
$$;

-- ============================================================
-- RPC 7: recent_actions
-- ============================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2057()
RETURNS TABLE (
  id uuid,
  cap_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
  investor_email text,
  round_label text
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
  SELECT a.id, a.cap_id, a.action_type, a.taken_at, a.by_email,
         a.amount_rupees, p.email, c.round_label
  FROM public.investor_allocation_action_log_r2057 a
  JOIN public.investor_allocation_cap_r2057 c ON c.id = a.cap_id
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================
-- Permission lockdown
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_caps_r2057() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cap_r2057(uuid, text, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2057(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2057(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2057(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.near_cap_r2057() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2057() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_caps_r2057() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cap_r2057(uuid, text, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2057(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2057(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2057(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.near_cap_r2057() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2057() TO authenticated;

COMMIT;
