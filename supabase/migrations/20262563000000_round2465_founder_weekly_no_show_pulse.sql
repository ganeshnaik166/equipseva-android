-- r2465 founder-weekly-no-show-pulse
-- Track no-shows across investor meetings, customer meetings, internal reviews, events, training
-- Reason × impact × prevention action × repeat offender × weekly metrics

CREATE TABLE IF NOT EXISTS public.founder_no_shows_r2465 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_kind text NOT NULL CHECK (appointment_kind IN ('investor_meeting','customer_meeting','internal_review','event','training')),
  scheduled_at timestamptz NOT NULL,
  party_label text NOT NULL,
  party_email text NOT NULL,
  no_show_reason text NOT NULL,
  impact_kind text NOT NULL CHECK (impact_kind IN ('revenue','relationship','time_wasted','reputation')),
  impact_rupees bigint NOT NULL DEFAULT 0,
  repeat_offender boolean NOT NULL DEFAULT false,
  prevention_action_md text NOT NULL,
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.weekly_no_show_metrics_r2465 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  total_appointments int NOT NULL,
  no_show_count int NOT NULL,
  no_show_rate_pct numeric NOT NULL,
  top_reason text NOT NULL,
  total_impact_rupees bigint NOT NULL,
  repeat_offenders_count int NOT NULL,
  prevention_score int NOT NULL CHECK (prevention_score BETWEEN 0 AND 100),
  founder_pulse_md text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_no_shows_r2465 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_no_show_metrics_r2465 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_no_shows_r2465;
CREATE POLICY founder_all ON public.founder_no_shows_r2465
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.weekly_no_show_metrics_r2465;
CREATE POLICY founder_all ON public.weekly_no_show_metrics_r2465
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed no-shows
INSERT INTO public.founder_no_shows_r2465
  (appointment_kind, scheduled_at, party_label, party_email, no_show_reason, impact_kind, impact_rupees, repeat_offender, prevention_action_md, owner_email, status, notes)
VALUES
  ('investor_meeting', '2026-06-15 10:00'::timestamptz, 'Karthik Reddy - Stellaris', 'karthik@stellaris.vc', 'Last-minute LP call conflict', 'relationship', 0, true, '- Confirm 24h prior via SMS + email\n- Add calendar hold buffer\n- Offer 3 slot options when rescheduling', 'founder@equipseva.in', 'in_progress', 'Second no-show this quarter'),
  ('customer_meeting', '2026-06-16 14:30'::timestamptz, 'Apollo Hyderabad - Procurement Head', 'procurement@apollohyd.in', 'Forgot the meeting', 'revenue', 2500000, false, '- Send Whatsapp reminder 2h before\n- Confirm with EA via call same morning\n- Switch to recurring monthly slot', 'sales@equipseva.in', 'in_progress', 'AMC renewal discussion missed'),
  ('internal_review', '2026-06-17 09:00'::timestamptz, 'Engineering weekly - 4 engineers', 'engineering@equipseva.in', 'No agenda circulated, engineers de-prioritized', 'time_wasted', 0, false, '- Lock agenda 24h before\n- Cancel if no agenda by deadline\n- Rotate facilitator weekly', 'cto@equipseva.in', 'done', 'Agenda discipline restored'),
  ('event', '2026-06-18 11:00'::timestamptz, 'CII Healthcare Summit - panel', 'panels@cii-summit.in', 'Speaker did not register on time', 'reputation', 0, true, '- Confirm panel slots 2 weeks out\n- Send dry-run invite 5 days prior\n- Carry backup speaker', 'founder@equipseva.in', 'open', 'Lost speaking slot - reputation hit'),
  ('training', '2026-06-19 15:00'::timestamptz, 'Engineer cohort 12 - Compliance', 'training@equipseva.in', 'Conflicting on-call shift assignments', 'time_wasted', 0, false, '- Sync training calendar with on-call rota\n- Send shift swap reminder 48h prior\n- Record session as fallback', 'training@equipseva.in', 'in_progress', '3 of 8 engineers no-show');

-- Seed weekly metrics
INSERT INTO public.weekly_no_show_metrics_r2465
  (week_start, total_appointments, no_show_count, no_show_rate_pct, top_reason, total_impact_rupees, repeat_offenders_count, prevention_score, founder_pulse_md, notes)
