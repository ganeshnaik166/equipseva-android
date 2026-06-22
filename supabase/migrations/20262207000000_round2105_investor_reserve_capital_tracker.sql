BEGIN;

-- ============================================================================
-- Round 2105 — Investor Reserve Capital Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_reserve_capital_tracker_r2105 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  reserve_label text NOT NULL,
  reserve_amount_rupees bigint NOT NULL DEFAULT 0,
  drawdown_amount_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'committed'
    CHECK (status IN ('committed','drawn','exhausted','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reserve_r2105_investor
  ON public.investor_reserve_capital_tracker_r2105(investor_id);
CREATE INDEX IF NOT EXISTS idx_reserve_r2105_status
  ON public.investor_reserve_capital_tracker_r2105(status);
CREATE INDEX IF NOT EXISTS idx_reserve_r2105_captured
  ON public.investor_reserve_capital_tracker_r2105(captured_at DESC);

ALTER TABLE public.investor_reserve_capital_tracker_r2105 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_reserve_r2105
  ON public.investor_reserve_capital_tracker_r2105;
CREATE POLICY founder_reserve_r2105
  ON public.investor_reserve_capital_tracker_r2105
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.investor_reserve_action_log_r2105 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reserve_id uuid NOT NULL REFERENCES public.investor_reserve_capital_tracker_r2105(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('committed','drawn','exhausted','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reserve_act_r2105_reserve
  ON public.investor_reserve_action_log_r2105(reserve_id);
CREATE INDEX IF NOT EXISTS idx_reserve_act_r2105_taken
  ON public.investor_reserve_action_log_r2105(taken_at DESC);

ALTER TABLE public.investor_reserve_action_log_r2105 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_reserve_act_r2105
  ON public.investor_reserve_action_log_r2105;
CREATE POLICY founder_reserve_act_r2105
  ON public.investor_reserve_action_log_r2105
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================================
-- RPC 1: list_reserves
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_reserves_r2105()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  reserve_label text,
  reserve_amount_rupees bigint,
  drawdown_amount_rupees bigint,
  remaining_rupees bigint,
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
    SELECT r.id, r.investor_id, r.reserve_label,
           r.reserve_amount_rupees, r.drawdown_amount_rupees,
           (r.reserve_amount_rupees - r.drawdown_amount_rupees) AS remaining_rupees,
           r.status, r.captured_at
    FROM public.investor_reserve_capital_tracker_r2105 r
    ORDER BY r.captured_at DESC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reserves_r2105() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reserves_r2105() TO authenticated;


-- ============================================================================
-- RPC 2: log_reserve
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_reserve_r2105(
  p_investor_id uuid,
  p_reserve_label text,
  p_reserve_amount_rupees bigint,
  p_status text DEFAULT 'committed'
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

  INSERT INTO public.investor_reserve_capital_tracker_r2105
    (investor_id, reserve_label, reserve_amount_rupees, status)
  VALUES (p_investor_id, p_reserve_label, p_reserve_amount_rupees, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_reserve_r2105',
    jsonb_build_object(
      'reserve_id', v_id,
      'investor_id', p_investor_id,
      'reserve_label', p_reserve_label,
      'reserve_amount_rupees', p_reserve_amount_rupees,
      'status', p_status
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_reserve_r2105(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_reserve_r2105(uuid, text, bigint, text) TO authenticated;


-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r2105(p_reserve_id uuid)
RETURNS TABLE (
  id uuid,
  reserve_id uuid,
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
    SELECT a.id, a.reserve_id, a.action_type, a.taken_at,
           a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_reserve_action_log_r2105 a
    WHERE a.reserve_id = p_reserve_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2105(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2105(uuid) TO authenticated;


-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r2105(
  p_reserve_id uuid,
  p_action_type text,
  p_amount_rupees bigint DEFAULT 0,
  p_notes_md text DEFAULT NULL
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

  v_email := (auth.jwt() ->> 'email');

  INSERT INTO public.investor_reserve_action_log_r2105
    (reserve_id, action_type, by_email, amount_rupees, notes_md)
  VALUES (p_reserve_id, p_action_type, v_email, p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;

  IF p_action_type = 'drawn' THEN
    UPDATE public.investor_reserve_capital_tracker_r2105
       SET drawdown_amount_rupees = drawdown_amount_rupees + p_amount_rupees,
           status = CASE
             WHEN drawdown_amount_rupees + p_amount_rupees >= reserve_amount_rupees
               THEN 'exhausted'
             ELSE 'drawn'
           END,
           updated_at = now()
     WHERE id = p_reserve_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_action_r2105',
    jsonb_build_object(
      'action_id', v_id,
      'reserve_id', p_reserve_id,
      'action_type', p_action_type,
      'amount_rupees', p_amount_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r2105(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2105(uuid, text, bigint, text) TO authenticated;


-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2105(
  p_reserve_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.investor_reserve_capital_tracker_r2105
     SET status = p_status, updated_at = now()
   WHERE id = p_reserve_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'mark_status_r2105',
    jsonb_build_object('reserve_id', p_reserve_id, 'status', p_status)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2105(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2105(uuid, text) TO authenticated;


-- ============================================================================
-- RPC 6: exhausted
-- ============================================================================
CREATE OR REPLACE FUNCTION public.exhausted_r2105()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  reserve_label text,
  reserve_amount_rupees bigint,
  drawdown_amount_rupees bigint,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.investor_id, r.reserve_label,
           r.reserve_amount_rupees, r.drawdown_amount_rupees, r.captured_at
    FROM public.investor_reserve_capital_tracker_r2105 r
    WHERE r.status = 'exhausted'
    ORDER BY r.captured_at DESC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.exhausted_r2105() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.exhausted_r2105() TO authenticated;


-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2105()
RETURNS TABLE (
  id uuid,
  reserve_id uuid,
  reserve_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.reserve_id, r.reserve_label, a.action_type,
           a.taken_at, a.by_email, a.amount_rupees
    FROM public.investor_reserve_action_log_r2105 a
    JOIN public.investor_reserve_capital_tracker_r2105 r ON r.id = a.reserve_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2105() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2105() TO authenticated;

COMMIT;
