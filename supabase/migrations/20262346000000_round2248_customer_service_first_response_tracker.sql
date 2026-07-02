BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_service_tickets_r2248 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_code text NOT NULL UNIQUE,
  customer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  channel text NOT NULL CHECK (channel IN ('chat','email','phone','whatsapp','in_app')),
  subject text NOT NULL,
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  first_response_at timestamptz,
  first_response_minutes int,
  resolved_at timestamptz,
  sla_target_minutes int NOT NULL DEFAULT 15,
  sla_breached boolean NOT NULL DEFAULT false,
  agent_email text,
  hour_of_day int CHECK (hour_of_day BETWEEN 0 AND 23),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_service_breach_log_r2248 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.customer_service_tickets_r2248(id) ON DELETE CASCADE,
  breach_severity text NOT NULL CHECK (breach_severity IN ('minor','major','critical')),
  minutes_over_target int NOT NULL,
  breach_reason text NOT NULL CHECK (breach_reason IN ('agent_unavailable','wrong_routing','peak_volume','tech_issue','other')),
  remediation text,
  noted_by text NOT NULL,
  noted_at timestamptz NOT NULL DEFAULT now(),
  resolved_followup boolean NOT NULL DEFAULT false
);

ALTER TABLE public.customer_service_tickets_r2248 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_service_breach_log_r2248 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_tickets_r2248 ON public.customer_service_tickets_r2248;
CREATE POLICY founder_all_tickets_r2248 ON public.customer_service_tickets_r2248
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_breach_r2248 ON public.customer_service_breach_log_r2248;
CREATE POLICY founder_all_breach_r2248 ON public.customer_service_breach_log_r2248
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

INSERT INTO public.customer_service_tickets_r2248 (ticket_code, channel, subject, priority, opened_at, first_response_at, first_response_minutes, resolved_at, sla_target_minutes, sla_breached, agent_email, hour_of_day, notes) VALUES
  ('CS-2248-0001','chat','AMC renewal question','normal', now() - interval '12 hours', now() - interval '12 hours' + interval '4 minutes', 4, now() - interval '11 hours', 15, false, 'agent1@equipseva.com', 10, 'resolved same shift'),
  ('CS-2248-0002','email','Invoice mismatch','high', now() - interval '2 days', now() - interval '2 days' + interval '42 minutes', 42, now() - interval '1 day', 30, true, 'agent2@equipseva.com', 14, 'breach by 12 min'),
  ('CS-2248-0003','phone','Engineer no-show','urgent', now() - interval '6 hours', now() - interval '6 hours' + interval '2 minutes', 2, now() - interval '5 hours', 5, false, 'agent3@equipseva.com', 18, 'urgent handled fast'),
  ('CS-2248-0004','whatsapp','Order tracking','normal', now() - interval '1 day', now() - interval '1 day' + interval '8 minutes', 8, now() - interval '23 hours', 15, false, 'agent1@equipseva.com', 11, 'fine'),
  ('CS-2248-0005','chat','Refund delay','high', now() - interval '3 days', now() - interval '3 days' + interval '55 minutes', 55, NULL, 30, true, 'agent2@equipseva.com', 19, 'still open'),
  ('CS-2248-0006','email','New onboarding','low', now() - interval '5 days', now() - interval '5 days' + interval '18 minutes', 18, now() - interval '4 days', 60, false, 'agent3@equipseva.com', 9, 'easy');

INSERT INTO public.customer_service_breach_log_r2248 (ticket_id, breach_severity, minutes_over_target, breach_reason, remediation, noted_by, resolved_followup) VALUES
  ((SELECT id FROM public.customer_service_tickets_r2248 WHERE ticket_code='CS-2248-0002'),'minor',12,'agent_unavailable','reassigned shift coverage','founder@equipseva.com',true),
  ((SELECT id FROM public.customer_service_tickets_r2248 WHERE ticket_code='CS-2248-0005'),'major',25,'peak_volume','add evening on-call rotation','founder@equipseva.com',false);

