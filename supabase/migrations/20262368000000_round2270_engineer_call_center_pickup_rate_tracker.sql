BEGIN;

-- =========================================================================
-- r2270: Engineer call-center pickup-rate tracker
-- When engineer phones ring, are they picked up? Track pickup %,
-- time-to-answer, and follow-up actions on missed calls.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_call_attempts_r2270 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  caller_id       uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  caller_role     text NOT NULL CHECK (caller_role IN ('hospital_admin','supplier','manufacturer','logistics','founder','dispatcher')),
  rang_at         timestamptz NOT NULL DEFAULT now(),
  answered_at     timestamptz,
  ended_at        timestamptz,
  ring_duration_seconds  int GENERATED ALWAYS AS (
    CASE WHEN answered_at IS NOT NULL
      THEN GREATEST(0, EXTRACT(EPOCH FROM (answered_at - rang_at))::int)
      ELSE NULL END
  ) STORED,
  call_duration_seconds  int GENERATED ALWAYS AS (
    CASE WHEN answered_at IS NOT NULL AND ended_at IS NOT NULL
      THEN GREATEST(0, EXTRACT(EPOCH FROM (ended_at - answered_at))::int)
      ELSE NULL END
  ) STORED,
  outcome         text NOT NULL CHECK (outcome IN ('picked_up','missed','rejected','voicemail','busy','failed')),
  priority        text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent','code_red')),
  job_ref         text,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eca_r2270_engineer_rang     ON public.engineer_call_attempts_r2270(engineer_id, rang_at DESC);
CREATE INDEX IF NOT EXISTS idx_eca_r2270_outcome_rang      ON public.engineer_call_attempts_r2270(outcome, rang_at DESC);
CREATE INDEX IF NOT EXISTS idx_eca_r2270_priority_rang     ON public.engineer_call_attempts_r2270(priority, rang_at DESC);

ALTER TABLE public.engineer_call_attempts_r2270 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eca_r2270_founder_all ON public.engineer_call_attempts_r2270;
CREATE POLICY eca_r2270_founder_all ON public.engineer_call_attempts_r2270
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.engineer_missed_call_followups_r2270 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_attempt_id uuid NOT NULL REFERENCES public.engineer_call_attempts_r2270(id) ON DELETE CASCADE,
  engineer_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  followup_kind   text NOT NULL CHECK (followup_kind IN ('callback','sms','whatsapp','escalation','no_action','reassigned')),
  followup_at     timestamptz NOT NULL DEFAULT now(),
  resolved        boolean NOT NULL DEFAULT false,
  resolved_at     timestamptz,
  performed_by    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emcf_r2270_call       ON public.engineer_missed_call_followups_r2270(call_attempt_id);
CREATE INDEX IF NOT EXISTS idx_emcf_r2270_engineer   ON public.engineer_missed_call_followups_r2270(engineer_id, followup_at DESC);
CREATE INDEX IF NOT EXISTS idx_emcf_r2270_resolved   ON public.engineer_missed_call_followups_r2270(resolved, followup_at DESC);

ALTER TABLE public.engineer_missed_call_followups_r2270 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS emcf_r2270_founder_all ON public.engineer_missed_call_followups_r2270;
CREATE POLICY emcf_r2270_founder_all ON public.engineer_missed_call_followups_r2270
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- =========================================================================
-- RPCs (7 total) — all founder-gated
-- =========================================================================

-- 1) Overall pickup KPIs (last N days)
CREATE OR REPLACE FUNCTION public.r2270_pickup_overview(days int DEFAULT 30)
RETURNS TABLE (
  total_calls       int,
  picked_up         int,
  missed            int,
  rejected          int,
  voicemail         int,
  pickup_rate_pct   numeric,
  median_answer_secs numeric,
  p90_answer_secs   numeric,
  urgent_missed     int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int                                              AS total_calls,
    (COUNT(*) FILTER (WHERE outcome = 'picked_up'))::int       AS picked_up,
    (COUNT(*) FILTER (WHERE outcome = 'missed'))::int          AS missed,
    (COUNT(*) FILTER (WHERE outcome = 'rejected'))::int        AS rejected,
    (COUNT(*) FILTER (WHERE outcome = 'voicemail'))::int       AS voicemail,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE outcome = 'picked_up')
        / NULLIF(COUNT(*), 0)::numeric, 2)                     AS pickup_rate_pct,
    ROUND(percentile_cont(0.5)  WITHIN GROUP (ORDER BY ring_duration_seconds) FILTER (WHERE outcome = 'picked_up')::numeric, 2) AS median_answer_secs,
    ROUND(percentile_cont(0.90) WITHIN GROUP (ORDER BY ring_duration_seconds) FILTER (WHERE outcome = 'picked_up')::numeric, 2) AS p90_answer_secs,
    (COUNT(*) FILTER (WHERE outcome IN ('missed','rejected') AND priority IN ('urgent','code_red')))::int AS urgent_missed
  FROM public.engineer_call_attempts_r2270
  WHERE rang_at >= now() - make_interval(days => days);
END;
$$;

