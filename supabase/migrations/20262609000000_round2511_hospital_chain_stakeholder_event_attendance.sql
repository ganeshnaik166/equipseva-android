-- Round 2511 — hospital chain stakeholder event attendance
-- chain × event × stakeholder attended × prep × follow-up × deal influence × cost

CREATE TABLE IF NOT EXISTS public.chain_stakeholder_events_r2511 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_name text NOT NULL,
  event_kind text NOT NULL CHECK (event_kind IN ('webinar','conference','dinner','site_visit','exec_lunch','workshop')),
  held_at timestamptz NOT NULL,
  stakeholder_name text NOT NULL,
  stakeholder_role text,
  attended boolean NOT NULL DEFAULT false,
  prep_summary_md text,
  follow_up_summary_md text,
  deal_influence text NOT NULL DEFAULT 'none' CHECK (deal_influence IN ('none','low','medium','high','critical')),
  cost_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  notes text
);

CREATE TABLE IF NOT EXISTS public.event_followup_outcomes_r2511 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  event_id uuid NOT NULL REFERENCES public.chain_stakeholder_events_r2511(id) ON DELETE CASCADE,
  outcome_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('meeting_booked','proposal_sent','deal_advanced','no_follow_up','passed')),
  revenue_influenced_rupees bigint NOT NULL DEFAULT 0,
  next_step text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text
);

ALTER TABLE public.chain_stakeholder_events_r2511 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_followup_outcomes_r2511 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_stakeholder_events_r2511;
CREATE POLICY founder_all ON public.chain_stakeholder_events_r2511
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.event_followup_outcomes_r2511;
CREATE POLICY founder_all ON public.event_followup_outcomes_r2511
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.chain_stakeholder_events_r2511
  (chain_name, event_name, event_kind, held_at, stakeholder_name, stakeholder_role, attended, prep_summary_md, follow_up_summary_md, deal_influence, cost_rupees, owner_email, notes)
VALUES
  ('Apollo Group','Q2 Biomedical Equipment Webinar','webinar','2026-05-12 11:00:00+05:30'::timestamptz,'Dr. Suresh Rao','Chief Biomedical Engineer',true,'## Prep\n- Reviewed Apollo PM contract gaps\n- Prepared 3-slide AMC pitch','## Follow-up\n- Asked for AMC proposal across 4 sites','high',12000,'founder@equipseva.com','Strong engagement; deal advancing'),
  ('Manipal Hospitals','South India Medical Tech Conference','conference','2026-05-18 09:30:00+05:30'::timestamptz,'Priya Menon','VP Procurement',true,'## Prep\n- Brought 2 case studies\n- Booked dinner slot','## Follow-up\n- Site visit scheduled for r2511 cluster','critical',85000,'founder@equipseva.com','High-influence touchpoint'),
  ('Fortis Healthcare','Founder Exec Lunch','exec_lunch','2026-05-22 13:00:00+05:30'::timestamptz,'Anil Kapoor','Group CTO',true,'## Prep\n- Hospital chain ops pitch deck\n- Highlight chain bulk pricing','## Follow-up\n- Proposal sent for 7-site rollout','high',24000,'founder@equipseva.com','Meeting booked for proposal review'),
  ('Narayana Health','On-site Workshop','workshop','2026-05-28 10:00:00+05:30'::timestamptz,'Dr. Vinod Kaul','Director Operations',false,'## Prep\n- Engineer team intro pack','## Follow-up\n- No-show; reschedule needed','low',5000,'founder@equipseva.com','Stakeholder cancelled day-of'),
  ('Max Healthcare','Site Visit — Delhi flagship','site_visit','2026-06-02 11:30:00+05:30'::timestamptz,'Sunita Sharma','Head of Engineering',true,'## Prep\n- Walked through 12 biomed assets\n- Tier-3 spec sheet','## Follow-up\n- AMC tier-3 quote requested','medium',18000,'founder@equipseva.com','Mid-funnel; warm');

INSERT INTO public.event_followup_outcomes_r2511
  (event_id, outcome_at, outcome_kind, revenue_influenced_rupees, next_step, owner_email, status, notes)
SELECT id, '2026-05-15 10:00:00+05:30'::timestamptz, 'meeting_booked', 480000, 'Send AMC proposal for 4 sites', 'founder@equipseva.com', 'in_progress', 'Apollo follow-up'
FROM public.chain_stakeholder_events_r2511 WHERE chain_name='Apollo Group' LIMIT 1;

