-- Round 2591: Hospital chain emergency engineer deployment
-- chain × emergency × response time × engineer × CSAT × ARR saved × repeat-risk

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_emergency_deployments_r2591 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  emergency_at timestamptz NOT NULL,
  emergency_kind text NOT NULL CHECK (emergency_kind IN ('downtime','data_loss','safety','regulatory','escalation')),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  response_minutes int NOT NULL DEFAULT 0,
  csat_score int NOT NULL DEFAULT 0 CHECK (csat_score BETWEEN 0 AND 10),
  arr_saved_rupees bigint NOT NULL DEFAULT 0,
  repeat_risk_kind text NOT NULL CHECK (repeat_risk_kind IN ('low','medium','high','critical')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.emergency_followup_actions_r2591 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  deployment_id uuid NOT NULL REFERENCES public.chain_emergency_deployments_r2591(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('call','visit','refund','training','policy_update')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.chain_emergency_deployments_r2591 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_followup_actions_r2591 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_emergency_deployments_r2591;
CREATE POLICY founder_all ON public.chain_emergency_deployments_r2591
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.emergency_followup_actions_r2591;
CREATE POLICY founder_all ON public.emergency_followup_actions_r2591
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed deployments
INSERT INTO public.chain_emergency_deployments_r2591
  (chain_name, emergency_at, emergency_kind, response_minutes, csat_score, arr_saved_rupees, repeat_risk_kind, owner_email, status, notes)
VALUES
  ('Apollo North', '2026-06-18 09:15:00+05:30'::timestamptz, 'downtime', 22, 9, 4200000, 'medium', 'ops@equipseva.in', 'resolved', 'CT scanner offline; spare swapped'),
  ('Fortis West', '2026-06-19 14:00:00+05:30'::timestamptz, 'data_loss', 45, 7, 1800000, 'high', 'ops@equipseva.in', 'in_progress', 'PACS backup restore in progress'),
  ('Manipal South', '2026-06-20 21:30:00+05:30'::timestamptz, 'safety', 18, 10, 6500000, 'low', 'ops@equipseva.in', 'resolved', 'Ventilator alarm calibration'),
  ('Yashoda Central', '2026-06-21 06:45:00+05:30'::timestamptz, 'regulatory', 60, 6, 950000, 'critical', 'ops@equipseva.in', 'open', 'NABH audit prep + missing log'),
  ('Care East', '2026-06-22 11:20:00+05:30'::timestamptz, 'escalation', 30, 8, 2750000, 'medium', 'ops@equipseva.in', 'in_progress', 'CEO complaint about repeat issue');

-- Seed follow-ups
INSERT INTO public.emergency_followup_actions_r2591
  (deployment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, emergency_at + interval '2 hours', 'call', 'positive', 'csm@equipseva.in', 'done', 'Post-incident debrief call'
FROM public.chain_emergency_deployments_r2591 WHERE chain_name = 'Apollo North';

INSERT INTO public.emergency_followup_actions_r2591
  (deployment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, emergency_at + interval '1 day', 'visit', 'neutral', 'csm@equipseva.in', 'open', 'On-site review with biomed team'
FROM public.chain_emergency_deployments_r2591 WHERE chain_name = 'Fortis West';

INSERT INTO public.emergency_followup_actions_r2591
  (deployment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, emergency_at + interval '3 days', 'training', 'positive', 'training@equipseva.in', 'done', 'Refresher training delivered'
FROM public.chain_emergency_deployments_r2591 WHERE chain_name = 'Manipal South';

INSERT INTO public.emergency_followup_actions_r2591
  (deployment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, emergency_at + interval '6 hours', 'policy_update', 'pending', 'compliance@equipseva.in', 'open', 'Update SOP for log retention'
FROM public.chain_emergency_deployments_r2591 WHERE chain_name = 'Yashoda Central';

INSERT INTO public.emergency_followup_actions_r2591
  (deployment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, emergency_at + interval '12 hours', 'refund', 'negative', 'finance@equipseva.in', 'done', 'Partial credit issued to chain'
FROM public.chain_emergency_deployments_r2591 WHERE chain_name = 'Care East';

-- RPC 1: list deployments
CREATE OR REPLACE FUNCTION public.list_deployments_r2591()
RETURNS TABLE (
  id uuid,
  chain_name text,
  emergency_at timestamptz,
  emergency_kind text,
  response_minutes int,
  csat_score int,
  arr_saved_rupees bigint,
  repeat_risk_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.emergency_at, d.emergency_kind, d.response_minutes,
         d.csat_score, d.arr_saved_rupees, d.repeat_risk_kind, d.owner_email, d.status, d.notes
  FROM public.chain_emergency_deployments_r2591 d
  ORDER BY d.emergency_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_deployments_r2591() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_deployments_r2591() TO authenticated;

-- RPC 2: list followup actions
CREATE OR REPLACE FUNCTION public.list_followup_actions_r2591()
RETURNS TABLE (
  id uuid,
  deployment_id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.deployment_id, d.chain_name, a.action_at, a.action_kind,
         a.outcome, a.owner_email, a.status, a.notes
  FROM public.emergency_followup_actions_r2591 a
  LEFT JOIN public.chain_emergency_deployments_r2591 d ON d.id = a.deployment_id
  ORDER BY a.action_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followup_actions_r2591() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_actions_r2591() TO authenticated;

-- RPC 3: top ARR saved focus
CREATE OR REPLACE FUNCTION public.top_arr_saved_focus_r2591()
RETURNS TABLE (
  chain_name text,
  total_arr_saved_rupees bigint,
  emergencies int,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.chain_name,
         COALESCE(SUM(d.arr_saved_rupees), 0)::bigint AS total_arr_saved_rupees,
         COUNT(*)::int AS emergencies,
         ROUND(AVG(d.csat_score)::numeric, 2) AS avg_csat
  FROM public.chain_emergency_deployments_r2591 d
  GROUP BY d.chain_name
  ORDER BY total_arr_saved_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_arr_saved_focus_r2591() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_saved_focus_r2591() TO authenticated;

-- RPC 4: emergency kind breakdown
CREATE OR REPLACE FUNCTION public.emergency_kind_breakdown_r2591()
RETURNS TABLE (
  emergency_kind text,
  emergencies int,
  avg_response_minutes numeric,
  total_arr_saved_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.emergency_kind,
         COUNT(*)::int AS emergencies,
         ROUND(AVG(d.response_minutes)::numeric, 1) AS avg_response_minutes,
         COALESCE(SUM(d.arr_saved_rupees), 0)::bigint AS total_arr_saved_rupees
  FROM public.chain_emergency_deployments_r2591 d
  GROUP BY d.emergency_kind
  ORDER BY emergencies DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.emergency_kind_breakdown_r2591() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.emergency_kind_breakdown_r2591() TO authenticated;

-- RPC 5: response time summary
CREATE OR REPLACE FUNCTION public.response_time_summary_r2591()
RETURNS TABLE (
  bucket text,
  emergencies int,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT CASE
           WHEN d.response_minutes <= 15 THEN 'under_15'
           WHEN d.response_minutes <= 30 THEN '15_to_30'
           WHEN d.response_minutes <= 60 THEN '30_to_60'
           ELSE 'over_60'
         END AS bucket,
         COUNT(*)::int AS emergencies,
         ROUND(AVG(d.csat_score)::numeric, 2) AS avg_csat
  FROM public.chain_emergency_deployments_r2591 d
  GROUP BY bucket
  ORDER BY bucket ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.response_time_summary_r2591() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.response_time_summary_r2591() TO authenticated;

-- RPC 6: monthly emergency trend
CREATE OR REPLACE FUNCTION public.monthly_emergency_trend_r2591()
RETURNS TABLE (
  month_label text,
  emergencies int,
  avg_response_minutes numeric,
  total_arr_saved_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', d.emergency_at), 'YYYY-MM') AS month_label,
         COUNT(*)::int AS emergencies,
         ROUND(AVG(d.response_minutes)::numeric, 1) AS avg_response_minutes,
         COALESCE(SUM(d.arr_saved_rupees), 0)::bigint AS total_arr_saved_rupees
  FROM public.chain_emergency_deployments_r2591 d
  GROUP BY date_trunc('month', d.emergency_at)
  ORDER BY date_trunc('month', d.emergency_at) ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_emergency_trend_r2591() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_emergency_trend_r2591() TO authenticated;

-- RPC 7: repeat risk distribution
CREATE OR REPLACE FUNCTION public.repeat_risk_distribution_r2591()
RETURNS TABLE (
  repeat_risk_kind text,
  emergencies int,
  total_arr_saved_rupees bigint,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.repeat_risk_kind,
         COUNT(*)::int AS emergencies,
         COALESCE(SUM(d.arr_saved_rupees), 0)::bigint AS total_arr_saved_rupees,
         ROUND(AVG(d.csat_score)::numeric, 2) AS avg_csat
  FROM public.chain_emergency_deployments_r2591 d
  GROUP BY d.repeat_risk_kind
  ORDER BY emergencies DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.repeat_risk_distribution_r2591() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repeat_risk_distribution_r2591() TO authenticated;

