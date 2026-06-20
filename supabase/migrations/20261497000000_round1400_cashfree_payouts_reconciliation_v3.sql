BEGIN;
-- r1400 ★ 600 SHIPS MILESTONE ★
-- Cashfree Payouts v3 Reconciliation Engine
-- 3 tables + 9 RPCs covering attempt ledger, webhook events, reconciliation runs



-- ============================================================================
-- TABLE 1: founder_cashfree_payout_attempts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_cashfree_payout_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_payout_id uuid NOT NULL REFERENCES public.engineer_payouts(id) ON DELETE CASCADE,
  attempt_number int NOT NULL DEFAULT 1,
  cashfree_reference_id text,
  amount_rupees numeric NOT NULL CHECK (amount_rupees >= 0),
  attempt_status text NOT NULL DEFAULT 'pending'
    CHECK (attempt_status IN ('pending','submitted','succeeded','failed','timeout','reverted','manual_intervention')),
  failure_reason text,
  failure_code text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  request_payload jsonb,
  response_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_payout_id, attempt_number)
);

CREATE INDEX IF NOT EXISTS idx_fcpa_engineer_payout_id ON public.founder_cashfree_payout_attempts (engineer_payout_id);
CREATE INDEX IF NOT EXISTS idx_fcpa_status ON public.founder_cashfree_payout_attempts (attempt_status);
CREATE INDEX IF NOT EXISTS idx_fcpa_submitted_at ON public.founder_cashfree_payout_attempts (submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_fcpa_cashfree_ref ON public.founder_cashfree_payout_attempts (cashfree_reference_id);

ALTER TABLE public.founder_cashfree_payout_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.founder_cashfree_payout_attempts FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- TABLE 2: founder_cashfree_webhook_events
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_cashfree_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id text NOT NULL UNIQUE,
  event_kind text NOT NULL
    CHECK (event_kind IN ('payout.success','payout.failed','payout.reverted','payout.pending','transfer.success','transfer.failed','batch.complete','batch.failed','beneficiary.added','beneficiary.removed')),
  payout_attempt_id uuid REFERENCES public.founder_cashfree_payout_attempts(id) ON DELETE SET NULL,
  signature_valid boolean,
  raw_payload jsonb NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  processing_outcome text
    CHECK (processing_outcome IN ('processed','duplicate','invalid_signature','unknown_reference','retry_scheduled'))
);

CREATE INDEX IF NOT EXISTS idx_fcwe_event_kind ON public.founder_cashfree_webhook_events (event_kind);
CREATE INDEX IF NOT EXISTS idx_fcwe_received_at ON public.founder_cashfree_webhook_events (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_fcwe_signature_valid ON public.founder_cashfree_webhook_events (signature_valid);
CREATE INDEX IF NOT EXISTS idx_fcwe_attempt_id ON public.founder_cashfree_webhook_events (payout_attempt_id);

ALTER TABLE public.founder_cashfree_webhook_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.founder_cashfree_webhook_events FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- TABLE 3: founder_cashfree_reconciliation_runs
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_cashfree_reconciliation_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_date date NOT NULL UNIQUE,
  run_kind text NOT NULL DEFAULT 'daily_auto'
    CHECK (run_kind IN ('daily_auto','weekly_audit','manual','emergency')),
  total_payouts_processed int DEFAULT 0,
  total_attempts_made int DEFAULT 0,
  total_succeeded int DEFAULT 0,
  total_failed int DEFAULT 0,
  total_amount_rupees numeric DEFAULT 0,
  total_amount_succeeded_rupees numeric DEFAULT 0,
  discrepancies_found int NOT NULL DEFAULT 0,
  discrepancy_amount_rupees numeric NOT NULL DEFAULT 0,
  run_status text NOT NULL DEFAULT 'running'
    CHECK (run_status IN ('running','complete','failed','partial')),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  error_log jsonb NOT NULL DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_fcrr_run_date ON public.founder_cashfree_reconciliation_runs (run_date DESC);
CREATE INDEX IF NOT EXISTS idx_fcrr_status ON public.founder_cashfree_reconciliation_runs (run_status);

ALTER TABLE public.founder_cashfree_reconciliation_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.founder_cashfree_reconciliation_runs FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- RPC 1: founder_cashfree_v3_summary — 18 KPI grid
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cashfree_v3_summary();
CREATE OR REPLACE FUNCTION public.founder_cashfree_v3_summary()
RETURNS TABLE (
  lifetime_attempts bigint,
  lifetime_succeeded bigint,
  lifetime_failed bigint,
  lifetime_amount_rupees numeric,
  lifetime_succeeded_rupees numeric,
  attempts_30d bigint,
  succeeded_30d bigint,
  failed_30d bigint,
  amount_30d_rupees numeric,
  pending_attempts bigint,
  manual_intervention_count bigint,
  reverted_count bigint,
  webhooks_total bigint,
  webhooks_30d bigint,
  invalid_signature_count bigint,
  reconciliation_runs_total bigint,
  last_run_status text,
  discrepancies_open bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts)::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='succeeded')::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='failed')::bigint,
    COALESCE((SELECT SUM(amount_rupees) FROM public.founder_cashfree_payout_attempts), 0)::numeric,
    COALESCE((SELECT SUM(amount_rupees) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='succeeded'), 0)::numeric,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE submitted_at >= now() - interval '30 days')::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='succeeded' AND submitted_at >= now() - interval '30 days')::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='failed' AND submitted_at >= now() - interval '30 days')::bigint,
    COALESCE((SELECT SUM(amount_rupees) FROM public.founder_cashfree_payout_attempts WHERE submitted_at >= now() - interval '30 days'), 0)::numeric,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status IN ('pending','submitted'))::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='manual_intervention')::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='reverted')::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_webhook_events)::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_webhook_events WHERE received_at >= now() - interval '30 days')::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_webhook_events WHERE signature_valid = false)::bigint,
    (SELECT COUNT(*) FROM public.founder_cashfree_reconciliation_runs)::bigint,
    COALESCE((SELECT run_status FROM public.founder_cashfree_reconciliation_runs ORDER BY run_date DESC LIMIT 1), 'none'),
    (SELECT COUNT(*) FROM public.founder_cashfree_payout_attempts WHERE attempt_status='manual_intervention' OR (attempt_status='submitted' AND submitted_at < now() - interval '24 hours'))::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cashfree_v3_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cashfree_v3_summary() TO authenticated;

