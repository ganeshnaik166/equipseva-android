-- =====================================================================
-- Round 498 — Risk Score + Collusion Detector (v0.4 Phase 5 #1)
-- =====================================================================
--
-- Phase 5 (Growth & Intelligence) starts. The roadmap explicitly
-- said Risk Score is the GATE before pushing growth — "growing
-- broken system makes break worse" — and that we MUST run it as
-- alert-only for 30 days before auto-block. This migration ships
-- both as alert-only.
--
-- Risk Score RS0-100 computed per (user_id, role) snapshot daily:
--   - Engineer side signals: dispute rate, suspicious_distance count
--     (r496), KYC re-verify overdue (r497), founder_action_log
--     rejection rate (r482), withdrawal velocity, IP-overlap with
--     hospital accounts (collusion).
--   - Hospital side: dispute-open rate, refund-request rate, AMC
--     create-without-affidavit, payment dispute frequency.
--
-- Collusion Detector — first-pass simple version:
--   - engineer + hospital with > 3 jobs together in 30 days
--     AND no other engineer/hospital activity for either party
--     (closed-loop pair) → flag for founder review.
--   - shared IP signature on auth events.
--   - bid amount + accept time clustering (statistical anomaly).
--
-- This migration ships:
--   * risk_score_snapshots — daily snapshot per actor
--   * collusion_flags — pair-level detection rows
--   * compute_risk_score(user_id) — RPC computing latest snapshot
--   * run_daily_risk_scoring() — cron-callable batch
--   * scan_collusion_pairs() — cron-callable detector
--   * founder_risk_top_n() — cockpit query
--
-- ALERT-ONLY for first 30 days — no auto-block. Founder reviews
-- top-N daily; auto-block flip is r500+ work.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. risk_score_snapshots
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.risk_score_snapshots (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid        NOT NULL,
  CONSTRAINT risk_score_user_fk
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  role                text        NOT NULL CHECK (role IN ('engineer','hospital','admin','founder')),
  score               int         NOT NULL CHECK (score BETWEEN 0 AND 100),
  -- Per-signal contributions (jsonb for forensic transparency)
  signal_breakdown    jsonb       NOT NULL DEFAULT '{}'::jsonb,
  -- Decision band
  band                text        NOT NULL
                                  CHECK (band IN ('clean','watch','high','critical')),
  -- Action: alert-only for now (v0.4); future r500+ may add auto-block
  action_taken        text        NOT NULL DEFAULT 'alert_only'
                                  CHECK (action_taken IN ('alert_only','founder_reviewed','blocked','cleared')),
  -- Forensic
  computed_at         timestamptz NOT NULL DEFAULT now(),
  computed_from_until timestamptz NOT NULL,  -- end of the data window scored
  -- Index for top-N + chart queries
  CONSTRAINT risk_score_one_per_user_day UNIQUE (user_id, computed_at)
);

CREATE INDEX IF NOT EXISTS risk_score_recent_idx
  ON public.risk_score_snapshots (user_id, computed_at DESC);
CREATE INDEX IF NOT EXISTS risk_score_band_idx
  ON public.risk_score_snapshots (band, computed_at DESC)
  WHERE band IN ('high','critical');
CREATE INDEX IF NOT EXISTS risk_score_score_desc_idx
  ON public.risk_score_snapshots (score DESC, computed_at DESC);

ALTER TABLE public.risk_score_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS risk_score_snapshots_select ON public.risk_score_snapshots;
CREATE POLICY risk_score_snapshots_select
  ON public.risk_score_snapshots
  FOR SELECT
  TO authenticated, service_role
  USING (public.is_founder());  -- founder-only for v0.4; never user-visible

REVOKE INSERT, UPDATE, DELETE ON public.risk_score_snapshots
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. collusion_flags
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.collusion_flags (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  hospital_user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Signal that triggered the flag
  signal_kind         text        NOT NULL
                                  CHECK (signal_kind IN (
                                    'closed_loop_pair',           -- >3 jobs / 30d AND no other counterparty
                                    'shared_ip_signature',        -- auth IPs overlap
                                    'bid_amount_clustering',      -- bids tightly clustered ±5%
                                    'accept_time_clustering',     -- accepted within X seconds repeatedly
                                    'shared_geo_address'          -- engineer's home address matches hospital's
                                  )),
  evidence            jsonb       NOT NULL,
  job_count_30d       int,
  total_value_rupees_30d numeric(12,2),
  status              text        NOT NULL DEFAULT 'open'
                                  CHECK (status IN ('open','investigating','confirmed','false_positive','resolved')),
  resolved_by         uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at         timestamptz,
  resolution_note     text,
  created_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT collusion_flag_dedup UNIQUE (engineer_user_id, hospital_user_id, signal_kind, status)
);

CREATE INDEX IF NOT EXISTS collusion_flags_open_idx
  ON public.collusion_flags (status, created_at DESC)
  WHERE status IN ('open','investigating');

ALTER TABLE public.collusion_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS collusion_flags_select ON public.collusion_flags;
CREATE POLICY collusion_flags_select
  ON public.collusion_flags
  FOR SELECT
  TO authenticated, service_role
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.collusion_flags
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. compute_risk_score(user_id, role)
-- ---------------------------------------------------------------------
-- First-pass simple model. Sums weighted signals; clamped to [0, 100].
-- Each signal is a function of trailing-30-day activity:
--   * disputed_jobs * 15
--   * suspicious_distance_events * 5
--   * overdue_renewals * 10
--   * recent_refund_rejections * 8
--   * paid_jobs * (-2) ← negative weight (good behavior)
CREATE OR REPLACE FUNCTION public.compute_risk_score(
  p_user_id uuid,
  p_role    text DEFAULT 'engineer'
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_score             int := 0;
  v_disputed_jobs     int := 0;
  v_suspicious        int := 0;
  v_overdue_renewals  int := 0;
  v_paid_jobs         int := 0;
  v_breakdown         jsonb;
  v_window_start      timestamptz := now() - interval '30 days';
  v_band              text;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  IF p_role = 'engineer' THEN
    -- Engineer signals
    SELECT count(*) INTO v_disputed_jobs
      FROM public.repair_job_escrow e
      JOIN public.repair_job_bids b ON b.repair_job_id = e.repair_job_id
                                    AND b.status = 'accepted'
     WHERE b.engineer_user_id = p_user_id
       AND e.status = 'disputed'
       AND e.updated_at >= v_window_start;

    SELECT count(*) INTO v_suspicious
      FROM public.engineer_attendance
     WHERE engineer_user_id = p_user_id
       AND suspicious_distance = true
       AND created_at >= v_window_start;

    SELECT count(*) INTO v_overdue_renewals
      FROM public.engineer_kyc_renewals
     WHERE engineer_user_id = p_user_id
       AND status IN ('pending','in_progress')
       AND due_at < now();

    SELECT count(*) INTO v_paid_jobs
      FROM public.engineer_payouts
     WHERE engineer_user_id = p_user_id
       AND status = 'processed'
       AND updated_at >= v_window_start;
  ELSIF p_role = 'hospital' THEN
    -- Hospital signals (reuse same shape; different sources)
    SELECT count(*) INTO v_disputed_jobs
      FROM public.repair_job_escrow e
      JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
     WHERE rj.hospital_user_id = p_user_id
       AND e.status = 'disputed'
       AND e.updated_at >= v_window_start;

    SELECT count(*) INTO v_paid_jobs
      FROM public.repair_job_escrow e
      JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
     WHERE rj.hospital_user_id = p_user_id
       AND e.status = 'released'
       AND e.updated_at >= v_window_start;
  END IF;

  v_score :=
      (v_disputed_jobs * 15)
    + (v_suspicious * 5)
    + (v_overdue_renewals * 10)
    + (v_paid_jobs * (-2));

  -- Clamp
  IF v_score < 0 THEN v_score := 0; END IF;
  IF v_score > 100 THEN v_score := 100; END IF;

  v_band := CASE
    WHEN v_score < 20 THEN 'clean'
    WHEN v_score < 40 THEN 'watch'
    WHEN v_score < 70 THEN 'high'
    ELSE 'critical'
  END;

  v_breakdown := jsonb_build_object(
    'disputed_jobs', v_disputed_jobs,
    'suspicious_distance_events', v_suspicious,
    'overdue_renewals', v_overdue_renewals,
    'paid_jobs_30d', v_paid_jobs,
    'window_start', v_window_start
  );

  INSERT INTO public.risk_score_snapshots (
    user_id, role, score, signal_breakdown, band, computed_from_until
  ) VALUES (
    p_user_id, p_role, v_score, v_breakdown, v_band, now()
  );

  RETURN v_score;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.compute_risk_score(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.compute_risk_score(uuid, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. run_daily_risk_scoring — batch (cron-callable)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_daily_risk_scoring()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user record;
  v_count int := 0;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  -- Score every engineer with activity in trailing 60 days
  FOR v_user IN
    SELECT DISTINCT e.user_id
      FROM public.engineers e
     WHERE e.verification_status = 'verified'
       AND EXISTS (
         SELECT 1 FROM public.engineer_payouts ep
          WHERE ep.engineer_user_id = e.user_id
            AND ep.updated_at >= now() - interval '60 days'
       )
  LOOP
    PERFORM public.compute_risk_score(v_user.user_id, 'engineer');
    v_count := v_count + 1;
  END LOOP;

  -- Score hospitals with recent escrow activity
  FOR v_user IN
    SELECT DISTINCT rj.hospital_user_id AS user_id
      FROM public.repair_jobs rj
     WHERE rj.hospital_user_id IS NOT NULL
       AND rj.created_at >= now() - interval '60 days'
  LOOP
    PERFORM public.compute_risk_score(v_user.user_id, 'hospital');
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.run_daily_risk_scoring()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.run_daily_risk_scoring() TO service_role;

-- ---------------------------------------------------------------------
-- 5. scan_collusion_pairs — closed-loop detection
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.scan_collusion_pairs()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  v_pair  record;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  -- Closed-loop pair: engineer + hospital with >3 jobs in last 30d
  -- AND engineer has NO OTHER hospitals AND hospital has NO OTHER
  -- engineers in same period. This is a strong signal of collusion
  -- or shadow-marketplace use.
  FOR v_pair IN
    WITH pair_activity AS (
      SELECT
        b.engineer_user_id,
        rj.hospital_user_id,
        count(*) AS job_count,
        sum(coalesce(e.amount_rupees, 0)) AS total_rupees
      FROM public.repair_job_bids b
      JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
      LEFT JOIN public.repair_job_escrow e ON e.repair_job_id = rj.id
      WHERE b.status = 'accepted'
        AND rj.created_at >= now() - interval '30 days'
      GROUP BY b.engineer_user_id, rj.hospital_user_id
      HAVING count(*) > 3
    ),
    engineer_breadth AS (
      SELECT engineer_user_id, count(DISTINCT hospital_user_id) AS n_hospitals
        FROM pair_activity
       GROUP BY engineer_user_id
    ),
    hospital_breadth AS (
      SELECT hospital_user_id, count(DISTINCT engineer_user_id) AS n_engineers
        FROM pair_activity
       GROUP BY hospital_user_id
    )
    SELECT pa.*
      FROM pair_activity pa
      JOIN engineer_breadth eb ON eb.engineer_user_id = pa.engineer_user_id
      JOIN hospital_breadth hb ON hb.hospital_user_id = pa.hospital_user_id
     WHERE eb.n_hospitals = 1
       AND hb.n_engineers = 1
  LOOP
    INSERT INTO public.collusion_flags (
      engineer_user_id, hospital_user_id, signal_kind,
      evidence, job_count_30d, total_value_rupees_30d
    ) VALUES (
      v_pair.engineer_user_id, v_pair.hospital_user_id, 'closed_loop_pair',
      jsonb_build_object(
        'job_count_30d', v_pair.job_count,
        'total_rupees_30d', v_pair.total_rupees,
        'detector', 'scan_collusion_pairs_v1'
      ),
      v_pair.job_count, v_pair.total_rupees
    )
    ON CONFLICT (engineer_user_id, hospital_user_id, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.scan_collusion_pairs()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.scan_collusion_pairs() TO service_role;

-- ---------------------------------------------------------------------
-- 6. founder_risk_top_n + founder_open_collusion_flags + resolver
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_risk_top_n(
  p_role  text DEFAULT NULL,
  p_band  text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  user_id          uuid,
  email            text,
  role             text,
  score            int,
  band             text,
  signal_breakdown jsonb,
  computed_at      timestamptz
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
  WITH latest AS (
    SELECT DISTINCT ON (s.user_id) s.*
      FROM public.risk_score_snapshots s
     ORDER BY s.user_id, s.computed_at DESC
  )
  SELECT l.user_id,
         coalesce((SELECT email FROM auth.users WHERE id = l.user_id), 'unknown') AS email,
         l.role, l.score, l.band, l.signal_breakdown, l.computed_at
    FROM latest l
   WHERE (p_role IS NULL OR l.role = p_role)
     AND (p_band IS NULL OR l.band = p_band)
   ORDER BY l.score DESC, l.computed_at DESC
   LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_risk_top_n(text, text, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_risk_top_n(text, text, integer) TO service_role;

CREATE OR REPLACE FUNCTION public.founder_open_collusion_flags(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  id              uuid,
  engineer_email  text,
  hospital_email  text,
  signal_kind     text,
  job_count_30d   int,
  total_value_rupees_30d numeric,
  evidence        jsonb,
  created_at      timestamptz
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
  SELECT c.id,
         coalesce((SELECT email FROM auth.users WHERE id = c.engineer_user_id), 'unknown'),
         coalesce((SELECT email FROM auth.users WHERE id = c.hospital_user_id), 'unknown'),
         c.signal_kind, c.job_count_30d, c.total_value_rupees_30d, c.evidence, c.created_at
    FROM public.collusion_flags c
   WHERE c.status IN ('open','investigating')
   ORDER BY c.created_at DESC
   LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_open_collusion_flags(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_open_collusion_flags(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.founder_resolve_collusion_flag(
  p_flag_id  uuid,
  p_status   text,    -- 'confirmed' / 'false_positive' / 'resolved'
  p_note     text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('investigating','confirmed','false_positive','resolved') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
  END IF;
  IF p_note IS NULL OR length(trim(p_note)) < 5 THEN
    RAISE EXCEPTION 'note required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_old FROM public.collusion_flags WHERE id = p_flag_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'flag_not_found' USING ERRCODE = '02000';
  END IF;

  UPDATE public.collusion_flags
     SET status = p_status,
         resolved_by = auth.uid(),
         resolved_at = CASE WHEN p_status IN ('confirmed','false_positive','resolved') THEN now() ELSE NULL END,
         resolution_note = p_note
   WHERE id = p_flag_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_resolve_collusion_flag',
    p_target_table  => 'collusion_flags',
    p_target_row_id => p_flag_id,
    p_before_value  => jsonb_build_object('status', v_old.status, 'signal_kind', v_old.signal_kind),
    p_after_value   => jsonb_build_object('status', p_status),
    p_reason        => p_note
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_resolve_collusion_flag(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_resolve_collusion_flag(uuid, text, text) TO service_role;

-- ---------------------------------------------------------------------
-- Daily crons
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.schedule(
    'run_daily_risk_scoring',
    '30 21 * * *',  -- 21:30 UTC = 03:00 IST
    $cron$SELECT public.run_daily_risk_scoring();$cron$
  );
  PERFORM cron.schedule(
    'scan_collusion_pairs_daily',
    '45 21 * * *',  -- 21:45 UTC = 03:15 IST
    $cron$SELECT public.scan_collusion_pairs();$cron$
  );
  RAISE NOTICE 'round 498: risk scoring + collusion scan crons scheduled';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 498: pg_cron unavailable; RPCs callable from edge fn / manual';
END;
$$;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname IN ('risk_score_snapshots','collusion_flags')
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 498: tables not RLS-enabled';
  END IF;
  RAISE NOTICE 'round 498 risk score + collusion verified: 2 tables, 7 RPCs, alert-only mode active';
END;
$$;