-- 2) Per-engineer pickup leaderboard
CREATE OR REPLACE FUNCTION public.r2270_engineer_pickup_leaderboard(days int DEFAULT 30)
RETURNS TABLE (
  engineer_id          uuid,
  engineer_email       text,
  total_calls          int,
  picked_up            int,
  missed               int,
  pickup_rate_pct      numeric,
  median_answer_secs   numeric,
  urgent_missed        int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    eca.engineer_id,
    p.email::text,
    COUNT(*)::int                                              AS total_calls,
    (COUNT(*) FILTER (WHERE eca.outcome = 'picked_up'))::int   AS picked_up,
    (COUNT(*) FILTER (WHERE eca.outcome = 'missed'))::int      AS missed,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE eca.outcome = 'picked_up')
        / NULLIF(COUNT(*), 0)::numeric, 2)                     AS pickup_rate_pct,
    ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY eca.ring_duration_seconds) FILTER (WHERE eca.outcome = 'picked_up')::numeric, 2) AS median_answer_secs,
    (COUNT(*) FILTER (WHERE eca.outcome IN ('missed','rejected') AND eca.priority IN ('urgent','code_red')))::int AS urgent_missed
  FROM public.engineer_call_attempts_r2270 eca
  JOIN public.profiles p ON p.id = eca.engineer_id
  WHERE eca.rang_at >= now() - make_interval(days => days)
  GROUP BY eca.engineer_id, p.email
  ORDER BY pickup_rate_pct ASC NULLS LAST, total_calls DESC
  LIMIT 50;
END;
$$;

-- 3) Daily pickup trend
CREATE OR REPLACE FUNCTION public.r2270_daily_pickup_trend(days int DEFAULT 14)
RETURNS TABLE (
  day              date,
  total_calls      int,
  picked_up        int,
  missed           int,
  pickup_rate_pct  numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (rang_at AT TIME ZONE 'Asia/Kolkata')::date                AS day,
    COUNT(*)::int                                              AS total_calls,
    (COUNT(*) FILTER (WHERE outcome = 'picked_up'))::int       AS picked_up,
    (COUNT(*) FILTER (WHERE outcome = 'missed'))::int          AS missed,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE outcome = 'picked_up')
        / NULLIF(COUNT(*), 0)::numeric, 2)                     AS pickup_rate_pct
  FROM public.engineer_call_attempts_r2270
  WHERE rang_at >= now() - make_interval(days => days)
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;

-- 4) Unresolved missed calls (open follow-ups OR no follow-up yet)
CREATE OR REPLACE FUNCTION public.r2270_open_missed_calls(lim int DEFAULT 100)
RETURNS TABLE (
  call_attempt_id  uuid,
  engineer_email   text,
  rang_at          timestamptz,
  outcome          text,
  priority         text,
  job_ref          text,
  followup_status  text,
  hours_open       numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    eca.id,
    p.email::text,
    eca.rang_at,
    eca.outcome,
    eca.priority,
    eca.job_ref,
    COALESCE(
      (SELECT CASE WHEN bool_or(resolved) THEN 'resolved' ELSE 'pending' END
         FROM public.engineer_missed_call_followups_r2270 f
         WHERE f.call_attempt_id = eca.id),
      'no_followup'
    )                                                          AS followup_status,
    ROUND(EXTRACT(EPOCH FROM (now() - eca.rang_at))::numeric / 3600.0, 2) AS hours_open
  FROM public.engineer_call_attempts_r2270 eca
  JOIN public.profiles p ON p.id = eca.engineer_id
  WHERE eca.outcome IN ('missed','rejected','voicemail','busy')
    AND NOT EXISTS (
      SELECT 1 FROM public.engineer_missed_call_followups_r2270 f
      WHERE f.call_attempt_id = eca.id AND f.resolved = true
    )
  ORDER BY
    CASE eca.priority WHEN 'code_red' THEN 0 WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    eca.rang_at ASC
  LIMIT lim;
END;
$$;

-- 5) Recent calls (raw log)
CREATE OR REPLACE FUNCTION public.r2270_recent_calls(lim int DEFAULT 100)
RETURNS TABLE (
  call_id                uuid,
  engineer_email         text,
  caller_role            text,
  rang_at                timestamptz,
  outcome                text,
  priority               text,
  ring_duration_seconds  int,
  call_duration_seconds  int,
  job_ref                text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT eca.id, p.email::text, eca.caller_role, eca.rang_at, eca.outcome,
         eca.priority, eca.ring_duration_seconds, eca.call_duration_seconds, eca.job_ref
  FROM public.engineer_call_attempts_r2270 eca
  JOIN public.profiles p ON p.id = eca.engineer_id
  ORDER BY eca.rang_at DESC
  LIMIT lim;
END;
$$;

-- 6) Follow-up effectiveness
CREATE OR REPLACE FUNCTION public.r2270_followup_effectiveness(days int DEFAULT 30)
RETURNS TABLE (
  followup_kind     text,
  total_attempts    int,
  resolved_count    int,
  resolution_rate_pct numeric,
  avg_resolve_hours numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    followup_kind,
    COUNT(*)::int                                       AS total_attempts,
    (COUNT(*) FILTER (WHERE resolved = true))::int      AS resolved_count,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE resolved = true)
        / NULLIF(COUNT(*), 0)::numeric, 2)              AS resolution_rate_pct,
    ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at - followup_at)) / 3600.0)
            FILTER (WHERE resolved = true AND resolved_at IS NOT NULL)::numeric, 2) AS avg_resolve_hours
  FROM public.engineer_missed_call_followups_r2270
  WHERE followup_at >= now() - make_interval(days => days)
  GROUP BY followup_kind
  ORDER BY total_attempts DESC;