-- ============================================================================
-- RPC 2: attempts_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cashfree_v3_attempts_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_cashfree_v3_attempts_recent(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  engineer_payout_id uuid,
  attempt_number int,
  cashfree_reference_id text,
  amount_rupees numeric,
  attempt_status text,
  failure_reason text,
  failure_code text,
  submitted_at timestamptz,
  completed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT a.id, a.engineer_payout_id, a.attempt_number, a.cashfree_reference_id,
         a.amount_rupees, a.attempt_status, a.failure_reason, a.failure_code,
         a.submitted_at, a.completed_at
  FROM public.founder_cashfree_payout_attempts a
  WHERE (p_status IS NULL OR a.attempt_status = p_status)
  ORDER BY a.submitted_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cashfree_v3_attempts_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cashfree_v3_attempts_recent(text, int) TO authenticated;

-- ============================================================================
-- RPC 3: webhooks_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cashfree_v3_webhooks_recent(int);
CREATE OR REPLACE FUNCTION public.founder_cashfree_v3_webhooks_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  event_id text,
  event_kind text,
  payout_attempt_id uuid,
  signature_valid boolean,
  received_at timestamptz,
  processed_at timestamptz,
  processing_outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT w.id, w.event_id, w.event_kind, w.payout_attempt_id,
         w.signature_valid, w.received_at, w.processed_at, w.processing_outcome
  FROM public.founder_cashfree_webhook_events w
  ORDER BY w.received_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cashfree_v3_webhooks_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cashfree_v3_webhooks_recent(int) TO authenticated;

-- ============================================================================
-- RPC 4: reconciliation_runs_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cashfree_v3_reconciliation_runs_recent(int);
CREATE OR REPLACE FUNCTION public.founder_cashfree_v3_reconciliation_runs_recent(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  run_date date,
  run_kind text,
  total_payouts_processed int,
  total_attempts_made int,
  total_succeeded int,
  total_failed int,
  total_amount_rupees numeric,
  total_amount_succeeded_rupees numeric,
  discrepancies_found int,
  discrepancy_amount_rupees numeric,
  run_status text,
  started_at timestamptz,
  completed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT r.id, r.run_date, r.run_kind, r.total_payouts_processed, r.total_attempts_made,
         r.total_succeeded, r.total_failed, r.total_amount_rupees, r.total_amount_succeeded_rupees,
         r.discrepancies_found, r.discrepancy_amount_rupees, r.run_status,
         r.started_at, r.completed_at
  FROM public.founder_cashfree_reconciliation_runs r
  ORDER BY r.run_date DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cashfree_v3_reconciliation_runs_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cashfree_v3_reconciliation_runs_recent(int) TO authenticated;

-- ============================================================================
-- RPC 5: discrepancies
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cashfree_v3_discrepancies();
CREATE OR REPLACE FUNCTION public.founder_cashfree_v3_discrepancies()
RETURNS TABLE (
  attempt_id uuid,
  engineer_payout_id uuid,
  attempt_number int,
  cashfree_reference_id text,
  amount_rupees numeric,
  attempt_status text,
  failure_reason text,
  submitted_at timestamptz,
  hours_stale numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT a.id, a.engineer_payout_id, a.attempt_number, a.cashfree_reference_id,
         a.amount_rupees, a.attempt_status, a.failure_reason, a.submitted_at,
         EXTRACT(EPOCH FROM (now() - a.submitted_at))/3600.0::numeric AS hours_stale
  FROM public.founder_cashfree_payout_attempts a
  WHERE a.attempt_status = 'manual_intervention'
     OR (a.attempt_status = 'submitted' AND a.submitted_at < now() - interval '24 hours')
     OR (a.attempt_status = 'pending' AND a.submitted_at < now() - interval '24 hours')
  ORDER BY a.submitted_at ASC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cashfree_v3_discrepancies() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cashfree_v3_discrepancies() TO authenticated;

-- ============================================================================
-- RPC 6: log record_attempt
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_cashfree_v3_record_attempt(uuid, numeric, jsonb);
CREATE OR REPLACE FUNCTION public.log_founder_cashfree_v3_record_attempt(
  p_payout_id uuid,
  p_amount numeric,
  p_payload jsonb
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_next_attempt int;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT COALESCE(MAX(attempt_number), 0) + 1 INTO v_next_attempt
  FROM public.founder_cashfree_payout_attempts
  WHERE engineer_payout_id = p_payout_id;

  INSERT INTO public.founder_cashfree_payout_attempts (
    engineer_payout_id, attempt_number, amount_rupees, attempt_status, request_payload
  ) VALUES (
    p_payout_id, v_next_attempt, p_amount, 'pending', p_payload
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cashfree_v3_record_attempt(uuid, numeric, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cashfree_v3_record_attempt(uuid, numeric, jsonb) TO authenticated;

-- ============================================================================
-- RPC 7: log record_webhook
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_cashfree_v3_record_webhook(text, text, uuid, boolean, jsonb);
CREATE OR REPLACE FUNCTION public.log_founder_cashfree_v3_record_webhook(
  p_event_id text,
  p_kind text,
  p_payout_id uuid,
  p_signature_ok boolean,
  p_payload jsonb
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_outcome text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF EXISTS (SELECT 1 FROM public.founder_cashfree_webhook_events WHERE event_id = p_event_id) THEN
    RETURN NULL;
  END IF;

  v_outcome := CASE
    WHEN p_signature_ok = false THEN 'invalid_signature'
    WHEN p_payout_id IS NULL THEN 'unknown_reference'
    ELSE 'processed'
  END;

  INSERT INTO public.founder_cashfree_webhook_events (
    event_id, event_kind, payout_attempt_id, signature_valid, raw_payload,
    processed_at, processing_outcome
  ) VALUES (
    p_event_id, p_kind, p_payout_id, p_signature_ok, p_payload,
    now(), v_outcome
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cashfree_v3_record_webhook(text, text, uuid, boolean, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cashfree_v3_record_webhook(text, text, uuid, boolean, jsonb) TO authenticated;

-- ============================================================================
-- RPC 8: log kickoff_reconciliation
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_cashfree_v3_kickoff_reconciliation(text);
CREATE OR REPLACE FUNCTION public.log_founder_cashfree_v3_kickoff_reconciliation(p_run_kind text DEFAULT 'daily_auto')
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_today date := CURRENT_DATE;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_cashfree_reconciliation_runs (run_date, run_kind, run_status)
  VALUES (v_today, p_run_kind, 'running')
  ON CONFLICT (run_date) DO UPDATE
    SET run_status = 'running',
        started_at = now(),
        run_kind = EXCLUDED.run_kind
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cashfree_v3_kickoff_reconciliation(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cashfree_v3_kickoff_reconciliation(text) TO authenticated;

-- ============================================================================
-- RPC 9: log record_attempt_outcome
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_cashfree_v3_record_attempt_outcome(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_cashfree_v3_record_attempt_outcome(
  p_attempt_id uuid,
  p_status text,
  p_failure_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF p_status NOT IN ('pending','submitted','succeeded','failed','timeout','reverted','manual_intervention') THEN
    RAISE EXCEPTION 'invalid status: %', p_status USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_cashfree_payout_attempts
  SET attempt_status = p_status,
      failure_reason = COALESCE(p_failure_reason, failure_reason),
      completed_at = CASE WHEN p_status IN ('succeeded','failed','timeout','reverted') THEN now() ELSE completed_at END
  WHERE id = p_attempt_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cashfree_v3_record_attempt_outcome(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cashfree_v3_record_attempt_outcome(uuid, text, text) TO authenticated;

COMMIT;