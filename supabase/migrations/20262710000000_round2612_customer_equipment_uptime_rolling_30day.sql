-- Round 2612: Customer Equipment Uptime Rolling 30-day
-- Tracks rolling 30-day uptime per hospital equipment + breach actions; RPCs surface critical focus, severity mix, monthly trend.

CREATE TABLE IF NOT EXISTS public.customer_uptime_30d_r2612 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL,
  window_end_date date NOT NULL,
  uptime_pct numeric NOT NULL DEFAULT 0,
  downtime_minutes int NOT NULL DEFAULT 0,
  slo_breach_count int NOT NULL DEFAULT 0,
  severity_kind text NOT NULL DEFAULT 'green' CHECK (severity_kind IN ('green','amber','red','critical')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','escalated','resolved')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.uptime_breach_actions_r2612 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  uptime_id uuid NOT NULL REFERENCES public.customer_uptime_30d_r2612(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('spare_dispatch','credit_apply','exec_call','training','replacement_quote')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.customer_uptime_30d_r2612 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uptime_breach_actions_r2612 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_uptime_30d_r2612;
CREATE POLICY founder_all ON public.customer_uptime_30d_r2612
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.uptime_breach_actions_r2612;
CREATE POLICY founder_all ON public.uptime_breach_actions_r2612
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.customer_uptime_30d_r2612
  (equipment_label, equipment_kind, window_end_date, uptime_pct, downtime_minutes, slo_breach_count, severity_kind, owner_email, status, notes)
VALUES
  ('Apollo MRI Bay 3', 'mri', '2026-06-20'::date, 99.42, 246, 0, 'green', 'cs@equipseva.com', 'monitoring', 'Within SLO, no action needed'),
  ('KIMS CT Scanner 2', 'ct', '2026-06-20'::date, 97.10, 1252, 2, 'amber', 'cs@equipseva.com', 'monitoring', 'Two short outages flagged for tube cooling'),
  ('Yashoda Cathlab 1', 'cathlab', '2026-06-20'::date, 94.30, 2462, 4, 'red', 'svp.service@equipseva.com', 'escalated', 'Recurring power supply faults, replacement quoted'),
  ('Continental Ventilator Pool', 'ventilator', '2026-06-20'::date, 88.10, 5141, 7, 'critical', 'founder@equipseva.com', 'escalated', 'Multiple units down, spare-parts dispatched'),
  ('Rainbow Neonatal Incubator A', 'incubator', '2026-06-20'::date, 99.80, 86, 0, 'green', 'cs@equipseva.com', 'resolved', 'Healed after firmware update');

INSERT INTO public.uptime_breach_actions_r2612
  (uptime_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-18T09:00:00Z'::timestamptz, 'spare_dispatch', 'positive', 'logistics@equipseva.com', 'done', 'Tube cooler dispatched same day'
FROM public.customer_uptime_30d_r2612 WHERE equipment_label = 'KIMS CT Scanner 2' LIMIT 1;

INSERT INTO public.uptime_breach_actions_r2612
  (uptime_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-19T14:30:00Z'::timestamptz, 'replacement_quote', 'pending', 'sales@equipseva.com', 'open', 'PSU module replacement quote sent'
FROM public.customer_uptime_30d_r2612 WHERE equipment_label = 'Yashoda Cathlab 1' LIMIT 1;

INSERT INTO public.uptime_breach_actions_r2612
  (uptime_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-20T10:00:00Z'::timestamptz, 'exec_call', 'neutral', 'founder@equipseva.com', 'open', 'Executive call scheduled with biomed head'
FROM public.customer_uptime_30d_r2612 WHERE equipment_label = 'Continental Ventilator Pool' LIMIT 1;

INSERT INTO public.uptime_breach_actions_r2612
  (uptime_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-15T11:00:00Z'::timestamptz, 'credit_apply', 'positive', 'finance@equipseva.com', 'done', 'AMC credit applied for downtime hours'
FROM public.customer_uptime_30d_r2612 WHERE equipment_label = 'Continental Ventilator Pool' LIMIT 1;

INSERT INTO public.uptime_breach_actions_r2612
  (uptime_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-10T15:00:00Z'::timestamptz, 'training', 'positive', 'training@equipseva.com', 'done', 'Bedside training session for ICU staff'
FROM public.customer_uptime_30d_r2612 WHERE equipment_label = 'Rainbow Neonatal Incubator A' LIMIT 1;

-- RPC 1: list uptime rows
CREATE OR REPLACE FUNCTION public.list_uptime_r2612()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_kind text,
  window_end_date date,
  uptime_pct numeric,
  downtime_minutes int,
  slo_breach_count int,
  severity_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.id, u.equipment_label, u.equipment_kind, u.window_end_date, u.uptime_pct,
           u.downtime_minutes, u.slo_breach_count, u.severity_kind, u.owner_email, u.status, u.notes
    FROM public.customer_uptime_30d_r2612 u
    ORDER BY
      CASE u.severity_kind
        WHEN 'critical' THEN 1
        WHEN 'red' THEN 2
        WHEN 'amber' THEN 3
        WHEN 'green' THEN 4
        ELSE 5
      END ASC,
      u.uptime_pct ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_uptime_r2612() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_uptime_r2612() TO authenticated;

-- RPC 2: list breach actions
CREATE OR REPLACE FUNCTION public.list_breach_actions_r2612()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, u.equipment_label, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
    FROM public.uptime_breach_actions_r2612 a
    JOIN public.customer_uptime_30d_r2612 u ON u.id = a.uptime_id
    ORDER BY a.action_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_breach_actions_r2612() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_breach_actions_r2612() TO authenticated;

-- RPC 3: top critical focus
CREATE OR REPLACE FUNCTION public.top_critical_focus_r2612()
RETURNS TABLE (
  equipment_label text,
  equipment_kind text,
  uptime_pct numeric,
  downtime_minutes int,
  severity_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.equipment_label, u.equipment_kind, u.uptime_pct, u.downtime_minutes,
           u.severity_kind, u.owner_email, u.status, u.notes
    FROM public.customer_uptime_30d_r2612 u
    WHERE u.severity_kind IN ('red','critical')
    ORDER BY u.uptime_pct ASC, u.downtime_minutes DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_critical_focus_r2612() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_critical_focus_r2612() TO authenticated;

-- RPC 4: severity distribution
CREATE OR REPLACE FUNCTION public.severity_distribution_r2612()
RETURNS TABLE (
  severity_kind text,
  total_assets int,
  avg_uptime_pct numeric,
  total_downtime_minutes int,
  total_breaches int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.severity_kind,
           COUNT(*)::int AS total_assets,
           ROUND(AVG(u.uptime_pct)::numeric, 2) AS avg_uptime_pct,
           SUM(u.downtime_minutes)::int AS total_downtime_minutes,
           SUM(u.slo_breach_count)::int AS total_breaches
    FROM public.customer_uptime_30d_r2612 u
    GROUP BY u.severity_kind
    ORDER BY
      CASE u.severity_kind
        WHEN 'critical' THEN 1
        WHEN 'red' THEN 2
        WHEN 'amber' THEN 3
        WHEN 'green' THEN 4
        ELSE 5
      END ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.severity_distribution_r2612() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.severity_distribution_r2612() TO authenticated;

-- RPC 5: monthly uptime trend
CREATE OR REPLACE FUNCTION public.monthly_uptime_trend_r2612()
RETURNS TABLE (
  month_label text,
  assets_tracked int,
  avg_uptime_pct numeric,
  total_downtime_minutes int,
  total_breaches int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', u.window_end_date), 'YYYY-MM') AS month_label,
           COUNT(*)::int AS assets_tracked,
           ROUND(AVG(u.uptime_pct)::numeric, 2) AS avg_uptime_pct,
           SUM(u.downtime_minutes)::int AS total_downtime_minutes,
           SUM(u.slo_breach_count)::int AS total_breaches
    FROM public.customer_uptime_30d_r2612 u
    GROUP BY date_trunc('month', u.window_end_date)
    ORDER BY date_trunc('month', u.window_end_date) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_uptime_trend_r2612() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_uptime_trend_r2612() TO authenticated;

-- RPC 6: action kind breakdown
CREATE OR REPLACE FUNCTION public.action_kind_breakdown_r2612()
RETURNS TABLE (
  action_kind text,
  total_actions int,
  done_actions int,
  positive_outcomes int,
  open_actions int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.action_kind,
           COUNT(*)::int AS total_actions,
           SUM(CASE WHEN a.status = 'done' THEN 1 ELSE 0 END)::int AS done_actions,
           SUM(CASE WHEN a.outcome = 'positive' THEN 1 ELSE 0 END)::int AS positive_outcomes,
           SUM(CASE WHEN a.status = 'open' THEN 1 ELSE 0 END)::int AS open_actions
    FROM public.uptime_breach_actions_r2612 a
    GROUP BY a.action_kind
    ORDER BY total_actions DESC, a.action_kind ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_breakdown_r2612() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_breakdown_r2612() TO authenticated;

-- RPC 7: hospital uptime summary
CREATE OR REPLACE FUNCTION public.hospital_uptime_summary_r2612()
RETURNS TABLE (
  equipment_kind text,
  total_assets int,
  avg_uptime_pct numeric,
  critical_assets int,
  red_assets int,
  amber_assets int,
  green_assets int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.equipment_kind,
           COUNT(*)::int AS total_assets,
           ROUND(AVG(u.uptime_pct)::numeric, 2) AS avg_uptime_pct,
           SUM(CASE WHEN u.severity_kind = 'critical' THEN 1 ELSE 0 END)::int AS critical_assets,
           SUM(CASE WHEN u.severity_kind = 'red' THEN 1 ELSE 0 END)::int AS red_assets,
           SUM(CASE WHEN u.severity_kind = 'amber' THEN 1 ELSE 0 END)::int AS amber_assets,
           SUM(CASE WHEN u.severity_kind = 'green' THEN 1 ELSE 0 END)::int AS green_assets
    FROM public.customer_uptime_30d_r2612 u
    GROUP BY u.equipment_kind
    ORDER BY critical_assets DESC, red_assets DESC, u.equipment_kind ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.hospital_uptime_summary_r2612() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hospital_uptime_summary_r2612() TO authenticated;