END;
$$;

-- 7) Pickup by priority band
CREATE OR REPLACE FUNCTION public.r2270_pickup_by_priority(days int DEFAULT 30)
RETURNS TABLE (
  priority         text,
  total_calls      int,
  picked_up        int,
  missed           int,
  pickup_rate_pct  numeric,
  median_answer_secs numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    priority,
    COUNT(*)::int                                              AS total_calls,
    (COUNT(*) FILTER (WHERE outcome = 'picked_up'))::int       AS picked_up,
    (COUNT(*) FILTER (WHERE outcome = 'missed'))::int          AS missed,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE outcome = 'picked_up')
        / NULLIF(COUNT(*), 0)::numeric, 2)                     AS pickup_rate_pct,
    ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY ring_duration_seconds) FILTER (WHERE outcome = 'picked_up')::numeric, 2) AS median_answer_secs
  FROM public.engineer_call_attempts_r2270
  WHERE rang_at >= now() - make_interval(days => days)
  GROUP BY priority
  ORDER BY
    CASE priority WHEN 'code_red' THEN 0 WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 WHEN 'low' THEN 4 END;
END;
$$;


-- =========================================================================
-- Grants
-- =========================================================================
REVOKE ALL ON FUNCTION public.r2270_pickup_overview(int)             FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2270_engineer_pickup_leaderboard(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2270_daily_pickup_trend(int)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2270_open_missed_calls(int)           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2270_recent_calls(int)                FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2270_followup_effectiveness(int)      FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2270_pickup_by_priority(int)          FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2270_pickup_overview(int)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2270_engineer_pickup_leaderboard(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2270_daily_pickup_trend(int)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2270_open_missed_calls(int)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2270_recent_calls(int)                TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2270_followup_effectiveness(int)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2270_pickup_by_priority(int)          TO authenticated;


-- =========================================================================
-- Seed (only if engineers exist; CHECK-safe values)
-- =========================================================================
DO $seed$
DECLARE
  eng1 uuid;
  eng2 uuid;
  caller1 uuid;
  c_id uuid;
BEGIN
  SELECT id INTO eng1 FROM public.profiles WHERE role = 'engineer' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO eng2 FROM public.profiles WHERE role = 'engineer' AND id <> COALESCE(eng1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO caller1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;

  IF eng1 IS NULL THEN RETURN; END IF;

  INSERT INTO public.engineer_call_attempts_r2270
    (engineer_id, caller_id, caller_role, rang_at, answered_at, ended_at, outcome, priority, job_ref, notes)
  VALUES
    (eng1, caller1, 'hospital_admin', now() - interval '2 hours', now() - interval '2 hours' + interval '6 seconds', now() - interval '2 hours' + interval '4 minutes', 'picked_up', 'high', 'JOB-9001', 'normal pickup'),
    (eng1, caller1, 'hospital_admin', now() - interval '1 day',   NULL, NULL, 'missed',  'urgent',   'JOB-9002', 'engineer in transit'),
    (eng1, caller1, 'dispatcher',     now() - interval '3 days',  now() - interval '3 days' + interval '12 seconds', now() - interval '3 days' + interval '2 minutes', 'picked_up', 'code_red', 'JOB-9003', 'code red picked up');

  IF eng2 IS NOT NULL THEN
    INSERT INTO public.engineer_call_attempts_r2270
      (engineer_id, caller_id, caller_role, rang_at, outcome, priority, job_ref, notes)
    VALUES
      (eng2, caller1, 'hospital_admin', now() - interval '5 hours',  'rejected', 'urgent', 'JOB-9004', 'engineer rejected'),
      (eng2, caller1, 'hospital_admin', now() - interval '2 days',   'voicemail','normal', 'JOB-9005', 'went to voicemail');
  END IF;

  -- one follow-up tied to the missed urgent call
  INSERT INTO public.engineer_missed_call_followups_r2270
    (call_attempt_id, engineer_id, followup_kind, followup_at, resolved, resolved_at, performed_by, notes)
  SELECT eca.id, eca.engineer_id, 'sms', eca.rang_at + interval '5 minutes', true, eca.rang_at + interval '20 minutes', caller1, 'sms callback resolved'
  FROM public.engineer_call_attempts_r2270 eca
  WHERE eca.engineer_id = eng1 AND eca.outcome = 'missed'
  LIMIT 1;
END
$seed$;

COMMIT;
