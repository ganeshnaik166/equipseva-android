BEGIN;

-- =============================================================================
-- Round 1745 — Investor Distribution Schedule
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.investor_distribution_schedule_r1745 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scheduled_date date NOT NULL,
  distribution_type text NOT NULL CHECK (distribution_type IN ('dividend','return_of_capital','liquidity_event','buyback')),
  scheduled_amount_rupees bigint NOT NULL CHECK (scheduled_amount_rupees >= 0),
  actual_amount_rupees bigint CHECK (actual_amount_rupees IS NULL OR actual_amount_rupees >= 0),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','paid','deferred','cancelled')),
  paid_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ids_r1745_investor ON public.investor_distribution_schedule_r1745(investor_id);
CREATE INDEX IF NOT EXISTS idx_ids_r1745_status ON public.investor_distribution_schedule_r1745(status);
CREATE INDEX IF NOT EXISTS idx_ids_r1745_date ON public.investor_distribution_schedule_r1745(scheduled_date DESC);

CREATE TABLE IF NOT EXISTS public.investor_distribution_communications_r1745 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL REFERENCES public.investor_distribution_schedule_r1745(id) ON DELETE CASCADE,
  comm_type text NOT NULL CHECK (comm_type IN ('confirmation_email','tax_form','dispute_response','founder_note')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  message_summary text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_idc_r1745_dist ON public.investor_distribution_communications_r1745(distribution_id);
CREATE INDEX IF NOT EXISTS idx_idc_r1745_sent ON public.investor_distribution_communications_r1745(sent_at DESC);

ALTER TABLE public.investor_distribution_schedule_r1745 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_distribution_communications_r1745 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ids_r1745_founder ON public.investor_distribution_schedule_r1745;
CREATE POLICY p_ids_r1745_founder ON public.investor_distribution_schedule_r1745
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_idc_r1745_founder ON public.investor_distribution_communications_r1745;
CREATE POLICY p_idc_r1745_founder ON public.investor_distribution_communications_r1745
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =============================================================================
-- RPC 1: list_distributions
-- =============================================================================
CREATE OR REPLACE FUNCTION public.list_distributions_r1745(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  scheduled_date date,
  distribution_type text,
  scheduled_amount_rupees bigint,
  actual_amount_rupees bigint,
  status text,
  paid_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.investor_id, p.email::text, d.scheduled_date, d.distribution_type,
         d.scheduled_amount_rupees, d.actual_amount_rupees, d.status, d.paid_at, d.notes, d.created_at
  FROM public.investor_distribution_schedule_r1745 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  ORDER BY d.scheduled_date DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- =============================================================================
-- RPC 2: schedule_distribution
-- =============================================================================
CREATE OR REPLACE FUNCTION public.schedule_distribution_r1745(
  p_investor_id uuid,
  p_scheduled_date date,
  p_distribution_type text,
  p_scheduled_amount_rupees bigint,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_distribution_schedule_r1745
    (investor_id, scheduled_date, distribution_type, scheduled_amount_rupees, notes)
  VALUES (p_investor_id, p_scheduled_date, p_distribution_type, p_scheduled_amount_rupees, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'schedule_distribution_r1745',
          jsonb_build_object('distribution_id', v_id, 'investor_id', p_investor_id,
                             'scheduled_amount_rupees', p_scheduled_amount_rupees,
                             'distribution_type', p_distribution_type));
  RETURN v_id;
END;
$$;

-- =============================================================================
-- RPC 3: list_comms
-- =============================================================================
CREATE OR REPLACE FUNCTION public.list_comms_r1745(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  distribution_id uuid,
  comm_type text,
  sent_at timestamptz,
  by_email text,
  message_summary text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.distribution_id, c.comm_type, c.sent_at, c.by_email, c.message_summary
  FROM public.investor_distribution_communications_r1745 c
  ORDER BY c.sent_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- =============================================================================
-- RPC 4: log_comm
-- =============================================================================
CREATE OR REPLACE FUNCTION public.log_comm_r1745(
  p_distribution_id uuid,
  p_comm_type text,
  p_message_summary text,
  p_by_email text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_distribution_communications_r1745
    (distribution_id, comm_type, message_summary, by_email)
  VALUES (p_distribution_id, p_comm_type, p_message_summary, COALESCE(p_by_email, (auth.jwt()->>'email')))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_comm_r1745',
          jsonb_build_object('comm_id', v_id, 'distribution_id', p_distribution_id, 'comm_type', p_comm_type));
  RETURN v_id;
END;
$$;

-- =============================================================================
-- RPC 5: mark_paid
-- =============================================================================
CREATE OR REPLACE FUNCTION public.mark_paid_r1745(
  p_distribution_id uuid,
  p_actual_amount_rupees bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_distribution_schedule_r1745
  SET status = 'paid',
      actual_amount_rupees = p_actual_amount_rupees,
      paid_at = now(),
      updated_at = now()
  WHERE id = p_distribution_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_paid_r1745',
          jsonb_build_object('distribution_id', p_distribution_id, 'actual_amount_rupees', p_actual_amount_rupees));
END;
$$;

-- =============================================================================
-- RPC 6: distribution_summary
-- =============================================================================
CREATE OR REPLACE FUNCTION public.distribution_summary_r1745()
RETURNS TABLE (
  total_scheduled int,
  total_paid int,
  total_deferred int,
  total_cancelled int,
  scheduled_amount_rupees bigint,
  paid_amount_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status = 'scheduled'))::int,
    (COUNT(*) FILTER (WHERE status = 'paid'))::int,
    (COUNT(*) FILTER (WHERE status = 'deferred'))::int,
    (COUNT(*) FILTER (WHERE status = 'cancelled'))::int,
    COALESCE(SUM(scheduled_amount_rupees) FILTER (WHERE status IN ('scheduled','paid')), 0)::bigint,
    COALESCE(SUM(actual_amount_rupees) FILTER (WHERE status = 'paid'), 0)::bigint
  FROM public.investor_distribution_schedule_r1745;
END;
$$;

-- =============================================================================
-- RPC 7: upcoming_distributions
-- =============================================================================
CREATE OR REPLACE FUNCTION public.upcoming_distributions_r1745(p_days int DEFAULT 90)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  scheduled_date date,
  distribution_type text,
  scheduled_amount_rupees bigint,
  status text,
  days_until int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.investor_id, p.email::text, d.scheduled_date, d.distribution_type,
         d.scheduled_amount_rupees, d.status,
         (d.scheduled_date - CURRENT_DATE)::int
  FROM public.investor_distribution_schedule_r1745 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  WHERE d.status = 'scheduled'
    AND d.scheduled_date >= CURRENT_DATE
    AND d.scheduled_date <= CURRENT_DATE + (GREATEST(1, LEAST(p_days, 365)) * INTERVAL '1 day')
  ORDER BY d.scheduled_date ASC
  LIMIT 200;
END;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
REVOKE EXECUTE ON FUNCTION public.list_distributions_r1745(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_distributions_r1745(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.schedule_distribution_r1745(uuid, date, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.schedule_distribution_r1745(uuid, date, text, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_comms_r1745(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_comms_r1745(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_comm_r1745(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_comm_r1745(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_paid_r1745(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_paid_r1745(uuid, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.distribution_summary_r1745() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.distribution_summary_r1745() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.upcoming_distributions_r1745(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_distributions_r1745(int) TO authenticated;

COMMIT;