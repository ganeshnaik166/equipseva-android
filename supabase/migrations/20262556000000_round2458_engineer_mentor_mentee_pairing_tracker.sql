-- Round 2458: Engineer mentor-mentee pairing tracker
-- Senior mentor x junior mentee x pairing weeks x ramp lift x meeting cadence x mentor bonus

CREATE TABLE IF NOT EXISTS public.mentor_pairings_r2458 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  mentee_engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  pairing_start timestamptz NOT NULL,
  pairing_end timestamptz,
  pairing_weeks int NOT NULL CHECK (pairing_weeks > 0 AND pairing_weeks <= 52),
  planned_meetings_per_week int NOT NULL CHECK (planned_meetings_per_week >= 1 AND planned_meetings_per_week <= 7),
  actual_meetings_count int NOT NULL DEFAULT 0 CHECK (actual_meetings_count >= 0),
  ramp_score_lift_pct numeric(6,2) NOT NULL DEFAULT 0 CHECK (ramp_score_lift_pct >= -100 AND ramp_score_lift_pct <= 500),
  mentor_bonus_rupees int NOT NULL DEFAULT 0 CHECK (mentor_bonus_rupees >= 0),
  status text NOT NULL CHECK (status IN ('active','completed','dropped','at_risk')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mentor_pairing_meetings_r2458 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pairing_id uuid NOT NULL REFERENCES public.mentor_pairings_r2458(id) ON DELETE CASCADE,
  meeting_at timestamptz NOT NULL,
  duration_minutes int NOT NULL CHECK (duration_minutes > 0 AND duration_minutes <= 480),
  agenda text,
  completion_score int NOT NULL DEFAULT 0 CHECK (completion_score >= 0 AND completion_score <= 100),
  blockers_md text,
  next_focus text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mentor_pairings_r2458 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_pairing_meetings_r2458 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.mentor_pairings_r2458;
CREATE POLICY founder_all ON public.mentor_pairings_r2458 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.mentor_pairing_meetings_r2458;
CREATE POLICY founder_all ON public.mentor_pairing_meetings_r2458 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_mentor_a uuid;
  v_mentor_b uuid;
  v_mentee_a uuid;
  v_mentee_b uuid;
  v_mentee_c uuid;
  v_pair_1 uuid;
  v_pair_2 uuid;
  v_pair_3 uuid;
  v_pair_4 uuid;
BEGIN
  SELECT id INTO v_mentor_a FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_mentor_b FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_mentee_a FROM public.engineers ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_mentee_b FROM public.engineers ORDER BY created_at DESC OFFSET 1 LIMIT 1;
  SELECT id INTO v_mentee_c FROM public.engineers ORDER BY created_at DESC OFFSET 2 LIMIT 1;

  IF v_mentor_a IS NULL OR v_mentee_a IS NULL THEN
    RETURN;
  END IF;

  IF v_mentor_b IS NULL THEN v_mentor_b := v_mentor_a; END IF;
  IF v_mentee_b IS NULL THEN v_mentee_b := v_mentee_a; END IF;
  IF v_mentee_c IS NULL THEN v_mentee_c := v_mentee_a; END IF;

  INSERT INTO public.mentor_pairings_r2458
    (mentor_engineer_user_id, mentee_engineer_user_id, pairing_start, pairing_end, pairing_weeks,
     planned_meetings_per_week, actual_meetings_count, ramp_score_lift_pct, mentor_bonus_rupees, status, outcome, notes)
  VALUES (v_mentor_a, v_mentee_a, '2026-04-01'::timestamptz, '2026-06-10'::timestamptz, 10,
          2, 19, 38.50, 12000, 'completed', 'positive', 'Mentee certified L2 after 10 weeks')
  RETURNING id INTO v_pair_1;

  INSERT INTO public.mentor_pairings_r2458
    (mentor_engineer_user_id, mentee_engineer_user_id, pairing_start, pairing_end, pairing_weeks,
     planned_meetings_per_week, actual_meetings_count, ramp_score_lift_pct, mentor_bonus_rupees, status, outcome, notes)
  VALUES (v_mentor_b, v_mentee_b, '2026-05-15'::timestamptz, NULL, 12,
          2, 9, 22.00, 0, 'active', 'pending', 'On track week 6 of 12')
  RETURNING id INTO v_pair_2;

  INSERT INTO public.mentor_pairings_r2458
    (mentor_engineer_user_id, mentee_engineer_user_id, pairing_start, pairing_end, pairing_weeks,
     planned_meetings_per_week, actual_meetings_count, ramp_score_lift_pct, mentor_bonus_rupees, status, outcome, notes)
  VALUES (v_mentor_a, v_mentee_c, '2026-05-01'::timestamptz, NULL, 8,
          3, 7, 5.50, 0, 'at_risk', 'pending', 'Cadence slipping - 7/21 expected')
  RETURNING id INTO v_pair_3;

  INSERT INTO public.mentor_pairings_r2458
    (mentor_engineer_user_id, mentee_engineer_user_id, pairing_start, pairing_end, pairing_weeks,
     planned_meetings_per_week, actual_meetings_count, ramp_score_lift_pct, mentor_bonus_rupees, status, outcome, notes)
  VALUES (v_mentor_b, v_mentee_a, '2026-02-01'::timestamptz, '2026-03-15'::timestamptz, 6,
          2, 3, -2.00, 0, 'dropped', 'negative', 'Mentee left for hospital role')
  RETURNING id INTO v_pair_4;

  INSERT INTO public.mentor_pairing_meetings_r2458
    (pairing_id, meeting_at, duration_minutes, agenda, completion_score, blockers_md, next_focus, notes)
  VALUES
    (v_pair_1, '2026-04-08'::timestamptz, 60, 'Onboarding + tool kit walkthrough', 90, NULL, 'CT scanner module basics', 'Strong start'),
    (v_pair_1, '2026-05-20'::timestamptz, 45, 'Mid-pairing check-in', 85, '- multimeter calibration', 'PCB rework practice', 'Confident pace'),
    (v_pair_2, '2026-05-22'::timestamptz, 50, 'Kickoff + escalation protocols', 80, NULL, 'Field shadowing', 'Schedule first ride-along'),
    (v_pair_3, '2026-05-10'::timestamptz, 30, 'First touchpoint', 60, '- mentee no-show on 2 calls', 'Re-establish cadence', 'Flag at-risk'),
    (v_pair_3, '2026-06-12'::timestamptz, 40, 'Recovery plan', 55, '- still behind cadence', 'Weekly written report', 'Founder reviewing');
END;
$seed$;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_pairings_r2458()
RETURNS TABLE (
  id uuid,
  mentor_engineer_user_id uuid,
  mentee_engineer_user_id uuid,
  pairing_start timestamptz,
  pairing_end timestamptz,
  pairing_weeks int,
  planned_meetings_per_week int,
  actual_meetings_count int,
  ramp_score_lift_pct numeric,
  mentor_bonus_rupees int,
  status text,
  outcome text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.mentor_engineer_user_id, p.mentee_engineer_user_id, p.pairing_start, p.pairing_end,
           p.pairing_weeks, p.planned_meetings_per_week, p.actual_meetings_count,
           p.ramp_score_lift_pct, p.mentor_bonus_rupees, p.status, p.outcome, p.notes, p.created_at
    FROM public.mentor_pairings_r2458 p
    ORDER BY p.pairing_start DESC NULLS LAST, p.created_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pairings_r2458() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pairings_r2458() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_meetings_r2458()
RETURNS TABLE (
  id uuid,
  pairing_id uuid,
  meeting_at timestamptz,
  duration_minutes int,
  agenda text,
  completion_score int,
  blockers_md text,
  next_focus text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.pairing_id, m.meeting_at, m.duration_minutes, m.agenda, m.completion_score,
           m.blockers_md, m.next_focus, m.notes, m.created_at
    FROM public.mentor_pairing_meetings_r2458 m
    ORDER BY m.meeting_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_meetings_r2458() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_meetings_r2458() TO authenticated;

CREATE OR REPLACE FUNCTION public.active_pairings_r2458()
RETURNS TABLE (
  id uuid,
  mentor_engineer_user_id uuid,
  mentee_engineer_user_id uuid,
  pairing_weeks int,
  weeks_elapsed int,
  actual_meetings_count int,
  planned_meetings_total int,
  cadence_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.mentor_engineer_user_id, p.mentee_engineer_user_id, p.pairing_weeks,
           GREATEST(0, LEAST(p.pairing_weeks, (EXTRACT(EPOCH FROM (now() - p.pairing_start)) / 604800)::int)) AS weeks_elapsed,
           p.actual_meetings_count,
           (p.pairing_weeks * p.planned_meetings_per_week) AS planned_meetings_total,
           CASE WHEN (p.pairing_weeks * p.planned_meetings_per_week) > 0
                THEN ROUND((p.actual_meetings_count::numeric / (p.pairing_weeks * p.planned_meetings_per_week)::numeric) * 100, 2)
                ELSE 0 END AS cadence_pct,
           p.status
    FROM public.mentor_pairings_r2458 p
    WHERE p.status IN ('active','at_risk')
    ORDER BY p.pairing_start ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.active_pairings_r2458() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_pairings_r2458() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_lift_pairings_r2458()
RETURNS TABLE (
  id uuid,
  mentor_engineer_user_id uuid,
  mentee_engineer_user_id uuid,
  ramp_score_lift_pct numeric,
  pairing_weeks int,
  status text,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.mentor_engineer_user_id, p.mentee_engineer_user_id, p.ramp_score_lift_pct,
           p.pairing_weeks, p.status, p.outcome
    FROM public.mentor_pairings_r2458 p
    WHERE p.status IN ('completed','active')
    ORDER BY p.ramp_score_lift_pct DESC NULLS LAST
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lift_pairings_r2458() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lift_pairings_r2458() TO authenticated;

CREATE OR REPLACE FUNCTION public.mentor_load_r2458()
RETURNS TABLE (
  mentor_engineer_user_id uuid,
  total_pairings int,
  active_pairings int,
  completed_pairings int,
  avg_lift_pct numeric,
  total_bonus_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.mentor_engineer_user_id,
           COUNT(*)::int AS total_pairings,
           COUNT(*) FILTER (WHERE p.status IN ('active','at_risk'))::int AS active_pairings,
           COUNT(*) FILTER (WHERE p.status = 'completed')::int AS completed_pairings,
           ROUND(AVG(p.ramp_score_lift_pct), 2) AS avg_lift_pct,
           COALESCE(SUM(p.mentor_bonus_rupees), 0)::bigint AS total_bonus_rupees
    FROM public.mentor_pairings_r2458 p
    GROUP BY p.mentor_engineer_user_id
    ORDER BY total_pairings DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mentor_load_r2458() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mentor_load_r2458() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_meeting_compliance_r2458()
RETURNS TABLE (
  week_start timestamptz,
  meetings_count int,
  avg_completion numeric,
  avg_duration_minutes numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('week', m.meeting_at) AS week_start,
           COUNT(*)::int AS meetings_count,
           ROUND(AVG(m.completion_score), 2) AS avg_completion,
           ROUND(AVG(m.duration_minutes), 2) AS avg_duration_minutes
    FROM public.mentor_pairing_meetings_r2458 m
    GROUP BY date_trunc('week', m.meeting_at)
    ORDER BY week_start DESC
    LIMIT 26;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_meeting_compliance_r2458() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_meeting_compliance_r2458() TO authenticated;

CREATE OR REPLACE FUNCTION public.mentor_bonus_summary_r2458()
RETURNS TABLE (
  status text,
  pairings_count int,
  total_bonus_rupees bigint,
  avg_bonus_rupees numeric,
  avg_lift_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.status,
           COUNT(*)::int AS pairings_count,
           COALESCE(SUM(p.mentor_bonus_rupees), 0)::bigint AS total_bonus_rupees,
           ROUND(AVG(p.mentor_bonus_rupees), 2) AS avg_bonus_rupees,
           ROUND(AVG(p.ramp_score_lift_pct), 2) AS avg_lift_pct
    FROM public.mentor_pairings_r2458 p
    GROUP BY p.status
    ORDER BY total_bonus_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mentor_bonus_summary_r2458() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mentor_bonus_summary_r2458() TO authenticated;
