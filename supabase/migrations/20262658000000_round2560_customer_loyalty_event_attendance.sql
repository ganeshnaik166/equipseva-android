-- Round 2560: customer loyalty event attendance
-- Tracks hospital customer engagement at events, bond strengthening, ARR uplift, follow-ups.

BEGIN;

-- Main attendance table
CREATE TABLE IF NOT EXISTS public.customer_loyalty_event_attendance_r2560 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_label text NOT NULL,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('annual_summit','dinner','webinar','training','conference','networking')),
  invited boolean NOT NULL DEFAULT true,
  attended boolean NOT NULL DEFAULT false,
  engagement_score int NOT NULL DEFAULT 0 CHECK (engagement_score BETWEEN 0 AND 100),
  bond_strength_kind text NOT NULL CHECK (bond_strength_kind IN ('weak','developing','strong','champion')),
  arr_uplift_estimate_rupees bigint NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('planned','confirmed','no_show','attended')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Follow-ups table
CREATE TABLE IF NOT EXISTS public.event_bond_followups_r2560 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id uuid NOT NULL REFERENCES public.customer_loyalty_event_attendance_r2560(id) ON DELETE CASCADE,
  followup_at timestamptz NOT NULL DEFAULT now(),
  followup_kind text NOT NULL CHECK (followup_kind IN ('call','email','site_visit','gift','exclusive_pricing')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.customer_loyalty_event_attendance_r2560 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_bond_followups_r2560 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_loyalty_event_attendance_r2560;
CREATE POLICY founder_all ON public.customer_loyalty_event_attendance_r2560
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.event_bond_followups_r2560;
CREATE POLICY founder_all ON public.event_bond_followups_r2560
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed: pick a few real hospital profiles
DO $seed$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_a1 uuid;
  v_a2 uuid;
  v_a3 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, gen_random_uuid()) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, gen_random_uuid()), COALESCE(v_h2, gen_random_uuid())) ORDER BY created_at ASC LIMIT 1;

  IF v_h1 IS NULL THEN
    RETURN; -- no hospital profiles to seed against
  END IF;

  INSERT INTO public.customer_loyalty_event_attendance_r2560
    (hospital_user_id, event_label, event_at, event_kind, invited, attended, engagement_score, bond_strength_kind, arr_uplift_estimate_rupees, owner_email, status, notes)
  VALUES
    (v_h1, 'EquipSeva Annual Summit 2026', now() - interval '14 days', 'annual_summit', true, true, 88, 'champion', 1800000, 'founder@equipseva.in', 'attended', 'CEO attended both days, signed MoU for AMC expansion')
  RETURNING id INTO v_a1;

  INSERT INTO public.customer_loyalty_event_attendance_r2560
    (hospital_user_id, event_label, event_at, event_kind, invited, attended, engagement_score, bond_strength_kind, arr_uplift_estimate_rupees, owner_email, status, notes)
  VALUES
    (COALESCE(v_h2, v_h1), 'Cardio Equipment Webinar', now() - interval '7 days', 'webinar', true, true, 62, 'developing', 350000, 'founder@equipseva.in', 'attended', 'Biomed eng asked detailed Q on cath lab uptime SLA')
  RETURNING id INTO v_a2;

  INSERT INTO public.customer_loyalty_event_attendance_r2560
    (hospital_user_id, event_label, event_at, event_kind, invited, attended, engagement_score, bond_strength_kind, arr_uplift_estimate_rupees, owner_email, status, notes)
  VALUES
    (COALESCE(v_h3, v_h1), 'Founders Dinner Hyderabad', now() - interval '21 days', 'dinner', true, false, 0, 'weak', 0, 'founder@equipseva.in', 'no_show', 'CFO confirmed then ghosted day-of')
  RETURNING id INTO v_a3;

  INSERT INTO public.customer_loyalty_event_attendance_r2560
    (hospital_user_id, event_label, event_at, event_kind, invited, attended, engagement_score, bond_strength_kind, arr_uplift_estimate_rupees, owner_email, status, notes)
  VALUES
    (v_h1, 'Biomed Engineer Training Bootcamp', now() - interval '3 days', 'training', true, true, 75, 'strong', 600000, 'founder@equipseva.in', 'attended', '5 of their engineers completed certification');

  -- Follow-ups
  IF v_a1 IS NOT NULL THEN
    INSERT INTO public.event_bond_followups_r2560
      (attendance_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES
      (v_a1, now() - interval '10 days', 'call', 'positive', 'founder@equipseva.in', 'done', 'Confirmed Q3 AMC expansion to 2 more sites');
  END IF;

  IF v_a2 IS NOT NULL THEN
    INSERT INTO public.event_bond_followups_r2560
      (attendance_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES
      (v_a2, now() - interval '4 days', 'email', 'pending', 'founder@equipseva.in', 'in_progress', 'Sent cath lab uptime case study, awaiting reply');
  END IF;

  IF v_a3 IS NOT NULL THEN
    INSERT INTO public.event_bond_followups_r2560
      (attendance_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES
      (v_a3, now() - interval '15 days', 'site_visit', 'negative', 'founder@equipseva.in', 'dropped', 'CFO unreachable, deprioritized for now');
  END IF;
END
$seed$;

-- RPCs ----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_attendance_r2560()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  event_label text,
  event_at timestamptz,
  event_kind text,
  invited boolean,
  attended boolean,
  engagement_score int,
  bond_strength_kind text,
  arr_uplift_estimate_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id,
           a.hospital_user_id,
           p.email,
           a.event_label,
           a.event_at,
           a.event_kind,
           a.invited,
           a.attended,
           a.engagement_score,
           a.bond_strength_kind,
           a.arr_uplift_estimate_rupees,
           a.owner_email,
           a.status,
           a.notes,
           a.created_at
      FROM public.customer_loyalty_event_attendance_r2560 a
      LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
     ORDER BY a.event_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_attendance_r2560() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attendance_r2560() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_followups_r2560()
RETURNS TABLE (
  id uuid,
  attendance_id uuid,
  event_label text,
  hospital_email text,
  followup_at timestamptz,
  followup_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id,
           f.attendance_id,
           a.event_label,
           p.email,
           f.followup_at,
           f.followup_kind,
           f.outcome,
           f.owner_email,
           f.status,
           f.notes,
           f.created_at
      FROM public.event_bond_followups_r2560 f
      LEFT JOIN public.customer_loyalty_event_attendance_r2560 a ON a.id = f.attendance_id
      LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
     ORDER BY f.followup_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followups_r2560() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followups_r2560() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_arr_uplift_customers_r2560()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  events_attended bigint,
  total_arr_uplift_rupees bigint,
  avg_engagement numeric,
  best_bond text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.hospital_user_id,
           p.email,
           COUNT(*) FILTER (WHERE a.attended) AS events_attended,
           COALESCE(SUM(a.arr_uplift_estimate_rupees), 0)::bigint AS total_arr_uplift_rupees,
           ROUND(AVG(a.engagement_score)::numeric, 1) AS avg_engagement,
           MAX(a.bond_strength_kind) AS best_bond
      FROM public.customer_loyalty_event_attendance_r2560 a
      LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
     GROUP BY a.hospital_user_id, p.email
     ORDER BY total_arr_uplift_rupees DESC NULLS LAST
     LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_arr_uplift_customers_r2560() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_uplift_customers_r2560() TO authenticated;

CREATE OR REPLACE FUNCTION public.event_kind_breakdown_r2560()
RETURNS TABLE (
  event_kind text,
  events_count bigint,
  attended_count bigint,
  total_arr_uplift_rupees bigint,
  avg_engagement numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.event_kind,
           COUNT(*) AS events_count,
           COUNT(*) FILTER (WHERE a.attended) AS attended_count,
           COALESCE(SUM(a.arr_uplift_estimate_rupees), 0)::bigint AS total_arr_uplift_rupees,
           ROUND(AVG(a.engagement_score)::numeric, 1) AS avg_engagement
      FROM public.customer_loyalty_event_attendance_r2560 a
     GROUP BY a.event_kind
     ORDER BY total_arr_uplift_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.event_kind_breakdown_r2560() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.event_kind_breakdown_r2560() TO authenticated;

CREATE OR REPLACE FUNCTION public.bond_strength_distribution_r2560()
RETURNS TABLE (
  bond_strength_kind text,
  hospital_count bigint,
  total_arr_uplift_rupees bigint,
  pct_of_attended numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT NULLIF(COUNT(*) FILTER (WHERE attended), 0) INTO v_total
    FROM public.customer_loyalty_event_attendance_r2560;

  RETURN QUERY
    SELECT a.bond_strength_kind,
           COUNT(DISTINCT a.hospital_user_id) AS hospital_count,
           COALESCE(SUM(a.arr_uplift_estimate_rupees), 0)::bigint AS total_arr_uplift_rupees,
           CASE WHEN v_total IS NULL THEN 0::numeric
                ELSE ROUND((COUNT(*) FILTER (WHERE a.attended))::numeric * 100.0 / v_total, 1)
           END AS pct_of_attended
      FROM public.customer_loyalty_event_attendance_r2560 a
     GROUP BY a.bond_strength_kind
     ORDER BY total_arr_uplift_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.bond_strength_distribution_r2560() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bond_strength_distribution_r2560() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_attendance_trend_r2560()
RETURNS TABLE (
  month_start timestamptz,
  events_count bigint,
  attended_count bigint,
  no_show_count bigint,
  total_arr_uplift_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', a.event_at) AS month_start,
           COUNT(*) AS events_count,
           COUNT(*) FILTER (WHERE a.attended) AS attended_count,
           COUNT(*) FILTER (WHERE a.status = 'no_show') AS no_show_count,
           COALESCE(SUM(a.arr_uplift_estimate_rupees), 0)::bigint AS total_arr_uplift_rupees
      FROM public.customer_loyalty_event_attendance_r2560 a
     GROUP BY date_trunc('month', a.event_at)
     ORDER BY month_start DESC NULLS LAST
     LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_attendance_trend_r2560() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_attendance_trend_r2560() TO authenticated;

CREATE OR REPLACE FUNCTION public.no_show_focus_r2560()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  event_label text,
  event_at timestamptz,
  event_kind text,
  bond_strength_kind text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id,
           a.hospital_user_id,
           p.email,
           a.event_label,
           a.event_at,
           a.event_kind,
           a.bond_strength_kind,
           a.owner_email,
           a.notes
      FROM public.customer_loyalty_event_attendance_r2560 a
      LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
     WHERE a.status = 'no_show' OR (a.invited AND NOT a.attended)
     ORDER BY a.event_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.no_show_focus_r2560() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.no_show_focus_r2560() TO authenticated;

