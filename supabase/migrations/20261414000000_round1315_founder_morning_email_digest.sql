BEGIN;

-- ============================================================================
-- r1315 — Founder morning email digest v2 (preview + log + RPC)
-- ============================================================================
-- Renders what the 07:30 IST morning email WILL contain. Backed by a single
-- RPC that aggregates priority actions, MRR snapshot + deltas, active alerts,
-- 24h milestones, and cron health into one JSONB payload.
--
-- IMPORTANT: founder_morning_digest_v2() is gated by is_founder() and
-- therefore MUST NOT be called from pg_cron (no JWT). Call it from an edge
-- function or the founder console page (server-side, with JWT).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Delivery log table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_morning_digest_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sent_at         timestamptz NOT NULL DEFAULT now(),
  payload         jsonb       NOT NULL,
  recipient_email text        NOT NULL,
  delivery_status text        NOT NULL DEFAULT 'pending'
                  CHECK (delivery_status IN ('pending','sent','failed','skipped')),
  failure_reason  text
);

CREATE INDEX IF NOT EXISTS founder_morning_digest_log_sent_at_idx
  ON public.founder_morning_digest_log (sent_at DESC);

ALTER TABLE public.founder_morning_digest_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_morning_digest_log_founder_select
  ON public.founder_morning_digest_log;
CREATE POLICY founder_morning_digest_log_founder_select
  ON public.founder_morning_digest_log
  FOR SELECT
  USING (public.is_founder());

REVOKE ALL ON public.founder_morning_digest_log FROM PUBLIC, anon;
GRANT  SELECT ON public.founder_morning_digest_log TO authenticated;

-- ---------------------------------------------------------------------------
-- Main RPC: founder_morning_digest_v2()
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_morning_digest_v2();

CREATE OR REPLACE FUNCTION public.founder_morning_digest_v2()
RETURNS TABLE (
  top_actions          jsonb,
  mrr_today            numeric,
  mrr_yesterday        numeric,
  mrr_7d_ago           numeric,
  mrr_30d_ago          numeric,
  mrr_delta_pct_dod    numeric,
  mrr_delta_pct_wow    numeric,
  active_alerts        jsonb,
  milestones_24h       jsonb,
  cron_health          jsonb,
  generated_at         timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_actions   jsonb;
  v_mrr_today     numeric;
  v_mrr_yest      numeric;
  v_mrr_7d        numeric;
  v_mrr_30d       numeric;
  v_alerts        jsonb;
  v_milestones    jsonb;
  v_cron          jsonb;
  v_code_red      int;
  v_stuck_payouts int;
  v_open_inc      int;
  v_jobs_24h      int;
  v_amcs_24h      int;
  v_payouts_24h   int;
  v_cron_fails    int := 0;
  v_cron_total    int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Top 10 priority actions (inline so we don't recurse through another SECDEF)
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.priority_score DESC), '[]'::jsonb)
    INTO v_top_actions
  FROM (
    SELECT
      'code_red'::text        AS action_type,
      cr.id::text             AS ref_id,
      cr.equipment_label      AS title,
      cr.minutes_open         AS metric,
      (100 + COALESCE(cr.minutes_open, 0))::numeric AS priority_score
    FROM public.code_red_requests cr
    WHERE cr.status NOT IN ('resolved','timed_out')
    UNION ALL
    SELECT
      'stuck_payout'::text,
      ep.id::text,
      'Payout queued >14d · ' || (ep.amount_rupees::text) || ' INR',
      EXTRACT(EPOCH FROM (now() - ep.created_at))::int / 86400,
      (60 + EXTRACT(EPOCH FROM (now() - ep.created_at))::numeric / 86400)
    FROM public.engineer_payouts ep
    WHERE ep.status = 'queued'
      AND ep.created_at < now() - interval '14 days'
    UNION ALL
    SELECT
      'open_incident'::text,
      fi.id::text,
      COALESCE(fi.title, 'Incident'),
      EXTRACT(EPOCH FROM (now() - fi.created_at))::int / 3600,
      (80 + EXTRACT(EPOCH FROM (now() - fi.created_at))::numeric / 3600)
    FROM public.founder_incidents fi
    WHERE fi.status = 'open'
    LIMIT 10
  ) t;

  -- MRR today: sum monthly_fee_rupees across active contracts
  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_mrr_today
  FROM public.amc_contracts
  WHERE status = 'active';

  -- MRR yesterday: contracts activated before yesterday and not deactivated by then
  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_mrr_yest
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '1 day'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '1 day');

  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_mrr_7d
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '7 days'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '7 days');

  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_mrr_30d
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '30 days'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '30 days');

  -- Active alert counts
  SELECT count(*) INTO v_code_red
  FROM public.code_red_requests
  WHERE status NOT IN ('resolved','timed_out');

  SELECT count(*) INTO v_stuck_payouts
  FROM public.engineer_payouts
  WHERE status = 'queued' AND created_at < now() - interval '14 days';

  SELECT count(*) INTO v_open_inc
  FROM public.founder_incidents
  WHERE status = 'open';

  v_alerts := jsonb_build_array(
    jsonb_build_object('kind','code_red_open',     'count', v_code_red,      'severity','critical'),
    jsonb_build_object('kind','stuck_payouts_14d', 'count', v_stuck_payouts, 'severity','high'),
    jsonb_build_object('kind','open_incidents',    'count', v_open_inc,      'severity','high')
  );

  -- Milestones (last 24h)
  SELECT count(*) INTO v_jobs_24h
  FROM public.repair_jobs
  WHERE status = 'completed' AND completed_at > now() - interval '24 hours';

  SELECT count(*) INTO v_amcs_24h
  FROM public.amc_contracts
  WHERE activated_at > now() - interval '24 hours';

  SELECT count(*) INTO v_payouts_24h
  FROM public.engineer_payouts
  WHERE status = 'paid_out' AND updated_at > now() - interval '24 hours';

  v_milestones := jsonb_build_array(
    jsonb_build_object('kind','jobs_completed',  'count', v_jobs_24h),
    jsonb_build_object('kind','amcs_activated',  'count', v_amcs_24h),
    jsonb_build_object('kind','payouts_paid',    'count', v_payouts_24h)
  );

  -- Cron health (best-effort; cron schema may not be visible)
  BEGIN
    EXECUTE $q$
      SELECT
        count(*) FILTER (WHERE status = 'failed'),
        count(*)
      FROM cron.job_run_details
      WHERE start_time > now() - interval '24 hours'
    $q$ INTO v_cron_fails, v_cron_total;
  EXCEPTION WHEN OTHERS THEN
    v_cron_fails := 0;
    v_cron_total := 0;
  END;

  v_cron := jsonb_build_object(
    'runs_24h',     v_cron_total,
    'failures_24h', v_cron_fails,
    'failure_rate', CASE WHEN v_cron_total > 0
                         THEN ROUND((v_cron_fails::numeric / v_cron_total::numeric) * 100, 2)
                         ELSE 0 END
  );

  RETURN QUERY SELECT
    v_top_actions,
    v_mrr_today,
    v_mrr_yest,
    v_mrr_7d,
    v_mrr_30d,
    CASE WHEN v_mrr_yest > 0
         THEN ROUND(((v_mrr_today - v_mrr_yest) / v_mrr_yest) * 100, 2)
         ELSE 0 END,
    CASE WHEN v_mrr_7d > 0
         THEN ROUND(((v_mrr_today - v_mrr_7d) / v_mrr_7d) * 100, 2)
         ELSE 0 END,
    v_alerts,
    v_milestones,
    v_cron,
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_morning_digest_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_morning_digest_v2() TO authenticated;

