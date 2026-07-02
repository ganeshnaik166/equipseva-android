-- Round r2595: Hospital chain C-suite meeting frequency
-- Track cadence of C-suite engagement across hospital chains and outcomes per meeting.

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_c_suite_meeting_cadence_r2595 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  c_suite_role text NOT NULL CHECK (c_suite_role IN ('ceo','coo','cfo','cmo','cio','chief_medical_officer','owner')),
  planned_cadence_days int NOT NULL DEFAULT 30,
  last_meeting_at timestamptz,
  next_meeting_at timestamptz,
  meetings_held_count int NOT NULL DEFAULT 0,
  actions_count int NOT NULL DEFAULT 0,
  deal_influence_kind text NOT NULL DEFAULT 'none' CHECK (deal_influence_kind IN ('none','low','medium','high','critical')),
  owner_email text,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','lagging','strong','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.c_suite_meeting_outcomes_r2595 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cadence_id uuid NOT NULL REFERENCES public.chain_c_suite_meeting_cadence_r2595(id) ON DELETE CASCADE,
  meeting_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL DEFAULT 'neutral' CHECK (outcome_kind IN ('positive','neutral','concerned','intro_offer','deal_advance')),
  summary_md text,
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_c_suite_meeting_cadence_r2595 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.c_suite_meeting_outcomes_r2595 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_c_suite_meeting_cadence_r2595;
CREATE POLICY founder_all ON public.chain_c_suite_meeting_cadence_r2595
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.c_suite_meeting_outcomes_r2595;
CREATE POLICY founder_all ON public.c_suite_meeting_outcomes_r2595
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed cadence rows
INSERT INTO public.chain_c_suite_meeting_cadence_r2595
  (chain_name, c_suite_role, planned_cadence_days, last_meeting_at, next_meeting_at, meetings_held_count, actions_count, deal_influence_kind, owner_email, status, notes)
VALUES
  ('Apollo Group', 'ceo', 30, now() - interval '12 days', now() + interval '18 days', 6, 14, 'critical', 'founder@equipseva.in', 'strong', 'Strong sponsor; pushed AMC chain deal'),
  ('Yashoda Network', 'cfo', 45, now() - interval '60 days', now() + interval '5 days', 3, 4, 'medium', 'founder@equipseva.in', 'lagging', 'Slipping cadence; CFO travel heavy'),
  ('Care Hospitals', 'coo', 30, now() - interval '20 days', now() + interval '10 days', 5, 9, 'high', 'founder@equipseva.in', 'on_track', 'COO drove pilot expansion'),
  ('KIMS Group', 'chief_medical_officer', 60, now() - interval '90 days', now() + interval '7 days', 1, 1, 'low', 'founder@equipseva.in', 'dropped', 'Lost momentum after Q1'),
  ('Continental Hospitals', 'owner', 45, now() - interval '15 days', now() + interval '30 days', 4, 7, 'high', 'founder@equipseva.in', 'on_track', 'Owner championing super-specialty');

