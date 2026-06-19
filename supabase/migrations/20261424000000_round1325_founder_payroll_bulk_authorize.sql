BEGIN;
-- Round 1325 — /founder-payroll-bulk-authorize
--
-- Heavy founder-facing surface to bulk-authorize engineer payouts.
-- Until Cashfree KYC activates, an "authorized" batch just flips the
-- existing per-payout cron consumer on — the cron picks queued rows
-- one-by-one. This page gives the founder an atomic, audit-trail-stamped
-- way to say "yes, release this whole period's worth of payouts."
--
-- Schema notes (verified against migrations/):
--   - engineer_payouts.amount_paise (bigint, NOT NULL, CHECK > 0)
--     AND engineer_payouts.amount_rupees (generated, r856) — we use _rupees
--   - engineer_payouts.queued_at (timestamptz)
--   - engineer_payouts.status text CHECK ('queued','processing','processed','failed','cancelled')
--   - engineers.verification_status is an enum — cast ::text
--   - engineers.payout_method_set: DOES NOT EXIST. We approximate the
--     "method ready" check via engineer_payouts.payout_method_id IS NOT NULL
--     (the existing per-payout cron uses the same gate at idx_engineer_payouts_queued).
--

-- ---------------------------------------------------------------------
-- 1. founder_payroll_batches — audit-trail table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_payroll_batches (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_label            text NOT NULL UNIQUE,
  period_start           date NOT NULL,
  period_end             date NOT NULL,
  total_payouts_count    int  NOT NULL,
  total_amount_rupees    numeric NOT NULL,
  authorized_at          timestamptz,
  authorized_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status                 text NOT NULL DEFAULT 'draft'
                           CHECK (status IN (
                             'draft','authorized','submitted_to_cashfree',
                             'partial_complete','complete','reverted'
                           )),
  payout_ids             uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  failure_reasons        jsonb  NOT NULL DEFAULT '{}'::jsonb,
  completed_at           timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT founder_payroll_batches_period_chk CHECK (period_end >= period_start)
);

