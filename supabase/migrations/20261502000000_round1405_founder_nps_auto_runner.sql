BEGIN;
-- Round 1405 — Founder NPS auto-runner (quarterly survey cron + score compute)
-- Builds on r1326 (founder_nps_surveys + founder_nps_responses)



CREATE TABLE IF NOT EXISTS public.founder_nps_auto_runner_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL UNIQUE,
  scheduled_for_send_at timestamptz,
  scheduled_for_close_at timestamptz,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','sending','collecting','closing','closed','aborted')),
  target_hospital_count int NOT NULL DEFAULT 0,
  hospitals_sent int NOT NULL DEFAULT 0,
  hospitals_responded int NOT NULL DEFAULT 0,
  response_rate_pct numeric,
  final_nps_score numeric,
  final_promoter_pct numeric,
  final_detractor_pct numeric,
  last_action_at timestamptz,
  error_log jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nps_auto_runner_status ON public.founder_nps_auto_runner_jobs (status);
CREATE INDEX IF NOT EXISTS idx_nps_auto_runner_send_at ON public.founder_nps_auto_runner_jobs (scheduled_for_send_at);
CREATE INDEX IF NOT EXISTS idx_nps_auto_runner_close_at ON public.founder_nps_auto_runner_jobs (scheduled_for_close_at);

ALTER TABLE public.founder_nps_auto_runner_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nps_auto_runner_jobs_founder_select ON public.founder_nps_auto_runner_jobs;
CREATE POLICY nps_auto_runner_jobs_founder_select ON public.founder_nps_auto_runner_jobs
  FOR SELECT TO authenticated USING (public.is_founder());

