-- Round 2442: Engineer Night-Shift Fairness Tracker
-- Tracks night/weekend/holiday shift assignments with consent + refusal + premium pay,
-- and computes per-engineer fairness deltas against rotation targets.

BEGIN;

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_night_shifts_r2442 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  shift_start_at timestamptz NOT NULL,
  shift_end_at timestamptz NOT NULL,
  shift_kind text NOT NULL
    CHECK (shift_kind IN ('night','late_evening','holiday','weekend')),
  consent_given boolean NOT NULL DEFAULT false,
  premium_rupees integer NOT NULL DEFAULT 0 CHECK (premium_rupees >= 0),
  refusal_reason text,
  refusal_kind text NOT NULL DEFAULT 'none'
    CHECK (refusal_kind IN ('none','health','family','burnout','conflict','other')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (shift_end_at >= shift_start_at)
);

CREATE INDEX IF NOT EXISTS idx_shifts_r2442_engineer    ON public.engineer_night_shifts_r2442(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_shifts_r2442_kind        ON public.engineer_night_shifts_r2442(shift_kind);
CREATE INDEX IF NOT EXISTS idx_shifts_r2442_refusal     ON public.engineer_night_shifts_r2442(refusal_kind);
CREATE INDEX IF NOT EXISTS idx_shifts_r2442_start_at    ON public.engineer_night_shifts_r2442(shift_start_at);
CREATE INDEX IF NOT EXISTS idx_shifts_r2442_consent     ON public.engineer_night_shifts_r2442(consent_given);

CREATE TABLE IF NOT EXISTS public.night_shift_fairness_metrics_r2442 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_night_shifts integer NOT NULL DEFAULT 0 CHECK (total_night_shifts >= 0),
  fairness_target integer NOT NULL DEFAULT 0 CHECK (fairness_target >= 0),
  fairness_delta integer NOT NULL DEFAULT 0,
  total_premium_rupees bigint NOT NULL DEFAULT 0 CHECK (total_premium_rupees >= 0),
  refusal_count integer NOT NULL DEFAULT 0 CHECK (refusal_count >= 0),
  status text NOT NULL DEFAULT 'on_track'
    CHECK (status IN ('on_track','over_quota','under_quota','refused_repeatedly')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (period_end >= period_start)
);

CREATE INDEX IF NOT EXISTS idx_metrics_r2442_engineer  ON public.night_shift_fairness_metrics_r2442(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_metrics_r2442_status    ON public.night_shift_fairness_metrics_r2442(status);
CREATE INDEX IF NOT EXISTS idx_metrics_r2442_period    ON public.night_shift_fairness_metrics_r2442(period_end);
CREATE INDEX IF NOT EXISTS idx_metrics_r2442_delta     ON public.night_shift_fairness_metrics_r2442(fairness_delta);

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE public.engineer_night_shifts_r2442 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.night_shift_fairness_metrics_r2442 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_night_shifts_r2442;
CREATE POLICY founder_all ON public.engineer_night_shifts_r2442
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.night_shift_fairness_metrics_r2442;
CREATE POLICY founder_all ON public.night_shift_fairness_metrics_r2442
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED
-- ============================================================================

INSERT INTO public.engineer_night_shifts_r2442
  (id, engineer_user_id, shift_start_at, shift_end_at, shift_kind, consent_given, premium_rupees, refusal_reason, refusal_kind, notes)
VALUES
  ('bbbbbbb1-0000-4000-8000-000000000001', NULL, (now() - interval '28 days')::timestamptz, (now() - interval '28 days' + interval '8 hours')::timestamptz, 'night',        true,  1800, NULL,                                'none',     'Apollo Jubilee — ventilator escalation'),
  ('bbbbbbb1-0000-4000-8000-000000000002', NULL, (now() - interval '21 days')::timestamptz, (now() - interval '21 days' + interval '6 hours')::timestamptz, 'weekend',      true,  1200, NULL,                                'none',     'Sunday OT dialysis bay'),
  ('bbbbbbb1-0000-4000-8000-000000000003', NULL, (now() - interval '14 days')::timestamptz, (now() - interval '14 days' + interval '5 hours')::timestamptz, 'late_evening', true,  900,  NULL,                                'none',     'Post-8pm CT scanner reboot'),
  ('bbbbbbb1-0000-4000-8000-000000000004', NULL, (now() - interval '10 days')::timestamptz, (now() - interval '10 days' + interval '4 hours')::timestamptz, 'night',        false, 0,    'Family emergency — child sick',     'family',   'Refusal logged; reassigned to engineer #B'),
  ('bbbbbbb1-0000-4000-8000-000000000005', NULL, (now() - interval '4 days')::timestamptz,  (now() - interval '4 days' + interval '7 hours')::timestamptz,  'holiday',      true,  2400, NULL,                                'none',     'Independence-Day call-out, MRI helium top-up');

INSERT INTO public.night_shift_fairness_metrics_r2442
  (id, engineer_user_id, period_start, period_end, total_night_shifts, fairness_target, fairness_delta, total_premium_rupees, refusal_count, status, notes)
VALUES
  ('ccccccc1-0000-4000-8000-000000000001', NULL, (now() - interval '60 days')::date, (now() - interval '1 day')::date, 8, 6, 2,  9600, 0, 'over_quota',         'Engineer A — taking too many shifts; rotate'),
  ('ccccccc1-0000-4000-8000-000000000002', NULL, (now() - interval '60 days')::date, (now() - interval '1 day')::date, 2, 6, -4, 2400, 1, 'under_quota',        'Engineer B — below quota; assign more'),
  ('ccccccc1-0000-4000-8000-000000000003', NULL, (now() - interval '60 days')::date, (now() - interval '1 day')::date, 6, 6, 0,  7200, 0, 'on_track',           'Engineer C — balanced'),
  ('ccccccc1-0000-4000-8000-000000000004', NULL, (now() - interval '60 days')::date, (now() - interval '1 day')::date, 1, 6, -5, 1200, 4, 'refused_repeatedly', 'Engineer D — 4 refusals; HR check-in'),
  ('ccccccc1-0000-4000-8000-000000000005', NULL, (now() - interval '60 days')::date, (now() - interval '1 day')::date, 5, 6, -1, 6000, 0, 'on_track',           'Engineer E — near target');

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_shifts_r2442()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  shift_start_at timestamptz,
  shift_end_at timestamptz,
  shift_kind text,
  consent_given boolean,
  premium_rupees integer,
  refusal_kind text,
  refusal_reason text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.engineer_user_id,
    s.shift_start_at,
    s.shift_end_at,
    s.shift_kind,
    s.consent_given,
    s.premium_rupees,
    s.refusal_kind,
    s.refusal_reason,
    s.notes
  FROM public.engineer_night_shifts_r2442 s
  ORDER BY s.shift_start_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_shifts_r2442() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_shifts_r2442() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_metrics_r2442()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_start date,
  period_end date,
  total_night_shifts integer,
  fairness_target integer,
  fairness_delta integer,
  total_premium_rupees bigint,
  refusal_count integer,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.engineer_user_id,
    m.period_start,
    m.period_end,
    m.total_night_shifts,
    m.fairness_target,
    m.fairness_delta,
    m.total_premium_rupees,
    m.refusal_count,
    m.status,
    m.notes
  FROM public.night_shift_fairness_metrics_r2442 m
  ORDER BY
    CASE m.status
      WHEN 'refused_repeatedly' THEN 0
      WHEN 'over_quota' THEN 1
      WHEN 'under_quota' THEN 2
      WHEN 'on_track' THEN 3
      ELSE 4
    END,
    ABS(m.fairness_delta) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_metrics_r2442() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_metrics_r2442() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_over_quota_engineers_r2442()
RETURNS TABLE (
  engineer_user_id uuid,
  total_night_shifts integer,
  fairness_target integer,
  fairness_delta integer,
  total_premium_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.engineer_user_id,
    m.total_night_shifts,
    m.fairness_target,
    m.fairness_delta,
    m.total_premium_rupees,
    m.status
  FROM public.night_shift_fairness_metrics_r2442 m
  WHERE m.fairness_delta > 0
  ORDER BY m.fairness_delta DESC, m.total_premium_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_over_quota_engineers_r2442() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_over_quota_engineers_r2442() TO authenticated;

CREATE OR REPLACE FUNCTION public.refusal_breakdown_r2442()
RETURNS TABLE (
  refusal_kind text,
  refusal_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total_refusals bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_refusals
  FROM public.engineer_night_shifts_r2442
  WHERE refusal_kind <> 'none';

  RETURN QUERY
  SELECT
    s.refusal_kind,
    COUNT(*)::bigint AS refusal_count,
    CASE WHEN total_refusals = 0 THEN 0::numeric
         ELSE ROUND((COUNT(*)::numeric / total_refusals::numeric) * 100, 1)
    END AS pct_of_total
  FROM public.engineer_night_shifts_r2442 s
  WHERE s.refusal_kind <> 'none'
  GROUP BY s.refusal_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.refusal_breakdown_r2442() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refusal_breakdown_r2442() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_premium_trend_r2442()
RETURNS TABLE (
  week_start date,
  shift_count bigint,
  total_premium_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (date_trunc('week', s.shift_start_at))::date AS week_start,
    COUNT(*)::bigint AS shift_count,
    COALESCE(SUM(s.premium_rupees), 0)::bigint AS total_premium_rupees
  FROM public.engineer_night_shifts_r2442 s
  WHERE s.consent_given = true
  GROUP BY 1
  ORDER BY 1 DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_premium_trend_r2442() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_premium_trend_r2442() TO authenticated;

CREATE OR REPLACE FUNCTION public.fairness_distribution_r2442()
RETURNS TABLE (
  status text,
  engineer_count bigint,
  avg_delta numeric,
  total_premium_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.status,
    COUNT(*)::bigint AS engineer_count,
    ROUND(AVG(m.fairness_delta)::numeric, 2) AS avg_delta,
    COALESCE(SUM(m.total_premium_rupees), 0)::bigint AS total_premium_rupees
  FROM public.night_shift_fairness_metrics_r2442 m
  GROUP BY m.status
  ORDER BY
    CASE m.status
      WHEN 'refused_repeatedly' THEN 0
      WHEN 'over_quota' THEN 1
      WHEN 'under_quota' THEN 2
      WHEN 'on_track' THEN 3
      ELSE 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fairness_distribution_r2442() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fairness_distribution_r2442() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_refused_engineers_r2442()
RETURNS TABLE (
  engineer_user_id uuid,
  refusal_count integer,
  total_night_shifts integer,
  fairness_delta integer,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.engineer_user_id,
    m.refusal_count,
    m.total_night_shifts,
    m.fairness_delta,
    m.status
  FROM public.night_shift_fairness_metrics_r2442 m
  WHERE m.refusal_count > 0
  ORDER BY m.refusal_count DESC, m.fairness_delta ASC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_refused_engineers_r2442() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_refused_engineers_r2442() TO authenticated;