INSERT INTO public.event_followup_outcomes_r2511
  (event_id, outcome_at, outcome_kind, revenue_influenced_rupees, next_step, owner_email, status, notes)
SELECT id, '2026-05-21 10:00:00+05:30'::timestamptz, 'deal_advanced', 1850000, 'Cluster pilot at 3 sites', 'founder@equipseva.com', 'in_progress', 'Manipal cluster moving'
FROM public.chain_stakeholder_events_r2511 WHERE chain_name='Manipal Hospitals' LIMIT 1;

INSERT INTO public.event_followup_outcomes_r2511
  (event_id, outcome_at, outcome_kind, revenue_influenced_rupees, next_step, owner_email, status, notes)
SELECT id, '2026-05-26 10:00:00+05:30'::timestamptz, 'proposal_sent', 720000, 'Awaiting Fortis CFO sign-off', 'founder@equipseva.com', 'open', 'Fortis proposal out'
FROM public.chain_stakeholder_events_r2511 WHERE chain_name='Fortis Healthcare' LIMIT 1;

INSERT INTO public.event_followup_outcomes_r2511
  (event_id, outcome_at, outcome_kind, revenue_influenced_rupees, next_step, owner_email, status, notes)
SELECT id, '2026-06-01 10:00:00+05:30'::timestamptz, 'no_follow_up', 0, 'Re-engage in Q3', 'founder@equipseva.com', 'dropped', 'Narayana stalled'
FROM public.chain_stakeholder_events_r2511 WHERE chain_name='Narayana Health' LIMIT 1;

INSERT INTO public.event_followup_outcomes_r2511
  (event_id, outcome_at, outcome_kind, revenue_influenced_rupees, next_step, owner_email, status, notes)