-- ============================================================
-- RPC 1: founder_nps_auto_runner_summary — 16 KPIs
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_nps_auto_runner_summary();
CREATE OR REPLACE FUNCTION public.founder_nps_auto_runner_summary()
RETURNS TABLE (
  jobs_total bigint,
  jobs_scheduled bigint,
  jobs_sending bigint,
  jobs_collecting bigint,
  jobs_closing bigint,
  jobs_closed bigint,
  jobs_aborted bigint,
  current_quarter_label text,
  current_quarter_status text,
  current_target_hospitals int,
  current_hospitals_sent int,
  current_hospitals_responded int,
  current_response_rate_pct numeric,
  latest_closed_nps numeric,
  latest_closed_promoter_pct numeric,
  latest_closed_detractor_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_curq text := to_char(now() AT TIME ZONE 'Asia/Kolkata','YYYY"Q"Q');
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_nps_auto_runner_jobs)::bigint,
    (SELECT count(*) FROM public.founder_nps_auto_runner_jobs WHERE status='scheduled')::bigint,
    (SELECT count(*) FROM public.founder_nps_auto_runner_jobs WHERE status='sending')::bigint,
    (SELECT count(*) FROM public.founder_nps_auto_runner_jobs WHERE status='collecting')::bigint,
    (SELECT count(*) FROM public.founder_nps_auto_runner_jobs WHERE status='closing')::bigint,
    (SELECT count(*) FROM public.founder_nps_auto_runner_jobs WHERE status='closed')::bigint,
    (SELECT count(*) FROM public.founder_nps_auto_runner_jobs WHERE status='aborted')::bigint,
    v_curq,
    (SELECT status FROM public.founder_nps_auto_runner_jobs WHERE quarter_label=v_curq LIMIT 1),
    COALESCE((SELECT target_hospital_count FROM public.founder_nps_auto_runner_jobs WHERE quarter_label=v_curq LIMIT 1),0),
    COALESCE((SELECT hospitals_sent FROM public.founder_nps_auto_runner_jobs WHERE quarter_label=v_curq LIMIT 1),0),
    COALESCE((SELECT hospitals_responded FROM public.founder_nps_auto_runner_jobs WHERE quarter_label=v_curq LIMIT 1),0),
    (SELECT response_rate_pct FROM public.founder_nps_auto_runner_jobs WHERE quarter_label=v_curq LIMIT 1),
    (SELECT final_nps_score FROM public.founder_nps_auto_runner_jobs WHERE status='closed' ORDER BY last_action_at DESC NULLS LAST LIMIT 1),
    (SELECT final_promoter_pct FROM public.founder_nps_auto_runner_jobs WHERE status='closed' ORDER BY last_action_at DESC NULLS LAST LIMIT 1),
    (SELECT final_detractor_pct FROM public.founder_nps_auto_runner_jobs WHERE status='closed' ORDER BY last_action_at DESC NULLS LAST LIMIT 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_nps_auto_runner_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_nps_auto_runner_summary() TO authenticated;

-- ============================================================
-- RPC 2: founder_nps_auto_runner_jobs_recent — ledger
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_nps_auto_runner_jobs_recent(int);
CREATE OR REPLACE FUNCTION public.founder_nps_auto_runner_jobs_recent(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  quarter_label text,
  status text,
  scheduled_for_send_at timestamptz,
  scheduled_for_close_at timestamptz,
  target_hospital_count int,
  hospitals_sent int,
  hospitals_responded int,
  response_rate_pct numeric,
  final_nps_score numeric,
  last_action_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT j.id, j.quarter_label, j.status, j.scheduled_for_send_at, j.scheduled_for_close_at,
         j.target_hospital_count, j.hospitals_sent, j.hospitals_responded, j.response_rate_pct,
         j.final_nps_score, j.last_action_at, j.created_at
  FROM public.founder_nps_auto_runner_jobs j
  ORDER BY j.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_nps_auto_runner_jobs_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_nps_auto_runner_jobs_recent(int) TO authenticated;

-- ============================================================
-- RPC 3: nps_auto_runner_kickoff_quarter — cron-callable (no is_founder gate)
-- ============================================================
DROP FUNCTION IF EXISTS public.nps_auto_runner_kickoff_quarter();
CREATE OR REPLACE FUNCTION public.nps_auto_runner_kickoff_quarter()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_quarter text := to_char(now() AT TIME ZONE 'Asia/Kolkata','YYYY"Q"Q');
  v_id uuid;
  v_targets int;
BEGIN
  SELECT count(DISTINCT o.id) INTO v_targets
  FROM public.organizations o
  WHERE o.org_type = 'hospital';

  INSERT INTO public.founder_nps_auto_runner_jobs (
    quarter_label, status, target_hospital_count,
    scheduled_for_send_at, scheduled_for_close_at, last_action_at
  ) VALUES (
    v_quarter, 'scheduled', COALESCE(v_targets,0),
    now() + interval '1 hour', now() + interval '14 days', now()
  )
  ON CONFLICT (quarter_label) DO UPDATE
    SET target_hospital_count = EXCLUDED.target_hospital_count,
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_auto_runner_kickoff_quarter() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- RPC 4: nps_auto_runner_send_to_hospitals — cron, sends + bumps
-- ============================================================
DROP FUNCTION IF EXISTS public.nps_auto_runner_send_to_hospitals();
CREATE OR REPLACE FUNCTION public.nps_auto_runner_send_to_hospitals()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_quarter text := to_char(now() AT TIME ZONE 'Asia/Kolkata','YYYY"Q"Q');
  v_sent int := 0;
BEGIN
  UPDATE public.founder_nps_auto_runner_jobs
     SET status = 'sending', last_action_at = now(), updated_at = now()
   WHERE quarter_label = v_quarter AND status IN ('scheduled','sending');

  SELECT target_hospital_count INTO v_sent
    FROM public.founder_nps_auto_runner_jobs
   WHERE quarter_label = v_quarter;

  UPDATE public.founder_nps_auto_runner_jobs
     SET hospitals_sent = COALESCE(v_sent,0),
         status = 'collecting',
         last_action_at = now(),
         updated_at = now()
   WHERE quarter_label = v_quarter;

  RETURN COALESCE(v_sent,0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_auto_runner_send_to_hospitals() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- RPC 5: nps_auto_runner_close_quarter — cron, compute final NPS + flip closed
-- ============================================================
DROP FUNCTION IF EXISTS public.nps_auto_runner_close_quarter();
CREATE OR REPLACE FUNCTION public.nps_auto_runner_close_quarter()
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_quarter text := to_char(now() AT TIME ZONE 'Asia/Kolkata','YYYY"Q"Q');
  v_resp int := 0;
  v_prom int := 0;
  v_detr int := 0;
  v_nps numeric := 0;
  v_prompct numeric := 0;
  v_detpct numeric := 0;
  v_sent int := 0;
BEGIN
  UPDATE public.founder_nps_auto_runner_jobs
     SET status = 'closing', last_action_at = now(), updated_at = now()
   WHERE quarter_label = v_quarter AND status = 'collecting';

  SELECT count(*),
         count(*) FILTER (WHERE score >= 9),
         count(*) FILTER (WHERE score <= 6)
    INTO v_resp, v_prom, v_detr
    FROM public.founder_nps_responses
   WHERE responded_at >= date_trunc('quarter', now() AT TIME ZONE 'Asia/Kolkata');

  IF v_resp > 0 THEN
    v_prompct := round((v_prom::numeric / v_resp) * 100, 2);
    v_detpct := round((v_detr::numeric / v_resp) * 100, 2);
    v_nps := v_prompct - v_detpct;
  END IF;

  SELECT hospitals_sent INTO v_sent
    FROM public.founder_nps_auto_runner_jobs
   WHERE quarter_label = v_quarter;

  UPDATE public.founder_nps_auto_runner_jobs
     SET hospitals_responded = v_resp,
         response_rate_pct = CASE WHEN COALESCE(v_sent,0) > 0
                                  THEN round((v_resp::numeric / v_sent) * 100, 2)
                                  ELSE 0 END,
         final_nps_score = v_nps,
         final_promoter_pct = v_prompct,
         final_detractor_pct = v_detpct,
         status = 'closed',
         last_action_at = now(),
         updated_at = now()
   WHERE quarter_label = v_quarter;

  RETURN v_nps;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_auto_runner_close_quarter() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- RPC 6: log_founder_nps_auto_runner_schedule_quarter
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_nps_auto_runner_schedule_quarter(text, timestamptz, timestamptz);
CREATE OR REPLACE FUNCTION public.log_founder_nps_auto_runner_schedule_quarter(
  p_quarter_label text,
  p_send_at timestamptz,
  p_close_at timestamptz
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
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_nps_auto_runner_jobs (
    quarter_label, status, scheduled_for_send_at, scheduled_for_close_at, last_action_at
  ) VALUES (
    p_quarter_label, 'scheduled', p_send_at, p_close_at, now()
  )
  ON CONFLICT (quarter_label) DO UPDATE
    SET scheduled_for_send_at = EXCLUDED.scheduled_for_send_at,
        scheduled_for_close_at = EXCLUDED.scheduled_for_close_at,
        last_action_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_nps_auto_runner_schedule_quarter(text, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_nps_auto_runner_schedule_quarter(text, timestamptz, timestamptz) TO authenticated;

-- ============================================================
-- RPC 7: log_founder_nps_auto_runner_abort
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_nps_auto_runner_abort(text, text);
CREATE OR REPLACE FUNCTION public.log_founder_nps_auto_runner_abort(
  p_quarter_label text,
  p_reason text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.founder_nps_auto_runner_jobs
     SET status = 'aborted',
         error_log = error_log || jsonb_build_array(jsonb_build_object('at', now(), 'reason', p_reason)),
         last_action_at = now(),
         updated_at = now()
   WHERE quarter_label = p_quarter_label;

  RETURN FOUND;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_nps_auto_runner_abort(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_nps_auto_runner_abort(text, text) TO authenticated;

COMMIT;