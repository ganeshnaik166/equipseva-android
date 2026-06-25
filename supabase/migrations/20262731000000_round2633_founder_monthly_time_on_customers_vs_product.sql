-- r2633 founder-monthly-time-on-customers-vs-product

CREATE TABLE IF NOT EXISTS public.founder_time_allocation_r2633 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  customer_hours numeric NOT NULL DEFAULT 0,
  product_hours numeric NOT NULL DEFAULT 0,
  team_hours numeric NOT NULL DEFAULT 0,
  fundraise_hours numeric NOT NULL DEFAULT 0,
  total_hours numeric NOT NULL DEFAULT 0,
  balance_kind text NOT NULL DEFAULT 'balanced' CHECK (balance_kind IN ('over_customers','over_product','balanced','over_team','over_fundraise')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','in_review','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.time_allocation_corrections_r2633 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  allocation_id uuid NOT NULL REFERENCES public.founder_time_allocation_r2633(id) ON DELETE CASCADE,
  correction_at timestamptz NOT NULL DEFAULT now(),
  correction_kind text NOT NULL CHECK (correction_kind IN ('delegate_customer','delegate_product','calendar_rebalance','saying_no')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_time_allocation_r2633 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_allocation_corrections_r2633 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_time_allocation_r2633;
CREATE POLICY founder_all ON public.founder_time_allocation_r2633
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.time_allocation_corrections_r2633;
CREATE POLICY founder_all ON public.time_allocation_corrections_r2633
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.founder_time_allocation_r2633 (month_label, customer_hours, product_hours, team_hours, fundraise_hours, total_hours, balance_kind, owner_email, status, notes) VALUES
  ('2026-02', 80, 40, 20, 10, 150, 'over_customers', 'founder@equipseva.in', 'closed', 'Heavy hospital visits month'),
  ('2026-03', 30, 90, 20, 15, 155, 'over_product', 'founder@equipseva.in', 'in_review', 'Engineer app v0.3 build sprint'),
  ('2026-04', 50, 50, 30, 25, 155, 'balanced', 'founder@equipseva.in', 'closed', 'Healthy split across pillars'),
  ('2026-05', 25, 40, 70, 20, 155, 'over_team', 'founder@equipseva.in', 'monitoring', 'Hiring + onboarding 4 engineers'),
  ('2026-06', 35, 35, 15, 80, 165, 'over_fundraise', 'founder@equipseva.in', 'monitoring', 'Seed round prep + investor meetings');

INSERT INTO public.time_allocation_corrections_r2633 (allocation_id, correction_kind, outcome, owner_email, status, notes)
SELECT id, 'delegate_product', 'positive', 'founder@equipseva.in', 'done', 'Handed Compose audit to senior eng'
FROM public.founder_time_allocation_r2633 WHERE month_label = '2026-03' LIMIT 1;

INSERT INTO public.time_allocation_corrections_r2633 (allocation_id, correction_kind, outcome, owner_email, status, notes)
SELECT id, 'calendar_rebalance', 'neutral', 'founder@equipseva.in', 'open', 'Blocked 2 mornings per week for customer calls'
FROM public.founder_time_allocation_r2633 WHERE month_label = '2026-05' LIMIT 1;

INSERT INTO public.time_allocation_corrections_r2633 (allocation_id, correction_kind, outcome, owner_email, status, notes)
SELECT id, 'saying_no', 'positive', 'founder@equipseva.in', 'done', 'Declined 3 investor intros to focus on existing diligence'
FROM public.founder_time_allocation_r2633 WHERE month_label = '2026-06' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_allocation_r2633()
RETURNS SETOF public.founder_time_allocation_r2633
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_time_allocation_r2633 ORDER BY month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_allocation_r2633() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_allocation_r2633() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_corrections_r2633()
RETURNS SETOF public.time_allocation_corrections_r2633
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.time_allocation_corrections_r2633 ORDER BY correction_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_corrections_r2633() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_corrections_r2633() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_balance_focus_r2633()
RETURNS TABLE(month_label text, balance_kind text, total_hours numeric, customer_hours numeric, product_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.month_label, a.balance_kind, a.total_hours, a.customer_hours, a.product_hours
  FROM public.founder_time_allocation_r2633 a
  WHERE a.status IN ('monitoring','in_review')
  ORDER BY a.total_hours DESC
  LIMIT 5;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_balance_focus_r2633() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_balance_focus_r2633() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_allocation_trend_r2633()
RETURNS TABLE(month_label text, customer_hours numeric, product_hours numeric, team_hours numeric, fundraise_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.month_label, a.customer_hours, a.product_hours, a.team_hours, a.fundraise_hours
  FROM public.founder_time_allocation_r2633 a
  ORDER BY a.month_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_allocation_trend_r2633() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_allocation_trend_r2633() TO authenticated;

CREATE OR REPLACE FUNCTION public.balance_kind_distribution_r2633()
RETURNS TABLE(balance_kind text, month_count bigint, total_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.balance_kind, COUNT(*)::bigint, COALESCE(SUM(a.total_hours),0)
  FROM public.founder_time_allocation_r2633 a
  GROUP BY a.balance_kind
  ORDER BY month_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.balance_kind_distribution_r2633() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.balance_kind_distribution_r2633() TO authenticated;

CREATE OR REPLACE FUNCTION public.correction_status_funnel_r2633()
RETURNS TABLE(status text, correction_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status, COUNT(*)::bigint
  FROM public.time_allocation_corrections_r2633 c
  GROUP BY c.status
  ORDER BY correction_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.correction_status_funnel_r2633() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.correction_status_funnel_r2633() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2633()
RETURNS TABLE(months_tracked bigint, total_logged_hours numeric, total_customer_hours numeric, total_product_hours numeric, open_corrections bigint, positive_outcomes bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM public.founder_time_allocation_r2633),
    (SELECT COALESCE(SUM(total_hours),0) FROM public.founder_time_allocation_r2633),
    (SELECT COALESCE(SUM(customer_hours),0) FROM public.founder_time_allocation_r2633),
    (SELECT COALESCE(SUM(product_hours),0) FROM public.founder_time_allocation_r2633),
    (SELECT COUNT(*)::bigint FROM public.time_allocation_corrections_r2633 WHERE status = 'open'),
    (SELECT COUNT(*)::bigint FROM public.time_allocation_corrections_r2633 WHERE outcome = 'positive');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2633() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2633() TO authenticated;