INSERT INTO public.c_suite_meeting_outcomes_r2595
  (cadence_id, meeting_at, outcome_kind, summary_md, follow_up_required, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '12 days', 'deal_advance', 'Apollo CEO committed to AMC chain expansion across 4 sites', true, now() + interval '5 days', 'founder@equipseva.in', 'open', 'Awaiting MOU draft'
FROM public.chain_c_suite_meeting_cadence_r2595 WHERE chain_name='Apollo Group' LIMIT 1;

INSERT INTO public.c_suite_meeting_outcomes_r2595
  (cadence_id, meeting_at, outcome_kind, summary_md, follow_up_required, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '60 days', 'concerned', 'Yashoda CFO raised pricing concerns vs incumbent', true, now() + interval '2 days', 'founder@equipseva.in', 'open', 'Need pricing deck v2'
FROM public.chain_c_suite_meeting_cadence_r2595 WHERE chain_name='Yashoda Network' LIMIT 1;

INSERT INTO public.c_suite_meeting_outcomes_r2595
  (cadence_id, meeting_at, outcome_kind, summary_md, follow_up_required, owner_email, status, notes)
SELECT id, now() - interval '20 days', 'positive', 'Care COO greenlit pilot at 2 new sites', false, 'founder@equipseva.in', 'done', 'Closed action'
FROM public.chain_c_suite_meeting_cadence_r2595 WHERE chain_name='Care Hospitals' LIMIT 1;

INSERT INTO public.c_suite_meeting_outcomes_r2595
  (cadence_id, meeting_at, outcome_kind, summary_md, follow_up_required, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '15 days', 'intro_offer', 'Continental owner offered intro to two peer chains', true, now() + interval '10 days', 'founder@equipseva.in', 'open', 'Warm intros pending'
FROM public.chain_c_suite_meeting_cadence_r2595 WHERE chain_name='Continental Hospitals' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_meeting_cadence_r2595()
RETURNS TABLE(
  id uuid,
  chain_name text,
  c_suite_role text,
  planned_cadence_days int,
  last_meeting_at timestamptz,
  next_meeting_at timestamptz,
  meetings_held_count int,
  actions_count int,
  deal_influence_kind text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.chain_name, c.c_suite_role, c.planned_cadence_days, c.last_meeting_at, c.next_meeting_at,
           c.meetings_held_count, c.actions_count, c.deal_influence_kind, c.owner_email, c.status, c.notes, c.created_at
    FROM public.chain_c_suite_meeting_cadence_r2595 c
    ORDER BY c.next_meeting_at ASC NULLS LAST, c.chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_meeting_cadence_r2595() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_meeting_cadence_r2595() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_meeting_outcomes_r2595()
RETURNS TABLE(
  id uuid,
  cadence_id uuid,
  chain_name text,
  c_suite_role text,
  meeting_at timestamptz,
  outcome_kind text,
  summary_md text,
  follow_up_required boolean,
  follow_up_at timestamptz,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.cadence_id, c.chain_name, c.c_suite_role, o.meeting_at, o.outcome_kind, o.summary_md,
           o.follow_up_required, o.follow_up_at, o.owner_email, o.status, o.notes, o.created_at
    FROM public.c_suite_meeting_outcomes_r2595 o
    LEFT JOIN public.chain_c_suite_meeting_cadence_r2595 c ON c.id = o.cadence_id
    ORDER BY o.meeting_at DESC NULLS LAST, c.chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_meeting_outcomes_r2595() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_meeting_outcomes_r2595() TO authenticated;

CREATE OR REPLACE FUNCTION public.lagging_focus_r2595()
RETURNS TABLE(
  chain_name text,
  c_suite_role text,
  days_since_last numeric,
  planned_cadence_days int,
  overdue_days numeric,
  status text,
  deal_influence_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_name, c.c_suite_role,
           ROUND(EXTRACT(EPOCH FROM (now() - c.last_meeting_at)) / 86400.0, 1) AS days_since_last,
           c.planned_cadence_days,
           ROUND(EXTRACT(EPOCH FROM (now() - c.last_meeting_at)) / 86400.0 - c.planned_cadence_days, 1) AS overdue_days,
           c.status,
           c.deal_influence_kind
    FROM public.chain_c_suite_meeting_cadence_r2595 c
    WHERE c.last_meeting_at IS NOT NULL
      AND EXTRACT(EPOCH FROM (now() - c.last_meeting_at)) / 86400.0 > c.planned_cadence_days
    ORDER BY (EXTRACT(EPOCH FROM (now() - c.last_meeting_at)) / 86400.0 - c.planned_cadence_days) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.lagging_focus_r2595() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lagging_focus_r2595() TO authenticated;

CREATE OR REPLACE FUNCTION public.role_distribution_r2595()
RETURNS TABLE(
  c_suite_role text,
  cadence_count bigint,
  total_meetings_held bigint,
  total_actions bigint,
  avg_planned_cadence_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.c_suite_role,
           COUNT(*)::bigint AS cadence_count,
           COALESCE(SUM(c.meetings_held_count),0)::bigint AS total_meetings_held,
           COALESCE(SUM(c.actions_count),0)::bigint AS total_actions,
           ROUND(AVG(c.planned_cadence_days)::numeric, 1) AS avg_planned_cadence_days
    FROM public.chain_c_suite_meeting_cadence_r2595 c
    GROUP BY c.c_suite_role
    ORDER BY COUNT(*) DESC NULLS LAST, c.c_suite_role ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.role_distribution_r2595() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_distribution_r2595() TO authenticated;

CREATE OR REPLACE FUNCTION public.deal_influence_summary_r2595()
RETURNS TABLE(
  deal_influence_kind text,
  chain_count bigint,
  total_actions bigint,
  total_meetings bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.deal_influence_kind,
           COUNT(*)::bigint AS chain_count,
           COALESCE(SUM(c.actions_count),0)::bigint AS total_actions,
           COALESCE(SUM(c.meetings_held_count),0)::bigint AS total_meetings
    FROM public.chain_c_suite_meeting_cadence_r2595 c
    GROUP BY c.deal_influence_kind
    ORDER BY COUNT(*) DESC NULLS LAST, c.deal_influence_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.deal_influence_summary_r2595() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deal_influence_summary_r2595() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_meeting_trend_r2595()
RETURNS TABLE(
  month_start timestamptz,
  meeting_count bigint,
  positive_count bigint,
  concerned_count bigint,
  deal_advance_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', o.meeting_at)::timestamptz AS month_start,
           COUNT(*)::bigint AS meeting_count,
           COUNT(*) FILTER (WHERE o.outcome_kind = 'positive')::bigint AS positive_count,
           COUNT(*) FILTER (WHERE o.outcome_kind = 'concerned')::bigint AS concerned_count,
           COUNT(*) FILTER (WHERE o.outcome_kind = 'deal_advance')::bigint AS deal_advance_count
    FROM public.c_suite_meeting_outcomes_r2595 o
    GROUP BY date_trunc('month', o.meeting_at)
    ORDER BY date_trunc('month', o.meeting_at) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_meeting_trend_r2595() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_meeting_trend_r2595() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2595()
RETURNS TABLE(
  owner_email text,
  cadence_count bigint,
  open_followups bigint,
  total_meetings_held bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.owner_email,
           COUNT(DISTINCT c.id)::bigint AS cadence_count,
           COUNT(o.id) FILTER (WHERE o.status = 'open' AND o.follow_up_required = true)::bigint AS open_followups,
           COALESCE(SUM(c.meetings_held_count),0)::bigint AS total_meetings_held
    FROM public.chain_c_suite_meeting_cadence_r2595 c
    LEFT JOIN public.c_suite_meeting_outcomes_r2595 o ON o.cadence_id = c.id
    GROUP BY c.owner_email
    ORDER BY COUNT(DISTINCT c.id) DESC NULLS LAST, c.owner_email ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2595() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2595() TO authenticated;

