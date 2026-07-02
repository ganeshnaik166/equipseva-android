-- Round 2653: founder monthly spouse family time tracker

CREATE TABLE IF NOT EXISTS public.founder_family_time_r2653 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  family_hours numeric NOT NULL DEFAULT 0,
  date_nights int NOT NULL DEFAULT 0,
  family_trips int NOT NULL DEFAULT 0,
  family_grade text NOT NULL DEFAULT 'C' CHECK (family_grade IN ('A','B','C','D','F')),
  top_drain_md text,
  top_invest_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','recovering','healthy','strained')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.family_time_recovery_actions_r2653 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES public.founder_family_time_r2653(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('scheduled_date_night','long_weekend','sabbatical','family_dinner','no_phone_zone')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_family_time_r2653 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_time_recovery_actions_r2653 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_family_time_r2653;
CREATE POLICY founder_all ON public.founder_family_time_r2653 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.family_time_recovery_actions_r2653;
CREATE POLICY founder_all ON public.family_time_recovery_actions_r2653 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.founder_family_time_r2653 (month_label, family_hours, date_nights, family_trips, family_grade, top_drain_md, top_invest_md, owner_email, status, notes)
VALUES
  ('2026-02', 38.0, 1, 0, 'F', 'Series A close ate every weekend', 'Booked Goa trip for March', 'founder@equipseva.in', 'strained', 'Worst month on record'),
  ('2026-03', 72.5, 3, 1, 'C', 'Engineer onboarding marathon', 'Weekly Sunday no-laptop rule', 'founder@equipseva.in', 'recovering', 'Goa trip reset things'),
  ('2026-04', 95.0, 4, 1, 'B', 'Hospital chain pitch trips', 'Date night every Friday', 'founder@equipseva.in', 'recovering', 'Trend up'),
  ('2026-05', 110.0, 5, 2, 'A', 'None major', 'Family dinner every weeknight', 'founder@equipseva.in', 'healthy', 'Best month so far'),
  ('2026-06', 88.0, 3, 1, 'B', 'v0.5 launch crunch', 'Long weekend in Coorg', 'founder@equipseva.in', 'monitoring', 'Mid-month check');

INSERT INTO public.family_time_recovery_actions_r2653 (family_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'long_weekend', 'positive', 'founder@equipseva.in', 'done', 'Goa 3-night trip'
FROM public.founder_family_time_r2653 WHERE month_label = '2026-03' LIMIT 1;

INSERT INTO public.family_time_recovery_actions_r2653 (family_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'scheduled_date_night', 'positive', 'founder@equipseva.in', 'done', 'Every Friday booked'
FROM public.founder_family_time_r2653 WHERE month_label = '2026-04' LIMIT 1;

INSERT INTO public.family_time_recovery_actions_r2653 (family_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'family_dinner', 'positive', 'founder@equipseva.in', 'done', 'No phones at table'
FROM public.founder_family_time_r2653 WHERE month_label = '2026-05' LIMIT 1;

INSERT INTO public.family_time_recovery_actions_r2653 (family_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'no_phone_zone', 'pending', 'founder@equipseva.in', 'open', 'Bedroom phone-free trial'
FROM public.founder_family_time_r2653 WHERE month_label = '2026-06' LIMIT 1;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_family_time_r2653()
RETURNS TABLE(id uuid, month_label text, family_hours numeric, date_nights int, family_trips int, family_grade text, top_drain_md text, top_invest_md text, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.id, f.month_label, f.family_hours, f.date_nights, f.family_trips, f.family_grade, f.top_drain_md, f.top_invest_md, f.owner_email, f.status, f.notes, f.created_at
  FROM public.founder_family_time_r2653 f ORDER BY f.month_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_family_time_r2653() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_family_time_r2653() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_recovery_actions_r2653()
RETURNS TABLE(id uuid, family_id uuid, month_label text, action_at timestamptz, action_kind text, outcome text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.family_id, f.month_label, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
  FROM public.family_time_recovery_actions_r2653 a JOIN public.founder_family_time_r2653 f ON f.id = a.family_id
  ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2653() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2653() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_drain_focus_r2653()
RETURNS TABLE(month_label text, family_hours numeric, family_grade text, top_drain_md text, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.month_label, f.family_hours, f.family_grade, f.top_drain_md, f.status
  FROM public.founder_family_time_r2653 f
  WHERE f.family_grade IN ('D','F') OR f.status = 'strained'
  ORDER BY f.month_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_drain_focus_r2653() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_drain_focus_r2653() TO authenticated;

CREATE OR REPLACE FUNCTION public.grade_distribution_r2653()
RETURNS TABLE(family_grade text, n bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.family_grade, count(*)::bigint FROM public.founder_family_time_r2653 f GROUP BY f.family_grade ORDER BY f.family_grade;
END $$;
REVOKE EXECUTE ON FUNCTION public.grade_distribution_r2653() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grade_distribution_r2653() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2653()
RETURNS TABLE(status text, n bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.status, count(*)::bigint FROM public.founder_family_time_r2653 f GROUP BY f.status ORDER BY f.status;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2653() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2653() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_family_trend_r2653()
RETURNS TABLE(month_label text, family_hours numeric, date_nights int, family_trips int, family_grade text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.month_label, f.family_hours, f.date_nights, f.family_trips, f.family_grade
  FROM public.founder_family_time_r2653 f ORDER BY f.month_label ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_family_trend_r2653() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_family_trend_r2653() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2653()
RETURNS TABLE(total_months bigint, strained_months bigint, healthy_months bigint, avg_family_hours numeric, total_date_nights bigint, total_trips bigint, open_actions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    (SELECT count(*)::bigint FROM public.founder_family_time_r2653),
    (SELECT count(*)::bigint FROM public.founder_family_time_r2653 WHERE status = 'strained'),
    (SELECT count(*)::bigint FROM public.founder_family_time_r2653 WHERE status = 'healthy'),
    (SELECT COALESCE(avg(family_hours),0)::numeric FROM public.founder_family_time_r2653),
    (SELECT COALESCE(sum(date_nights),0)::bigint FROM public.founder_family_time_r2653),
    (SELECT COALESCE(sum(family_trips),0)::bigint FROM public.founder_family_time_r2653),
    (SELECT count(*)::bigint FROM public.family_time_recovery_actions_r2653 WHERE status = 'open');
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2653() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2653() TO authenticated;
