-- Round 2660: customer quarterly implementation debt tracker
-- Tracks unkept promises, workarounds, missing features per hospital customer per quarter
-- plus close-out actions taken to retire each debt item.

CREATE TABLE IF NOT EXISTS public.customer_implementation_debt_r2660 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  debt_kind text NOT NULL CHECK (debt_kind IN ('promise_unkept','workaround_left','missing_feature','training_skip','process_gap')),
  debt_severity text NOT NULL CHECK (debt_severity IN ('low','medium','high','critical')),
  cost_to_close_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS customer_implementation_debt_r2660_hospital_idx ON public.customer_implementation_debt_r2660(hospital_user_id);
CREATE INDEX IF NOT EXISTS customer_implementation_debt_r2660_quarter_idx ON public.customer_implementation_debt_r2660(quarter_label);
CREATE INDEX IF NOT EXISTS customer_implementation_debt_r2660_status_idx ON public.customer_implementation_debt_r2660(status);

ALTER TABLE public.customer_implementation_debt_r2660 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_implementation_debt_r2660;
CREATE POLICY founder_all ON public.customer_implementation_debt_r2660
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.debt_close_actions_r2660 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id uuid NOT NULL REFERENCES public.customer_implementation_debt_r2660(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('ship_feature','retrain','manual_followup','escalation','refund')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS debt_close_actions_r2660_debt_idx ON public.debt_close_actions_r2660(debt_id);
CREATE INDEX IF NOT EXISTS debt_close_actions_r2660_at_idx ON public.debt_close_actions_r2660(action_at DESC);

ALTER TABLE public.debt_close_actions_r2660 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.debt_close_actions_r2660;
CREATE POLICY founder_all ON public.debt_close_actions_r2660
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed rows
DO $seed$
DECLARE
  v_hospital uuid;
  v_debt1 uuid;
  v_debt2 uuid;
  v_debt3 uuid;
  v_debt4 uuid;
BEGIN
  SELECT id INTO v_hospital FROM public.profiles WHERE role = 'hospital_admin' LIMIT 1;
  IF v_hospital IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_implementation_debt_r2660(hospital_user_id, quarter_label, debt_kind, debt_severity, cost_to_close_rupees, owner_email, status, notes)
  VALUES (v_hospital, '2026-Q2', 'promise_unkept', 'high', 45000, 'cs@equipseva.com', 'open', 'Promised AMC dashboard preview at onboarding, not delivered')
  RETURNING id INTO v_debt1;

  INSERT INTO public.customer_implementation_debt_r2660(hospital_user_id, quarter_label, debt_kind, debt_severity, cost_to_close_rupees, owner_email, status, notes)
  VALUES (v_hospital, '2026-Q2', 'workaround_left', 'medium', 8000, 'ops@equipseva.com', 'in_progress', 'CSV export workaround for invoice batch download')
  RETURNING id INTO v_debt2;

  INSERT INTO public.customer_implementation_debt_r2660(hospital_user_id, quarter_label, debt_kind, debt_severity, cost_to_close_rupees, owner_email, status, notes)
  VALUES (v_hospital, '2026-Q1', 'missing_feature', 'critical', 120000, 'product@equipseva.com', 'open', 'NABH audit ZIP export pending for surgery wing')
  RETURNING id INTO v_debt3;

  INSERT INTO public.customer_implementation_debt_r2660(hospital_user_id, quarter_label, debt_kind, debt_severity, cost_to_close_rupees, owner_email, status, notes)
  VALUES (v_hospital, '2026-Q1', 'training_skip', 'low', 3500, 'training@equipseva.com', 'closed', 'Biomed team training rescheduled twice and finally done')
  RETURNING id INTO v_debt4;

  INSERT INTO public.debt_close_actions_r2660(debt_id, action_at, action_kind, outcome, owner_email, status, notes) VALUES
    (v_debt1, (now() - interval '5 days')::timestamptz, 'ship_feature', 'pending', 'cs@equipseva.com', 'open', 'Engineering ticket filed for AMC dashboard'),
    (v_debt2, (now() - interval '2 days')::timestamptz, 'manual_followup', 'neutral', 'ops@equipseva.com', 'open', 'Sent CSV template by email'),
    (v_debt3, (now() - interval '10 days')::timestamptz, 'escalation', 'pending', 'founder@equipseva.com', 'open', 'Escalated to founder for prioritization'),
    (v_debt4, (now() - interval '1 day')::timestamptz, 'retrain', 'positive', 'training@equipseva.com', 'done', 'Onsite training completed for biomed team');
END
$seed$;

-- RPC 1: list_debt_r2660
CREATE OR REPLACE FUNCTION public.list_debt_r2660()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  quarter_label text,
  debt_kind text,
  debt_severity text,
  cost_to_close_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_user_id, p.email::text, d.quarter_label, d.debt_kind, d.debt_severity,
         d.cost_to_close_rupees, d.owner_email, d.status, d.notes, d.created_at
  FROM public.customer_implementation_debt_r2660 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  ORDER BY d.created_at DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_debt_r2660() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_debt_r2660() TO authenticated;

-- RPC 2: list_close_actions_r2660
CREATE OR REPLACE FUNCTION public.list_close_actions_r2660()
RETURNS TABLE (
  id uuid,
  debt_id uuid,
  quarter_label text,
  debt_kind text,
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
  SELECT a.id, a.debt_id, d.quarter_label, d.debt_kind, a.action_at, a.action_kind,
         a.outcome, a.owner_email, a.status, a.notes
  FROM public.debt_close_actions_r2660 a
  JOIN public.customer_implementation_debt_r2660 d ON d.id = a.debt_id
  ORDER BY a.action_at DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_close_actions_r2660() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_close_actions_r2660() TO authenticated;

-- RPC 3: top_debt_focus_r2660
CREATE OR REPLACE FUNCTION public.top_debt_focus_r2660()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  debt_kind text,
  debt_severity text,
  cost_to_close_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.quarter_label, d.debt_kind, d.debt_severity, d.cost_to_close_rupees,
         d.owner_email, d.status, d.notes
  FROM public.customer_implementation_debt_r2660 d
  WHERE d.status IN ('open','in_progress')
  ORDER BY
    CASE d.debt_severity
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END,
    d.cost_to_close_rupees DESC
  LIMIT 10;
END
$$;
REVOKE EXECUTE ON FUNCTION public.top_debt_focus_r2660() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_debt_focus_r2660() TO authenticated;

-- RPC 4: debt_kind_distribution_r2660
CREATE OR REPLACE FUNCTION public.debt_kind_distribution_r2660()
RETURNS TABLE (
  debt_kind text,
  cnt bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.debt_kind, count(*)::bigint, coalesce(sum(d.cost_to_close_rupees),0)::bigint
  FROM public.customer_implementation_debt_r2660 d
  GROUP BY d.debt_kind
  ORDER BY count(*) DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.debt_kind_distribution_r2660() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.debt_kind_distribution_r2660() TO authenticated;

-- RPC 5: status_funnel_r2660
CREATE OR REPLACE FUNCTION public.status_funnel_r2660()
RETURNS TABLE (
  status text,
  cnt bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.status, count(*)::bigint, coalesce(sum(d.cost_to_close_rupees),0)::bigint
  FROM public.customer_implementation_debt_r2660 d
  GROUP BY d.status
  ORDER BY count(*) DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2660() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2660() TO authenticated;

-- RPC 6: quarterly_debt_trend_r2660
CREATE OR REPLACE FUNCTION public.quarterly_debt_trend_r2660()
RETURNS TABLE (
  quarter_label text,
  cnt bigint,
  open_cnt bigint,
  closed_cnt bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.quarter_label,
         count(*)::bigint,
         count(*) FILTER (WHERE d.status IN ('open','in_progress'))::bigint,
         count(*) FILTER (WHERE d.status = 'closed')::bigint,
         coalesce(sum(d.cost_to_close_rupees),0)::bigint
  FROM public.customer_implementation_debt_r2660 d
  GROUP BY d.quarter_label
  ORDER BY d.quarter_label DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_debt_trend_r2660() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_debt_trend_r2660() TO authenticated;

-- RPC 7: total_cost_summary_r2660
CREATE OR REPLACE FUNCTION public.total_cost_summary_r2660()
RETURNS TABLE (
  total_debt_count bigint,
  open_count bigint,
  closed_count bigint,
  total_cost_rupees bigint,
  open_cost_rupees bigint,
  closed_cost_rupees bigint,
  critical_open_count bigint,
  actions_logged bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE d.status IN ('open','in_progress'))::bigint,
    count(*) FILTER (WHERE d.status = 'closed')::bigint,
    coalesce(sum(d.cost_to_close_rupees),0)::bigint,
    coalesce(sum(d.cost_to_close_rupees) FILTER (WHERE d.status IN ('open','in_progress')),0)::bigint,
    coalesce(sum(d.cost_to_close_rupees) FILTER (WHERE d.status = 'closed'),0)::bigint,
    count(*) FILTER (WHERE d.status IN ('open','in_progress') AND d.debt_severity = 'critical')::bigint,
    (SELECT count(*) FROM public.debt_close_actions_r2660)::bigint
  FROM public.customer_implementation_debt_r2660 d;
END
$$;
REVOKE EXECUTE ON FUNCTION public.total_cost_summary_r2660() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_cost_summary_r2660() TO authenticated;
