BEGIN;

-- ============================================================
-- Round 1973 — Investor SAFE Notes Tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_safe_notes_r1973 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  safe_label text NOT NULL,
  principal_amount_rupees bigint NOT NULL DEFAULT 0,
  valuation_cap_rupees bigint NOT NULL DEFAULT 0,
  discount_pct numeric(5,2) NOT NULL DEFAULT 0,
  safe_type text NOT NULL CHECK (safe_type IN ('post_money','pre_money','mfn_only','no_cap')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','converted','repurchased','written_off')),
  issued_at timestamptz NOT NULL DEFAULT now(),
  converted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_safe_note_log_r1973 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  safe_id uuid NOT NULL REFERENCES public.investor_safe_notes_r1973(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('issued','mfn_triggered','converted','repurchased','extended')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_safe_notes_r1973 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_safe_note_log_r1973 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_safes_r1973 ON public.investor_safe_notes_r1973;
CREATE POLICY founder_all_safes_r1973 ON public.investor_safe_notes_r1973
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_safe_log_r1973 ON public.investor_safe_note_log_r1973;
CREATE POLICY founder_all_safe_log_r1973 ON public.investor_safe_note_log_r1973
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_safes
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_safes_r1973()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  safe_label text,
  principal_amount_rupees bigint,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  safe_type text,
  status text,
  issued_at timestamptz,
  converted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.investor_id, s.safe_label, s.principal_amount_rupees,
           s.valuation_cap_rupees, s.discount_pct, s.safe_type, s.status,
           s.issued_at, s.converted_at
    FROM public.investor_safe_notes_r1973 s
    ORDER BY s.issued_at DESC
    LIMIT 200;
END;
$$;

-- ============================================================
-- RPC 2: log_safe (issue a new SAFE)
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_safe_r1973(
  p_investor_id uuid,
  p_safe_label text,
  p_principal_amount_rupees bigint,
  p_valuation_cap_rupees bigint,
  p_discount_pct numeric,
  p_safe_type text
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

  INSERT INTO public.investor_safe_notes_r1973
    (investor_id, safe_label, principal_amount_rupees, valuation_cap_rupees, discount_pct, safe_type, status)
  VALUES
    (p_investor_id, p_safe_label, p_principal_amount_rupees, p_valuation_cap_rupees, p_discount_pct, p_safe_type, 'active')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_safe_r1973',
    jsonb_build_object('safe_id', v_id, 'investor_id', p_investor_id, 'principal', p_principal_amount_rupees)
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_actions
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1973(p_safe_id uuid)
RETURNS TABLE (
  id uuid,
  safe_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.safe_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_safe_note_log_r1973 a
    WHERE a.safe_id = p_safe_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

-- ============================================================
-- RPC 4: log_action
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_action_r1973(
  p_safe_id uuid,
  p_action_type text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_safe_note_log_r1973
    (safe_id, action_type, by_email, amount_rupees, notes_md)
  VALUES
    (p_safe_id, p_action_type, (auth.jwt()->>'email'), p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_action_r1973',
    jsonb_build_object('action_id', v_id, 'safe_id', p_safe_id, 'action_type', p_action_type)
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: mark_status
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_status_r1973(
  p_safe_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','converted','repurchased','written_off') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.investor_safe_notes_r1973
     SET status = p_status,
         converted_at = CASE WHEN p_status = 'converted' THEN now() ELSE converted_at END,
         updated_at = now()
   WHERE id = p_safe_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r1973',
    jsonb_build_object('safe_id', p_safe_id, 'status', p_status)
  );
END;
$$;

-- ============================================================
-- RPC 6: outstanding_total
-- ============================================================
CREATE OR REPLACE FUNCTION public.outstanding_total_r1973()
RETURNS TABLE (
  active_count bigint,
  active_principal_rupees bigint,
  converted_count bigint,
  converted_principal_rupees bigint,
  total_principal_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*) FILTER (WHERE status = 'active')::bigint,
      COALESCE(SUM(principal_amount_rupees) FILTER (WHERE status = 'active'), 0)::bigint,
      COUNT(*) FILTER (WHERE status = 'converted')::bigint,
      COALESCE(SUM(principal_amount_rupees) FILTER (WHERE status = 'converted'), 0)::bigint,
      COALESCE(SUM(principal_amount_rupees), 0)::bigint
    FROM public.investor_safe_notes_r1973;
END;
$$;

-- ============================================================
-- RPC 7: recent_actions
-- ============================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r1973()
RETURNS TABLE (
  id uuid,
  safe_id uuid,
  safe_label text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.safe_id, s.safe_label, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_safe_note_log_r1973 a
    LEFT JOIN public.investor_safe_notes_r1973 s ON s.id = a.safe_id
    ORDER BY a.taken_at DESC
    LIMIT 50;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_safes_r1973() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_safe_r1973(uuid, text, bigint, bigint, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1973(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1973(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1973(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.outstanding_total_r1973() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1973() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_safes_r1973() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_safe_r1973(uuid, text, bigint, bigint, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1973(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1973(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1973(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.outstanding_total_r1973() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1973() TO authenticated;

COMMIT;