COMMENT ON FUNCTION public.founder_morning_digest_v2() IS
  'Founder morning digest payload. DO NOT call from pg_cron (no JWT — is_founder() will fail). Call from edge fn or page server-side.';

-- ---------------------------------------------------------------------------
-- Logging RPC
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_morning_digest_sent(jsonb, text, text, text);

CREATE OR REPLACE FUNCTION public.log_founder_morning_digest_sent(
  p_payload   jsonb,
  p_recipient text,
  p_status    text,
  p_reason    text DEFAULT NULL
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
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_status NOT IN ('pending','sent','failed','skipped') THEN
    RAISE EXCEPTION 'invalid delivery_status: %', p_status;
  END IF;

  INSERT INTO public.founder_morning_digest_log
    (payload, recipient_email, delivery_status, failure_reason)
  VALUES
    (p_payload, p_recipient, p_status, p_reason)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_morning_digest_sent(jsonb, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_morning_digest_sent(jsonb, text, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Recent log RPC
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_morning_digest_recent(int);

CREATE OR REPLACE FUNCTION public.founder_morning_digest_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  id              uuid,
  sent_at         timestamptz,
  recipient_email text,
  delivery_status text,
  failure_reason  text,
  payload_summary jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    l.id,
    l.sent_at,
    l.recipient_email,
    l.delivery_status,
    l.failure_reason,
    jsonb_build_object(
      'mrr_today',     l.payload -> 'mrr_today',
      'top_action_n',  jsonb_array_length(COALESCE(l.payload -> 'top_actions', '[]'::jsonb))
    ) AS payload_summary
  FROM public.founder_morning_digest_log l
  ORDER BY l.sent_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 30), 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_morning_digest_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_morning_digest_recent(int) TO authenticated;

COMMIT;