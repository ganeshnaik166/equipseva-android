-- Round 2648: customer monthly engagement pulse net
-- Founder-only tables + RPCs to track monthly engagement pulse
-- and action outcomes per hospital customer.

CREATE TABLE IF NOT EXISTS public.customer_engagement_pulse_r2648 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  month_label text NOT NULL,
  touches_made int NOT NULL DEFAULT 0,
  touches_responded int NOT NULL DEFAULT 0,
  engagement_score int NOT NULL DEFAULT 0 CHECK (engagement_score BETWEEN 0 AND 100),
  sentiment_kind text NOT NULL CHECK (sentiment_kind IN ('positive','neutral','negative')),
  retention_risk_kind text NOT NULL CHECK (retention_risk_kind IN ('low','medium','high','critical')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','at_risk','champion','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engagement_action_outcomes_r2648 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_id uuid REFERENCES public.customer_engagement_pulse_r2648(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('call','visit','event','gift','founder_intro')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_engagement_pulse_r2648 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engagement_action_outcomes_r2648 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_engagement_pulse_r2648;
CREATE POLICY founder_all ON public.customer_engagement_pulse_r2648
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engagement_action_outcomes_r2648;
CREATE POLICY founder_all ON public.engagement_action_outcomes_r2648
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed rows (no apostrophes)
INSERT INTO public.customer_engagement_pulse_r2648
  (month_label, touches_made, touches_responded, engagement_score, sentiment_kind, retention_risk_kind, owner_email, status, notes)
VALUES
  ('2026-06', 12, 10, 86, 'positive', 'low', 'success@equipseva.com', 'champion', 'Strong response to monthly outreach'),
  ('2026-06', 8, 3, 42, 'neutral', 'high', 'success@equipseva.com', 'at_risk', 'Drop in repair bookings two months running'),
  ('2026-06', 6, 1, 18, 'negative', 'critical', 'founder@equipseva.com', 'at_risk', 'Escalation flagged by ops review'),
  ('2026-05', 10, 9, 91, 'positive', 'low', 'success@equipseva.com', 'champion', 'Referenced equipseva in chain board meeting'),
  ('2026-05', 4, 0, 8, 'negative', 'critical', 'success@equipseva.com', 'lost', 'Switched vendor mid month');

INSERT INTO public.engagement_action_outcomes_r2648
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-10T00:00:00Z'::timestamptz, 'call', 'positive', 'success@equipseva.com', 'done', 'Quarterly review call went well'
  FROM public.customer_engagement_pulse_r2648 WHERE month_label = '2026-06' AND status = 'champion' LIMIT 1;

INSERT INTO public.engagement_action_outcomes_r2648
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-12T00:00:00Z'::timestamptz, 'visit', 'neutral', 'success@equipseva.com', 'open', 'Onsite visit scheduled to review needs'
  FROM public.customer_engagement_pulse_r2648 WHERE month_label = '2026-06' AND status = 'at_risk' LIMIT 1;

INSERT INTO public.engagement_action_outcomes_r2648
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-18T00:00:00Z'::timestamptz, 'founder_intro', 'pending', 'founder@equipseva.com', 'open', 'Founder reachout pending confirmation'
  FROM public.customer_engagement_pulse_r2648 WHERE retention_risk_kind = 'critical' AND month_label = '2026-06' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_engagement_r2648()
RETURNS TABLE (
  id uuid,
  month_label text,
  touches_made int,
  touches_responded int,
  engagement_score int,
  sentiment_kind text,
  retention_risk_kind text,
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
  SELECT p.id, p.month_label, p.touches_made, p.touches_responded, p.engagement_score,
         p.sentiment_kind, p.retention_risk_kind, p.owner_email, p.status, p.notes, p.created_at
  FROM public.customer_engagement_pulse_r2648 p
  ORDER BY p.month_label DESC, p.engagement_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_engagement_r2648() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engagement_r2648() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_action_outcomes_r2648()
RETURNS TABLE (
  id uuid,
  pulse_id uuid,
  action_at timestamptz,
  action_kind text,
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
  SELECT a.id, a.pulse_id, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes, a.created_at
  FROM public.engagement_action_outcomes_r2648 a
  ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_action_outcomes_r2648() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_outcomes_r2648() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_at_risk_focus_r2648()
RETURNS TABLE (
  id uuid,
  month_label text,
  engagement_score int,
  sentiment_kind text,
  retention_risk_kind text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.month_label, p.engagement_score, p.sentiment_kind,
         p.retention_risk_kind, p.owner_email, p.status
  FROM public.customer_engagement_pulse_r2648 p
  WHERE p.retention_risk_kind IN ('high','critical') OR p.status = 'at_risk'
  ORDER BY
    CASE p.retention_risk_kind
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      ELSE 4
    END,
    p.engagement_score ASC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_focus_r2648() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_at_risk_focus_r2648() TO authenticated;

CREATE OR REPLACE FUNCTION public.sentiment_distribution_r2648()
RETURNS TABLE (sentiment_kind text, pulse_count bigint, avg_engagement_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.sentiment_kind, COUNT(*)::bigint AS pulse_count,
         COALESCE(AVG(p.engagement_score),0)::numeric AS avg_engagement_score
  FROM public.customer_engagement_pulse_r2648 p
  GROUP BY p.sentiment_kind
  ORDER BY p.sentiment_kind;
END $$;
REVOKE EXECUTE ON FUNCTION public.sentiment_distribution_r2648() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sentiment_distribution_r2648() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2648()
RETURNS TABLE (status text, pulse_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.status, COUNT(*)::bigint
  FROM public.customer_engagement_pulse_r2648 p
  GROUP BY p.status
  ORDER BY p.status;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2648() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2648() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_engagement_trend_r2648()
RETURNS TABLE (month_bucket text, pulse_count bigint, avg_engagement_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.month_label AS month_bucket, COUNT(*)::bigint AS pulse_count,
         COALESCE(AVG(p.engagement_score),0)::numeric AS avg_engagement_score
  FROM public.customer_engagement_pulse_r2648 p
  GROUP BY p.month_label
  ORDER BY p.month_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_engagement_trend_r2648() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_engagement_trend_r2648() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2648()
RETURNS TABLE (owner_email text, pulse_count bigint, at_risk_count bigint, champion_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(p.owner_email,'unassigned') AS owner_email,
         COUNT(*)::bigint AS pulse_count,
         COUNT(*) FILTER (WHERE p.status = 'at_risk')::bigint AS at_risk_count,
         COUNT(*) FILTER (WHERE p.status = 'champion')::bigint AS champion_count
  FROM public.customer_engagement_pulse_r2648 p
  GROUP BY COALESCE(p.owner_email,'unassigned')
  ORDER BY pulse_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2648() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2648() TO authenticated;
