BEGIN;

-- =========================================================================
-- Round 1909: Investor Capital Call Schedule
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.investor_capital_call_schedule_r1909 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  call_date date NOT NULL,
  call_amount_rupees bigint NOT NULL CHECK (call_amount_rupees >= 0),
  call_purpose_md text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','sent','paid','late','cancelled')),
  sent_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iccs_r1909_investor ON public.investor_capital_call_schedule_r1909(investor_id);
CREATE INDEX IF NOT EXISTS idx_iccs_r1909_status ON public.investor_capital_call_schedule_r1909(status);
CREATE INDEX IF NOT EXISTS idx_iccs_r1909_date ON public.investor_capital_call_schedule_r1909(call_date DESC);

ALTER TABLE public.investor_capital_call_schedule_r1909 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iccs_r1909_founder_all ON public.investor_capital_call_schedule_r1909;
CREATE POLICY iccs_r1909_founder_all ON public.investor_capital_call_schedule_r1909
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_capital_call_log_r1909 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id uuid NOT NULL REFERENCES public.investor_capital_call_schedule_r1909(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('call_sent','reminder_sent','payment_received','escalation','written_off')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iccl_r1909_call ON public.investor_capital_call_log_r1909(call_id);
CREATE INDEX IF NOT EXISTS idx_iccl_r1909_taken ON public.investor_capital_call_log_r1909(taken_at DESC);

ALTER TABLE public.investor_capital_call_log_r1909 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iccl_r1909_founder_all ON public.investor_capital_call_log_r1909;
CREATE POLICY iccl_r1909_founder_all ON public.investor_capital_call_log_r1909
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_calls
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_capital_calls_r1909()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  call_date date,
  call_amount_rupees bigint,
  call_purpose_md text,
  status text,
  sent_at timestamptz,
  paid_at timestamptz,
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
  SELECT s.id, s.investor_id, s.call_date, s.call_amount_rupees, s.call_purpose_md,
         s.status, s.sent_at, s.paid_at, s.created_at
  FROM public.investor_capital_call_schedule_r1909 s
  ORDER BY s.call_date DESC, s.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_capital_calls_r1909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_capital_calls_r1909() TO authenticated;

-- =========================================================================
-- RPC 2: log_call (creates schedule entry)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_capital_call_r1909(
  p_investor_id uuid,
  p_call_date date,
  p_call_amount_rupees bigint,
  p_call_purpose_md text
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

  INSERT INTO public.investor_capital_call_schedule_r1909(investor_id, call_date, call_amount_rupees, call_purpose_md, status)
  VALUES (p_investor_id, p_call_date, p_call_amount_rupees, p_call_purpose_md, 'scheduled')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1909.log_capital_call',
          jsonb_build_object('call_id', v_id, 'investor_id', p_investor_id, 'amount_rupees', p_call_amount_rupees, 'call_date', p_call_date),
          now());

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_capital_call_r1909(uuid, date, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_capital_call_r1909(uuid, date, bigint, text) TO authenticated;

-- =========================================================================
-- RPC 3: list_logs
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_capital_call_logs_r1909(p_call_id uuid)
RETURNS TABLE (
  id uuid,
  call_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  note_md text
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
  SELECT l.id, l.call_id, l.action_type, l.taken_at, l.by_email, l.note_md
  FROM public.investor_capital_call_log_r1909 l
  WHERE l.call_id = p_call_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_capital_call_logs_r1909(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_capital_call_logs_r1909(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: log_action
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_capital_call_action_r1909(
  p_call_id uuid,
  p_action_type text,
  p_note_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_log_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := auth.jwt()->>'email';

  INSERT INTO public.investor_capital_call_log_r1909(call_id, action_type, by_email, note_md)
  VALUES (p_call_id, p_action_type, v_email, p_note_md)
  RETURNING id INTO v_log_id;

  -- side-effect: if call_sent, mark schedule as sent
  IF p_action_type = 'call_sent' THEN
    UPDATE public.investor_capital_call_schedule_r1909
    SET status = 'sent', sent_at = COALESCE(sent_at, now()), updated_at = now()
    WHERE id = p_call_id AND status = 'scheduled';
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), v_email, 'r1909.log_capital_call_action',
          jsonb_build_object('call_id', p_call_id, 'action_type', p_action_type, 'log_id', v_log_id),
          now());

  RETURN v_log_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_capital_call_action_r1909(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_capital_call_action_r1909(uuid, text, text) TO authenticated;

-- =========================================================================
-- RPC 5: mark_paid
-- =========================================================================
CREATE OR REPLACE FUNCTION public.mark_capital_call_paid_r1909(p_call_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := auth.jwt()->>'email';

  UPDATE public.investor_capital_call_schedule_r1909
  SET status = 'paid', paid_at = now(), updated_at = now()
  WHERE id = p_call_id;

  INSERT INTO public.investor_capital_call_log_r1909(call_id, action_type, by_email, note_md)
  VALUES (p_call_id, 'payment_received', v_email, 'Marked paid by founder');

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), v_email, 'r1909.mark_capital_call_paid',
          jsonb_build_object('call_id', p_call_id),
          now());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_capital_call_paid_r1909(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_capital_call_paid_r1909(uuid) TO authenticated;

-- =========================================================================
-- RPC 6: late_calls
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_late_capital_calls_r1909()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  call_date date,
  call_amount_rupees bigint,
  status text,
  days_overdue int
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
  SELECT s.id, s.investor_id, s.call_date, s.call_amount_rupees, s.status,
         (CURRENT_DATE - s.call_date)::int AS days_overdue
  FROM public.investor_capital_call_schedule_r1909 s
  WHERE s.status IN ('scheduled','sent','late')
    AND s.call_date < CURRENT_DATE
  ORDER BY s.call_date ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_late_capital_calls_r1909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_late_capital_calls_r1909() TO authenticated;

-- =========================================================================
-- RPC 7: recent_logs (across all calls)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_recent_capital_call_logs_r1909()
RETURNS TABLE (
  id uuid,
  call_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  note_md text
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
  SELECT l.id, l.call_id, l.action_type, l.taken_at, l.by_email, l.note_md
  FROM public.investor_capital_call_log_r1909 l
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_recent_capital_call_logs_r1909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recent_capital_call_logs_r1909() TO authenticated;

COMMIT;