VALUES
  ('2026-06-01', 42, 4, 9.5, 'Calendar conflicts', 1800000, 1, 62, '## Week of Jun 1\n- 4 no-shows: 1 investor, 2 customer, 1 internal\n- Prevention score 62/100\n- **Action**: tighten 24h confirm protocol', 'Baseline week'),
  ('2026-06-08', 38, 5, 13.1, 'Forgot meeting', 3200000, 2, 55, '## Week of Jun 8\n- 5 no-shows incl 2 repeat offenders\n- Prevention dropping\n- **Action**: install Whatsapp reminder bot', 'Worst week so far'),
  ('2026-06-15', 45, 5, 11.1, 'Last-minute conflicts', 2500000, 2, 68, '## Week of Jun 15\n- 5 no-shows but reminder bot live mid-week\n- Prevention up to 68\n- **Action**: enforce no-agenda-no-meeting', 'Reminder bot deployed mid-week'),
  ('2026-06-22', 40, 2, 5.0, 'On-call conflict', 800000, 0, 82, '## Week of Jun 22\n- Only 2 no-shows, zero repeat offenders\n- Prevention 82/100\n- **Action**: hold this discipline', 'Best week - prevention working');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_no_shows_r2465()
RETURNS TABLE (id uuid, appointment_kind text, scheduled_at timestamptz, party_label text, party_email text, no_show_reason text, impact_kind text, impact_rupees bigint, repeat_offender boolean, owner_email text, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.appointment_kind, n.scheduled_at, n.party_label, n.party_email, n.no_show_reason, n.impact_kind, n.impact_rupees, n.repeat_offender, n.owner_email, n.status
  FROM public.founder_no_shows_r2465 n
  ORDER BY n.scheduled_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_no_shows_r2465() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_no_shows_r2465() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_metrics_r2465()
RETURNS TABLE (id uuid, week_start date, total_appointments int, no_show_count int, no_show_rate_pct numeric, top_reason text, total_impact_rupees bigint, repeat_offenders_count int, prevention_score int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.week_start, m.total_appointments, m.no_show_count, m.no_show_rate_pct, m.top_reason, m.total_impact_rupees, m.repeat_offenders_count, m.prevention_score
  FROM public.weekly_no_show_metrics_r2465 m
  ORDER BY m.week_start DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_metrics_r2465() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_metrics_r2465() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_no_show_parties_r2465()
RETURNS TABLE (party_label text, party_email text, no_show_count bigint, total_impact_rupees bigint, last_no_show_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.party_label, n.party_email, COUNT(*)::bigint, COALESCE(SUM(n.impact_rupees), 0)::bigint, MAX(n.scheduled_at)
  FROM public.founder_no_shows_r2465 n
  GROUP BY n.party_label, n.party_email
  ORDER BY COUNT(*) DESC, SUM(n.impact_rupees) DESC NULLS LAST
  LIMIT 10;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_no_show_parties_r2465() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_no_show_parties_r2465() TO authenticated;

CREATE OR REPLACE FUNCTION public.reason_breakdown_r2465()
RETURNS TABLE (no_show_reason text, appointment_kind text, hit_count bigint, total_impact_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.no_show_reason, n.appointment_kind, COUNT(*)::bigint, COALESCE(SUM(n.impact_rupees), 0)::bigint
  FROM public.founder_no_shows_r2465 n
  GROUP BY n.no_show_reason, n.appointment_kind
  ORDER BY COUNT(*) DESC, SUM(n.impact_rupees) DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION public.reason_breakdown_r2465() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reason_breakdown_r2465() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_rate_trend_r2465()
RETURNS TABLE (week_start date, no_show_rate_pct numeric, no_show_count int, total_appointments int, prevention_score int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.week_start, m.no_show_rate_pct, m.no_show_count, m.total_appointments, m.prevention_score
  FROM public.weekly_no_show_metrics_r2465 m
  ORDER BY m.week_start ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.weekly_rate_trend_r2465() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_rate_trend_r2465() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_impact_focus_r2465()
RETURNS TABLE (party_label text, appointment_kind text, no_show_reason text, impact_kind text, impact_rupees bigint, scheduled_at timestamptz, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.party_label, n.appointment_kind, n.no_show_reason, n.impact_kind, n.impact_rupees, n.scheduled_at, n.status
  FROM public.founder_no_shows_r2465 n
  WHERE n.impact_rupees > 0
  ORDER BY n.impact_rupees DESC
  LIMIT 10;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_impact_focus_r2465() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_impact_focus_r2465() TO authenticated;

CREATE OR REPLACE FUNCTION public.repeat_offenders_focus_r2465()
RETURNS TABLE (party_label text, party_email text, appointment_kind text, no_show_count bigint, total_impact_rupees bigint, last_reason text, last_scheduled_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.party_label, n.party_email, n.appointment_kind, COUNT(*)::bigint, COALESCE(SUM(n.impact_rupees), 0)::bigint,
         (SELECT n2.no_show_reason FROM public.founder_no_shows_r2465 n2 WHERE n2.party_email = n.party_email ORDER BY n2.scheduled_at DESC LIMIT 1),
         MAX(n.scheduled_at)
  FROM public.founder_no_shows_r2465 n
  WHERE n.repeat_offender = true
  GROUP BY n.party_label, n.party_email, n.appointment_kind
  ORDER BY COUNT(*) DESC, SUM(n.impact_rupees) DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION public.repeat_offenders_focus_r2465() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repeat_offenders_focus_r2465() TO authenticated;
