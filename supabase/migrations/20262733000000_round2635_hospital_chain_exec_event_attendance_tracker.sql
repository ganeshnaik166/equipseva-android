BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_exec_event_attendance_r2635 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_label text NOT NULL,
  event_at timestamptz NOT NULL,
  exec_role text NOT NULL CHECK (exec_role IN ('ceo','coo','cfo','cmo','cio','chief_medical_officer','owner')),
  attended boolean NOT NULL DEFAULT false,
  our_attendees_md text NOT NULL DEFAULT '',
  engagement_score int NOT NULL DEFAULT 0 CHECK (engagement_score BETWEEN 0 AND 100),
  deal_advancement_kind text NOT NULL DEFAULT 'none' CHECK (deal_advancement_kind IN ('none','awareness','interest','commitment','close')),
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.exec_event_follow_ups_r2635 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id uuid NOT NULL REFERENCES public.chain_exec_event_attendance_r2635(id) ON DELETE CASCADE,
  follow_up_at timestamptz NOT NULL,
  follow_up_kind text NOT NULL CHECK (follow_up_kind IN ('call','email','meeting','proposal','intro')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_exec_event_attendance_r2635 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exec_event_follow_ups_r2635 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_exec_event_attendance_r2635;
CREATE POLICY founder_all ON public.chain_exec_event_attendance_r2635
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.exec_event_follow_ups_r2635;
CREATE POLICY founder_all ON public.exec_event_follow_ups_r2635
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_attendance
CREATE OR REPLACE FUNCTION public.list_attendance_r2635()
RETURNS TABLE (
  id uuid,
  chain_name text,
  event_label text,
  event_at timestamptz,
  exec_role text,
  attended boolean,
  engagement_score int,
  deal_advancement_kind text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.event_label, a.event_at, a.exec_role, a.attended,
         a.engagement_score, a.deal_advancement_kind, a.owner_email, a.status
  FROM public.chain_exec_event_attendance_r2635 a
  ORDER BY a.event_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_attendance_r2635() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attendance_r2635() TO authenticated;

-- RPC 2: list_follow_ups
CREATE OR REPLACE FUNCTION public.list_follow_ups_r2635()
RETURNS TABLE (
  id uuid,
  attendance_id uuid,
  chain_name text,
  event_label text,
  follow_up_at timestamptz,
  follow_up_kind text,
  outcome text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.attendance_id, a.chain_name, a.event_label,
         f.follow_up_at, f.follow_up_kind, f.outcome, f.owner_email, f.status
  FROM public.exec_event_follow_ups_r2635 f
  JOIN public.chain_exec_event_attendance_r2635 a ON a.id = f.attendance_id
  ORDER BY f.follow_up_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_follow_ups_r2635() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_follow_ups_r2635() TO authenticated;

-- RPC 3: top_engagement_focus
CREATE OR REPLACE FUNCTION public.top_engagement_focus_r2635()
RETURNS TABLE (
  chain_name text,
  events_attended int,
  avg_engagement numeric,
  max_engagement int,
  deal_close_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name,
         COUNT(*) FILTER (WHERE a.attended)::int AS events_attended,
         ROUND(AVG(a.engagement_score)::numeric, 2) AS avg_engagement,
         MAX(a.engagement_score)::int AS max_engagement,
         COUNT(*) FILTER (WHERE a.deal_advancement_kind = 'close')::int AS deal_close_count
  FROM public.chain_exec_event_attendance_r2635 a
  GROUP BY a.chain_name
  ORDER BY avg_engagement DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_engagement_focus_r2635() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_engagement_focus_r2635() TO authenticated;

-- RPC 4: exec_role_distribution
CREATE OR REPLACE FUNCTION public.exec_role_distribution_r2635()
RETURNS TABLE (
  exec_role text,
  total_events int,
  attended_count int,
  avg_engagement numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.exec_role,
         COUNT(*)::int AS total_events,
         COUNT(*) FILTER (WHERE a.attended)::int AS attended_count,
         ROUND(AVG(a.engagement_score)::numeric, 2) AS avg_engagement
  FROM public.chain_exec_event_attendance_r2635 a
  GROUP BY a.exec_role
  ORDER BY total_events DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.exec_role_distribution_r2635() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.exec_role_distribution_r2635() TO authenticated;

-- RPC 5: status_funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2635()
RETURNS TABLE (
  status text,
  event_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status, COUNT(*)::int AS event_count
  FROM public.chain_exec_event_attendance_r2635 a
  GROUP BY a.status
  ORDER BY event_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2635() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2635() TO authenticated;

-- RPC 6: deal_advancement_summary
CREATE OR REPLACE FUNCTION public.deal_advancement_summary_r2635()
RETURNS TABLE (
  deal_advancement_kind text,
  event_count int,
  avg_engagement numeric,
  follow_up_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.deal_advancement_kind,
         COUNT(*)::int AS event_count,
         ROUND(AVG(a.engagement_score)::numeric, 2) AS avg_engagement,
         (SELECT COUNT(*)::int FROM public.exec_event_follow_ups_r2635 f
            JOIN public.chain_exec_event_attendance_r2635 a2 ON a2.id = f.attendance_id
            WHERE a2.deal_advancement_kind = a.deal_advancement_kind) AS follow_up_count
  FROM public.chain_exec_event_attendance_r2635 a
  GROUP BY a.deal_advancement_kind
  ORDER BY event_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.deal_advancement_summary_r2635() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deal_advancement_summary_r2635() TO authenticated;

-- RPC 7: monthly_event_trend
CREATE OR REPLACE FUNCTION public.monthly_event_trend_r2635()
RETURNS TABLE (
  month_start date,
  event_count int,
  attended_count int,
  avg_engagement numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.event_at)::date AS month_start,
         COUNT(*)::int AS event_count,
         COUNT(*) FILTER (WHERE a.attended)::int AS attended_count,
         ROUND(AVG(a.engagement_score)::numeric, 2) AS avg_engagement
  FROM public.chain_exec_event_attendance_r2635 a
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_event_trend_r2635() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_event_trend_r2635() TO authenticated;

-- Seed
INSERT INTO public.chain_exec_event_attendance_r2635
  (chain_name, event_label, event_at, exec_role, attended, our_attendees_md, engagement_score, deal_advancement_kind, owner_email, status, notes)
VALUES
  ('Apollo Hospitals', 'CIO Tech Summit Mumbai', '2026-05-12 10:00:00'::timestamptz, 'cio', true, 'Ganesh + Priya', 82, 'interest', 'gd@equipseva.com', 'done', 'Strong CIO interest in AMC dashboard'),
  ('Fortis Healthcare', 'CFO Roundtable Bengaluru', '2026-05-18 14:00:00'::timestamptz, 'cfo', true, 'Ganesh', 71, 'awareness', 'gd@equipseva.com', 'done', 'CFO open to pilot Q3'),
  ('Manipal Hospitals', 'COO Operations Forum', '2026-06-04 09:30:00'::timestamptz, 'coo', true, 'Priya', 88, 'commitment', 'priya@equipseva.com', 'done', 'COO verbal commit on 4-hospital pilot'),
  ('Max Healthcare', 'CEO Healthcare India', '2026-06-15 11:00:00'::timestamptz, 'ceo', false, 'No attendees', 25, 'none', 'gd@equipseva.com', 'cancelled', 'CEO travel conflict'),
  ('Narayana Health', 'CMO Clinical Excellence', '2026-06-20 15:00:00'::timestamptz, 'chief_medical_officer', true, 'Ganesh + Anil', 76, 'interest', 'gd@equipseva.com', 'done', 'CMO requested case studies');

INSERT INTO public.exec_event_follow_ups_r2635
  (attendance_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-20 10:00:00'::timestamptz, 'email', 'positive', 'gd@equipseva.com', 'closed', 'Sent AMC deck and pricing'
FROM public.chain_exec_event_attendance_r2635 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.exec_event_follow_ups_r2635
  (attendance_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-08 14:00:00'::timestamptz, 'meeting', 'positive', 'priya@equipseva.com', 'in_progress', 'Onsite walkthrough scheduled'
FROM public.chain_exec_event_attendance_r2635 WHERE chain_name = 'Manipal Hospitals' LIMIT 1;

INSERT INTO public.exec_event_follow_ups_r2635
  (attendance_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-22 11:00:00'::timestamptz, 'proposal', 'pending', 'gd@equipseva.com', 'open', 'Proposal draft pending legal'
FROM public.chain_exec_event_attendance_r2635 WHERE chain_name = 'Narayana Health' LIMIT 1;

COMMIT;
