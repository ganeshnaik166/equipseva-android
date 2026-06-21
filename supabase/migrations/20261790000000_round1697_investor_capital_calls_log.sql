BEGIN;

-- =========================================================================
-- r1697 — Investor Capital Calls Log
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.investor_capital_calls_r1697 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  call_label text NOT NULL,
  called_amount_rupees bigint NOT NULL CHECK (called_amount_rupees >= 0),
  call_date date NOT NULL DEFAULT CURRENT_DATE,
  due_date date NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','funded','late','skipped')),
  funded_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (funded_amount_rupees >= 0),
  funded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icc_r1697_investor ON public.investor_capital_calls_r1697(investor_id);
CREATE INDEX IF NOT EXISTS idx_icc_r1697_status ON public.investor_capital_calls_r1697(status);
CREATE INDEX IF NOT EXISTS idx_icc_r1697_due ON public.investor_capital_calls_r1697(due_date);

CREATE TABLE IF NOT EXISTS public.investor_capital_call_messages_r1697 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id uuid NOT NULL REFERENCES public.investor_capital_calls_r1697(id) ON DELETE CASCADE,
  sent_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL CHECK (channel IN ('email','call','whatsapp')),
  message_summary text NOT NULL,
  response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iccm_r1697_call ON public.investor_capital_call_messages_r1697(call_id);
CREATE INDEX IF NOT EXISTS idx_iccm_r1697_sent ON public.investor_capital_call_messages_r1697(sent_at DESC);

ALTER TABLE public.investor_capital_calls_r1697 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_capital_call_messages_r1697 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS icc_r1697_founder_all ON public.investor_capital_calls_r1697;
CREATE POLICY icc_r1697_founder_all ON public.investor_capital_calls_r1697
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS iccm_r1697_founder_all ON public.investor_capital_call_messages_r1697;
CREATE POLICY iccm_r1697_founder_all ON public.investor_capital_call_messages_r1697
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC: list_calls
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_calls_r1697()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  call_label text,
  called_amount_rupees bigint,
  call_date date,
  due_date date,
  status text,
  funded_amount_rupees bigint,
  funded_at timestamptz,
  days_to_due int,
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
  SELECT
    c.id,
    c.investor_id,
    p.email::text AS investor_email,
    c.call_label,
    c.called_amount_rupees,
    c.call_date,
    c.due_date,
    c.status,
    c.funded_amount_rupees,
    c.funded_at,
    (c.due_date - CURRENT_DATE)::int AS days_to_due,
    c.created_at
  FROM public.investor_capital_calls_r1697 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY c.call_date DESC, c.created_at DESC
  LIMIT 500;
END;
$$;

-- =========================================================================
-- RPC: issue_call
-- =========================================================================
CREATE OR REPLACE FUNCTION public.issue_call_r1697(
  p_investor_id uuid,
  p_call_label text,
  p_called_amount_rupees bigint,
  p_due_date date
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
  INSERT INTO public.investor_capital_calls_r1697(investor_id, call_label, called_amount_rupees, due_date)
  VALUES (p_investor_id, p_call_label, p_called_amount_rupees, p_due_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'issue_call_r1697',
    jsonb_build_object('call_id', v_id, 'investor_id', p_investor_id, 'amount', p_called_amount_rupees));

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC: mark_funded
-- =========================================================================
CREATE OR REPLACE FUNCTION public.mark_funded_r1697(
  p_call_id uuid,
  p_funded_amount_rupees bigint
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
  UPDATE public.investor_capital_calls_r1697
  SET funded_amount_rupees = p_funded_amount_rupees,
      funded_at = now(),
      status = 'funded',
      updated_at = now()
  WHERE id = p_call_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_funded_r1697',
    jsonb_build_object('call_id', p_call_id, 'funded_amount', p_funded_amount_rupees));
END;
$$;

-- =========================================================================
-- RPC: list_messages
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_messages_r1697(p_call_id uuid)
RETURNS TABLE(
  id uuid,
  call_id uuid,
  sent_at timestamptz,
  channel text,
  message_summary text,
  response text
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
  SELECT m.id, m.call_id, m.sent_at, m.channel, m.message_summary, m.response
  FROM public.investor_capital_call_messages_r1697 m
  WHERE m.call_id = p_call_id
  ORDER BY m.sent_at DESC
  LIMIT 200;
END;
$$;

-- =========================================================================
-- RPC: log_message
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_message_r1697(
  p_call_id uuid,
  p_channel text,
  p_message_summary text,
  p_response text
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
  INSERT INTO public.investor_capital_call_messages_r1697(call_id, channel, message_summary, response)
  VALUES (p_call_id, p_channel, p_message_summary, p_response)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_message_r1697',
    jsonb_build_object('msg_id', v_id, 'call_id', p_call_id, 'channel', p_channel));

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC: capital_call_summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.capital_call_summary_r1697()
RETURNS TABLE(
  total_calls int,
  open_calls int,
  funded_calls int,
  late_calls int,
  skipped_calls int,
  total_called_rupees bigint,
  total_funded_rupees bigint,
  outstanding_rupees bigint
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
  SELECT
    (SELECT (COUNT(*))::int FROM public.investor_capital_calls_r1697),
    (SELECT (COUNT(*))::int FROM public.investor_capital_calls_r1697 WHERE status = 'open'),
    (SELECT (COUNT(*))::int FROM public.investor_capital_calls_r1697 WHERE status = 'funded'),
    (SELECT (COUNT(*))::int FROM public.investor_capital_calls_r1697 WHERE status = 'late'),
    (SELECT (COUNT(*))::int FROM public.investor_capital_calls_r1697 WHERE status = 'skipped'),
    (SELECT COALESCE(SUM(called_amount_rupees),0)::bigint FROM public.investor_capital_calls_r1697),
    (SELECT COALESCE(SUM(funded_amount_rupees),0)::bigint FROM public.investor_capital_calls_r1697),
    (SELECT COALESCE(SUM(called_amount_rupees - funded_amount_rupees),0)::bigint
       FROM public.investor_capital_calls_r1697 WHERE status IN ('open','late'));
END;
$$;

-- =========================================================================
-- RPC: late_calls
-- =========================================================================
CREATE OR REPLACE FUNCTION public.late_calls_r1697()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  call_label text,
  called_amount_rupees bigint,
  due_date date,
  days_overdue int,
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
  SELECT
    c.id,
    c.investor_id,
    p.email::text AS investor_email,
    c.call_label,
    c.called_amount_rupees,
    c.due_date,
    (CURRENT_DATE - c.due_date)::int AS days_overdue,
    c.status
  FROM public.investor_capital_calls_r1697 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  WHERE c.status IN ('open','late')
    AND c.due_date < CURRENT_DATE
  ORDER BY c.due_date ASC
  LIMIT 200;
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.list_calls_r1697() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.issue_call_r1697(uuid, text, bigint, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_funded_r1697(uuid, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_messages_r1697(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_message_r1697(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.capital_call_summary_r1697() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.late_calls_r1697() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_calls_r1697() TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_call_r1697(uuid, text, bigint, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_funded_r1697(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_messages_r1697(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_message_r1697(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capital_call_summary_r1697() TO authenticated;
GRANT EXECUTE ON FUNCTION public.late_calls_r1697() TO authenticated;

COMMIT;