SELECT id, '2026-06-05 10:00:00+05:30'::timestamptz, 'meeting_booked', 360000, 'Tier-3 quote walkthrough', 'founder@equipseva.com', 'in_progress', 'Max Healthcare warm'
FROM public.chain_stakeholder_events_r2511 WHERE chain_name='Max Healthcare' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_events_r2511()
RETURNS TABLE (
  id uuid,
  chain_name text,
  event_name text,
  event_kind text,
  held_at timestamptz,
  stakeholder_name text,
  stakeholder_role text,
  attended boolean,
  deal_influence text,
  cost_rupees bigint,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_name, e.event_name, e.event_kind, e.held_at,
         e.stakeholder_name, e.stakeholder_role, e.attended,
         e.deal_influence, e.cost_rupees, e.owner_email
  FROM public.chain_stakeholder_events_r2511 e
  ORDER BY e.held_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_events_r2511() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_events_r2511() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_followup_outcomes_r2511()
RETURNS TABLE (
  id uuid,
  event_id uuid,
  chain_name text,
  event_name text,
  outcome_at timestamptz,
  outcome_kind text,
  revenue_influenced_rupees bigint,
  next_step text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.event_id, e.chain_name, e.event_name,
         o.outcome_at, o.outcome_kind, o.revenue_influenced_rupees,
         o.next_step, o.owner_email, o.status
  FROM public.event_followup_outcomes_r2511 o
  JOIN public.chain_stakeholder_events_r2511 e ON e.id = o.event_id
  ORDER BY o.outcome_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_followup_outcomes_r2511() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_outcomes_r2511() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_influence_events_r2511()
RETURNS TABLE (
  chain_name text,
  event_name text,
  deal_influence text,
  cost_rupees bigint,
  total_revenue_influenced_rupees bigint,
  roi_multiple numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.chain_name, e.event_name, e.deal_influence, e.cost_rupees,
         COALESCE(SUM(o.revenue_influenced_rupees),0)::bigint AS total_revenue_influenced_rupees,
         CASE WHEN e.cost_rupees > 0
              THEN ROUND(COALESCE(SUM(o.revenue_influenced_rupees),0)::numeric / e.cost_rupees::numeric, 2)
              ELSE NULL END AS roi_multiple
  FROM public.chain_stakeholder_events_r2511 e
  LEFT JOIN public.event_followup_outcomes_r2511 o ON o.event_id = e.id
  GROUP BY e.id, e.chain_name, e.event_name, e.deal_influence, e.cost_rupees
  ORDER BY total_revenue_influenced_rupees DESC
  LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_influence_events_r2511() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_influence_events_r2511() TO authenticated;

CREATE OR REPLACE FUNCTION public.kind_breakdown_r2511()
RETURNS TABLE (
  event_kind text,
  event_count bigint,
  attended_count bigint,
  total_cost_rupees bigint,
  total_revenue_influenced_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_kind,
         COUNT(*)::bigint AS event_count,
         COUNT(*) FILTER (WHERE e.attended)::bigint AS attended_count,
         COALESCE(SUM(e.cost_rupees),0)::bigint AS total_cost_rupees,
         COALESCE((SELECT SUM(o.revenue_influenced_rupees)
                   FROM public.event_followup_outcomes_r2511 o
                   JOIN public.chain_stakeholder_events_r2511 e2 ON e2.id = o.event_id
                   WHERE e2.event_kind = e.event_kind),0)::bigint AS total_revenue_influenced_rupees
  FROM public.chain_stakeholder_events_r2511 e
  GROUP BY e.event_kind
  ORDER BY total_revenue_influenced_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2511() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2511() TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_summary_r2511()
RETURNS TABLE (
  total_events bigint,
  attended_events bigint,
  no_shows bigint,
  attendance_rate_pct numeric,
  high_or_critical_influence bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::bigint AS total_events,
         COUNT(*) FILTER (WHERE attended)::bigint AS attended_events,
         COUNT(*) FILTER (WHERE NOT attended)::bigint AS no_shows,
         CASE WHEN COUNT(*) > 0
              THEN ROUND(100.0 * COUNT(*) FILTER (WHERE attended)::numeric / COUNT(*)::numeric, 1)
              ELSE 0 END AS attendance_rate_pct,
         COUNT(*) FILTER (WHERE deal_influence IN ('high','critical'))::bigint AS high_or_critical_influence
  FROM public.chain_stakeholder_events_r2511;
END $$;
REVOKE EXECUTE ON FUNCTION public.attendance_summary_r2511() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.attendance_summary_r2511() TO authenticated;

CREATE OR REPLACE FUNCTION public.cost_vs_outcome_r2511()
RETURNS TABLE (
  chain_name text,
  total_cost_rupees bigint,
  total_revenue_influenced_rupees bigint,
  net_rupees bigint,
  outcomes_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.chain_name,
         COALESCE(SUM(e.cost_rupees),0)::bigint AS total_cost_rupees,
         COALESCE((SELECT SUM(o.revenue_influenced_rupees)
                   FROM public.event_followup_outcomes_r2511 o
                   JOIN public.chain_stakeholder_events_r2511 e2 ON e2.id = o.event_id
                   WHERE e2.chain_name = e.chain_name),0)::bigint AS total_revenue_influenced_rupees,
         (COALESCE((SELECT SUM(o.revenue_influenced_rupees)
                    FROM public.event_followup_outcomes_r2511 o
                    JOIN public.chain_stakeholder_events_r2511 e2 ON e2.id = o.event_id
                    WHERE e2.chain_name = e.chain_name),0) - COALESCE(SUM(e.cost_rupees),0))::bigint AS net_rupees,
         (SELECT COUNT(*) FROM public.event_followup_outcomes_r2511 o
          JOIN public.chain_stakeholder_events_r2511 e2 ON e2.id = o.event_id
          WHERE e2.chain_name = e.chain_name)::bigint AS outcomes_count
  FROM public.chain_stakeholder_events_r2511 e
  GROUP BY e.chain_name
  ORDER BY net_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.cost_vs_outcome_r2511() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cost_vs_outcome_r2511() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_event_trend_r2511()
RETURNS TABLE (
  month_start timestamptz,
  events_count bigint,
  attended_count bigint,
  total_cost_rupees bigint,
  total_revenue_influenced_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', e.held_at) AS month_start,
         COUNT(*)::bigint AS events_count,
         COUNT(*) FILTER (WHERE e.attended)::bigint AS attended_count,
         COALESCE(SUM(e.cost_rupees),0)::bigint AS total_cost_rupees,
         COALESCE((SELECT SUM(o.revenue_influenced_rupees)
                   FROM public.event_followup_outcomes_r2511 o
                   JOIN public.chain_stakeholder_events_r2511 e2 ON e2.id = o.event_id
                   WHERE date_trunc('month', e2.held_at) = date_trunc('month', e.held_at)),0)::bigint AS total_revenue_influenced_rupees
  FROM public.chain_stakeholder_events_r2511 e
  GROUP BY date_trunc('month', e.held_at)
  ORDER BY month_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_event_trend_r2511() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_event_trend_r2511() TO authenticated;