CREATE INDEX IF NOT EXISTS idx_founder_payroll_batches_created
  ON public.founder_payroll_batches (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_payroll_batches_status
  ON public.founder_payroll_batches (status, created_at DESC);

REVOKE ALL ON public.founder_payroll_batches FROM PUBLIC, anon;

-- Lock writes to the helpers below. We expose SELECT to authenticated
-- but the RPCs already gate on is_founder() so non-founder reads
-- return 0 rows from the RPCs anyway. The table itself is admin-only.
REVOKE INSERT, UPDATE, DELETE ON public.founder_payroll_batches FROM authenticated;
GRANT  SELECT ON public.founder_payroll_batches TO authenticated;

-- ---------------------------------------------------------------------
-- 2. founder_payroll_batch_dryrun — what would a batch for this window look like?
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payroll_batch_dryrun(date, date);
CREATE OR REPLACE FUNCTION public.founder_payroll_batch_dryrun(
  p_period_start date,
  p_period_end   date
)
RETURNS TABLE (
  candidate_payout_count              bigint,
  total_amount_rupees                 numeric,
  engineer_count                      bigint,
  median_payout_rupees                numeric,
  largest_payout_rupees               numeric,
  smallest_payout_rupees              numeric,
  payouts_blocked_missing_kyc         bigint,
  payouts_blocked_missing_upi_or_bank bigint,
  payouts_blocked_disputed            bigint,
  payouts_ok_to_authorize             bigint,
  sample_top_5_amounts                jsonb
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
  WITH base AS (
    SELECT
      p.id,
      p.engineer_user_id,
      p.amount_rupees::numeric                                  AS amt,
      coalesce(e.verification_status::text, 'pending')          AS vstatus,
      (p.payout_method_id IS NOT NULL)                          AS has_method,
      EXISTS (
        SELECT 1
        FROM public.repair_job_disputes d
        WHERE d.repair_job_id = p.repair_job_id
          AND d.status::text IN ('open','under_review','escalated')
      ) AS is_disputed
    FROM public.engineer_payouts p
    LEFT JOIN public.engineers e
      ON e.user_id = p.engineer_user_id
    WHERE p.status = 'queued'
      AND p.queued_at >= p_period_start::timestamptz
      AND p.queued_at <  (p_period_end + 1)::timestamptz
  )
  SELECT
    coalesce(count(*), 0)::bigint                              AS candidate_payout_count,
    coalesce(sum(amt), 0)::numeric                             AS total_amount_rupees,
    coalesce(count(DISTINCT engineer_user_id), 0)::bigint      AS engineer_count,
    coalesce(percentile_cont(0.5) WITHIN GROUP (ORDER BY amt), 0)::numeric
                                                               AS median_payout_rupees,
    coalesce(max(amt), 0)::numeric                             AS largest_payout_rupees,
    coalesce(min(amt), 0)::numeric                             AS smallest_payout_rupees,
    coalesce(count(*) FILTER (WHERE vstatus <> 'verified'), 0)::bigint
                                                               AS payouts_blocked_missing_kyc,
    coalesce(count(*) FILTER (WHERE NOT has_method), 0)::bigint
                                                               AS payouts_blocked_missing_upi_or_bank,
    coalesce(count(*) FILTER (WHERE is_disputed), 0)::bigint   AS payouts_blocked_disputed,
    coalesce(count(*) FILTER (
      WHERE vstatus = 'verified' AND has_method AND NOT is_disputed
    ), 0)::bigint                                              AS payouts_ok_to_authorize,
    coalesce((
      SELECT jsonb_agg(jsonb_build_object('payout_id', id, 'amount_rupees', amt)
                       ORDER BY amt DESC)
      FROM (
        SELECT id, amt FROM base ORDER BY amt DESC LIMIT 5
      ) t
    ), '[]'::jsonb)                                            AS sample_top_5_amounts
  FROM base;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payroll_batch_dryrun(date, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payroll_batch_dryrun(date, date) TO authenticated;

-- ---------------------------------------------------------------------
-- 3. founder_payroll_batches_recent
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payroll_batches_recent(int);
CREATE OR REPLACE FUNCTION public.founder_payroll_batches_recent(p_limit int DEFAULT 20)
RETURNS TABLE (
  id                  uuid,
  batch_label         text,
  period_start        date,
  period_end          date,
  total_payouts_count int,
  total_amount_rupees numeric,
  status              text,
  authorized_at       timestamptz,
  completed_at        timestamptz,
  created_at          timestamptz
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
    b.id, b.batch_label, b.period_start, b.period_end,
    b.total_payouts_count, b.total_amount_rupees,
    b.status::text, b.authorized_at, b.completed_at, b.created_at
  FROM public.founder_payroll_batches b
  ORDER BY b.created_at DESC
  LIMIT greatest(coalesce(p_limit, 20), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payroll_batches_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payroll_batches_recent(int) TO authenticated;

-- ---------------------------------------------------------------------
-- 4. log_founder_payroll_batch_create — materialize a draft batch
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_payroll_batch_create(date, date);
CREATE OR REPLACE FUNCTION public.log_founder_payroll_batch_create(
  p_period_start date,
  p_period_end   date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id        uuid;
  v_label     text;
  v_ids       uuid[];
  v_count     int;
  v_total     numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_period_end < p_period_start THEN
    RAISE EXCEPTION 'period_end must be >= period_start';
  END IF;

  SELECT
    coalesce(array_agg(p.id ORDER BY p.queued_at), ARRAY[]::uuid[]),
    coalesce(count(*), 0)::int,
    coalesce(sum(p.amount_rupees), 0)::numeric
  INTO v_ids, v_count, v_total
  FROM public.engineer_payouts p
  LEFT JOIN public.engineers e ON e.user_id = p.engineer_user_id
  WHERE p.status = 'queued'
    AND p.queued_at >= p_period_start::timestamptz
    AND p.queued_at <  (p_period_end + 1)::timestamptz
    AND coalesce(e.verification_status::text, 'pending') = 'verified'
    AND p.payout_method_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.repair_job_disputes d
      WHERE d.repair_job_id = p.repair_job_id
        AND d.status::text IN ('open','under_review','escalated')
    );

  v_label := 'payroll-' || to_char(p_period_start, 'YYYYMMDD') || '-'
                       || to_char(p_period_end,   'YYYYMMDD') || '-'
                       || to_char(now() AT TIME ZONE 'Asia/Kolkata', 'HH24MISS');

  INSERT INTO public.founder_payroll_batches (
    batch_label, period_start, period_end,
    total_payouts_count, total_amount_rupees,
    payout_ids, status
  )
  VALUES (
    v_label, p_period_start, p_period_end,
    v_count, v_total, v_ids, 'draft'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_payroll_batch_create(date, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_payroll_batch_create(date, date) TO authenticated;

-- ---------------------------------------------------------------------
-- 5. log_founder_payroll_batch_authorize
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_payroll_batch_authorize(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_payroll_batch_authorize(p_batch_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_payroll_batches
  SET status        = 'authorized',
      authorized_at = now(),
      authorized_by = auth.uid(),
      updated_at    = now()
  WHERE id = p_batch_id
    AND status = 'draft';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'batch % not in draft state', p_batch_id USING ERRCODE = '22023';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_payroll_batch_authorize(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_payroll_batch_authorize(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- 6. log_founder_payroll_batch_status — generic state transition
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_payroll_batch_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_payroll_batch_status(
  p_batch_id   uuid,
  p_new_status text,
  p_note       text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_new_status NOT IN (
    'draft','authorized','submitted_to_cashfree',
    'partial_complete','complete','reverted'
  ) THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_payroll_batches
  SET status          = p_new_status,
      completed_at    = CASE WHEN p_new_status IN ('complete','reverted')
                             THEN now() ELSE completed_at END,
      failure_reasons = CASE WHEN p_note IS NOT NULL
                             THEN failure_reasons || jsonb_build_object(
                               'note_' || to_char(now(), 'YYYYMMDDHH24MISS'), p_note)
                             ELSE failure_reasons END,
      updated_at      = now()
  WHERE id = p_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'batch % not found', p_batch_id USING ERRCODE = '02000';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_payroll_batch_status(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_payroll_batch_status(uuid, text, text) TO authenticated;

COMMIT;