CREATE OR REPLACE FUNCTION public.founder_cs_frt_overview_r2248()
RETURNS TABLE(total_tickets int, avg_first_response_min numeric, sla_breach_count int, breach_rate_pct numeric, open_unresolved int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    ROUND(AVG(first_response_minutes)::numeric, 1),
    (COUNT(*) FILTER (WHERE sla_breached))::int,
    ROUND((COUNT(*) FILTER (WHERE sla_breached))::numeric * 100.0 / NULLIF(COUNT(*),0), 1),
    (COUNT(*) FILTER (WHERE resolved_at IS NULL))::int
  FROM public.customer_service_tickets_r2248;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_cs_frt_by_channel_r2248()
RETURNS TABLE(channel text, ticket_count int, avg_frt_min numeric, breach_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.channel,
         (COUNT(*))::int,
         ROUND(AVG(t.first_response_minutes)::numeric, 1),
         (COUNT(*) FILTER (WHERE t.sla_breached))::int
  FROM public.customer_service_tickets_r2248 t
  GROUP BY t.channel
  ORDER BY COUNT(*) DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_cs_frt_by_hour_r2248()
RETURNS TABLE(hour_of_day int, ticket_count int, avg_frt_min numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.hour_of_day,
         (COUNT(*))::int,
         ROUND(AVG(t.first_response_minutes)::numeric, 1)
  FROM public.customer_service_tickets_r2248 t
  WHERE t.hour_of_day IS NOT NULL
  GROUP BY t.hour_of_day
  ORDER BY t.hour_of_day;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_cs_frt_by_priority_r2248()
RETURNS TABLE(priority text, ticket_count int, avg_frt_min numeric, breach_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.priority,
         (COUNT(*))::int,
         ROUND(AVG(t.first_response_minutes)::numeric, 1),
         (COUNT(*) FILTER (WHERE t.sla_breached))::int
  FROM public.customer_service_tickets_r2248 t
  GROUP BY t.priority
  ORDER BY (CASE t.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 WHEN 'low' THEN 4 END);
END; $$;

CREATE OR REPLACE FUNCTION public.founder_cs_recent_tickets_r2248()
RETURNS TABLE(ticket_code text, channel text, subject text, priority text, opened_at timestamptz, first_response_minutes int, sla_breached boolean, agent_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.ticket_code, t.channel, t.subject, t.priority, t.opened_at, t.first_response_minutes, t.sla_breached, t.agent_email
  FROM public.customer_service_tickets_r2248 t
  ORDER BY t.opened_at DESC
  LIMIT 50;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_cs_breach_log_r2248()
RETURNS TABLE(ticket_code text, channel text, breach_severity text, minutes_over_target int, breach_reason text, remediation text, noted_at timestamptz, resolved_followup boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.ticket_code, t.channel, b.breach_severity, b.minutes_over_target, b.breach_reason, b.remediation, b.noted_at, b.resolved_followup
  FROM public.customer_service_breach_log_r2248 b
  JOIN public.customer_service_tickets_r2248 t ON t.id = b.ticket_id
  ORDER BY b.noted_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_cs_agent_leaderboard_r2248()
RETURNS TABLE(agent_email text, ticket_count int, avg_frt_min numeric, breach_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.agent_email,
         (COUNT(*))::int,
         ROUND(AVG(t.first_response_minutes)::numeric, 1),
         (COUNT(*) FILTER (WHERE t.sla_breached))::int
  FROM public.customer_service_tickets_r2248 t
  WHERE t.agent_email IS NOT NULL
  GROUP BY t.agent_email
  ORDER BY AVG(t.first_response_minutes) ASC NULLS LAST;
END; $$;

REVOKE ALL ON FUNCTION public.founder_cs_frt_overview_r2248() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_cs_frt_by_channel_r2248() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_cs_frt_by_hour_r2248() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_cs_frt_by_priority_r2248() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_cs_recent_tickets_r2248() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_cs_breach_log_r2248() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_cs_agent_leaderboard_r2248() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_cs_frt_overview_r2248() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_cs_frt_by_channel_r2248() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_cs_frt_by_hour_r2248() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_cs_frt_by_priority_r2248() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_cs_recent_tickets_r2248() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_cs_breach_log_r2248() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_cs_agent_leaderboard_r2248() TO authenticated;

COMMIT;
