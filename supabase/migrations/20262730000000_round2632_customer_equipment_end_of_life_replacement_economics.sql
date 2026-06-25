-- Round 2632: customer equipment end-of-life replacement economics

CREATE TABLE IF NOT EXISTS public.customer_eol_economics_r2632 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  age_years numeric NOT NULL DEFAULT 0,
  maintenance_ttm_rupees bigint NOT NULL DEFAULT 0,
  replacement_cost_rupees bigint NOT NULL DEFAULT 0,
  payback_months numeric NOT NULL DEFAULT 0,
  decision_kind text NOT NULL DEFAULT 'wait_12mo' CHECK (decision_kind IN ('replace_now','wait_12mo','wait_24mo','no_replace')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','quoted','decided','dropped')),
  notes text
);

ALTER TABLE public.customer_eol_economics_r2632 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_eol_economics_r2632;
CREATE POLICY founder_all ON public.customer_eol_economics_r2632 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.eol_economics_decisions_r2632 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  economics_id uuid NOT NULL REFERENCES public.customer_eol_economics_r2632(id) ON DELETE CASCADE,
  decided_at timestamptz NOT NULL DEFAULT now(),
  decision_kind text NOT NULL,
  summary_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.eol_economics_decisions_r2632 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.eol_economics_decisions_r2632;
CREATE POLICY founder_all ON public.eol_economics_decisions_r2632 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.customer_eol_economics_r2632 (equipment_label, age_years, maintenance_ttm_rupees, replacement_cost_rupees, payback_months, decision_kind, owner_email, status, notes) VALUES
  ('Ultrasound Unit A', 9.5, 180000, 1200000, 14.2, 'replace_now', 'ops1@example.com', 'quoted', 'High TTM cost, replacement justified'),
  ('CT Scanner B', 7.0, 420000, 9500000, 33.5, 'wait_12mo', 'ops2@example.com', 'monitoring', 'Watch utilization next quarter'),
  ('Patient Monitor C', 11.2, 60000, 220000, 9.8, 'replace_now', 'ops1@example.com', 'decided', 'Refurb option declined'),
  ('Ventilator D', 5.0, 90000, 850000, 28.0, 'wait_24mo', 'ops3@example.com', 'monitoring', 'Within MTBF window'),
  ('X-Ray Mobile E', 13.0, 240000, 1500000, 18.5, 'replace_now', 'ops2@example.com', 'quoted', 'Parts availability dropping');

INSERT INTO public.eol_economics_decisions_r2632 (economics_id, decision_kind, summary_md, owner_email, status, notes)
SELECT id, decision_kind, '## Decision\nApproved per economics review', owner_email, 'open', 'Initial decision logged'
FROM public.customer_eol_economics_r2632
LIMIT 4;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_economics_r2632()
RETURNS SETOF public.customer_eol_economics_r2632
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_eol_economics_r2632 ORDER BY created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_economics_r2632() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_economics_r2632() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_decisions_r2632()
RETURNS SETOF public.eol_economics_decisions_r2632
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.eol_economics_decisions_r2632 ORDER BY decided_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_decisions_r2632() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decisions_r2632() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_payback_focus_r2632()
RETURNS TABLE(equipment_label text, payback_months numeric, maintenance_ttm_rupees bigint, replacement_cost_rupees bigint, decision_kind text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.equipment_label, e.payback_months, e.maintenance_ttm_rupees, e.replacement_cost_rupees, e.decision_kind
    FROM public.customer_eol_economics_r2632 e
    ORDER BY e.payback_months ASC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_payback_focus_r2632() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_payback_focus_r2632() TO authenticated;

CREATE OR REPLACE FUNCTION public.decision_kind_distribution_r2632()
RETURNS TABLE(decision_kind text, cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.decision_kind, count(*)::bigint
    FROM public.customer_eol_economics_r2632 e
    GROUP BY e.decision_kind
    ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_kind_distribution_r2632() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_kind_distribution_r2632() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2632()
RETURNS TABLE(status text, cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.status, count(*)::bigint
    FROM public.customer_eol_economics_r2632 e
    GROUP BY e.status
    ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2632() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2632() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_decision_trend_r2632()
RETURNS TABLE(month_label text, cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', d.decided_at), 'YYYY-MM') AS month_label, count(*)::bigint
    FROM public.eol_economics_decisions_r2632 d
    GROUP BY date_trunc('month', d.decided_at)
    ORDER BY date_trunc('month', d.decided_at) DESC
    LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_decision_trend_r2632() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_decision_trend_r2632() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2632()
RETURNS TABLE(owner_email text, cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT coalesce(e.owner_email, 'unassigned') AS owner_email, count(*)::bigint
    FROM public.customer_eol_economics_r2632 e
    GROUP BY coalesce(e.owner_email, 'unassigned')
    ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2632() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2632() TO authenticated;
