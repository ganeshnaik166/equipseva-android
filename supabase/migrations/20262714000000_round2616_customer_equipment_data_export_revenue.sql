-- Round 2616: Customer Equipment Data Export Revenue
-- Tracks hospital data export subscriptions (CSV, API, reports) as a revenue line
-- and a renewal log capturing churn/upgrade events.

CREATE TABLE IF NOT EXISTS public.customer_data_export_revenue_r2616 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  export_kind text NOT NULL CHECK (export_kind IN ('daily_csv','api_seat','report_subscription','analytics_pack','training_credit')),
  monthly_revenue_rupees bigint NOT NULL DEFAULT 0,
  contract_months integer NOT NULL DEFAULT 12,
  owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','cancelled','upgraded')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.data_export_renewal_log_r2616 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  export_id uuid REFERENCES public.customer_data_export_revenue_r2616(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('renewed','upgraded','cancelled','downgraded')),
  revenue_delta_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_data_export_revenue_r2616 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_export_renewal_log_r2616 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_data_export_revenue_r2616;
CREATE POLICY founder_all ON public.customer_data_export_revenue_r2616
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.data_export_renewal_log_r2616;
CREATE POLICY founder_all ON public.data_export_renewal_log_r2616
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.customer_data_export_revenue_r2616 (hospital_user_id, equipment_label, export_kind, monthly_revenue_rupees, contract_months, owner_email, status, notes)
VALUES
  (NULL, 'Philips MRI 1.5T', 'daily_csv', 12000, 12, 'data@apollo.example', 'active', 'Daily CSV pull to BI lake'),
  (NULL, 'GE CT 64-slice', 'api_seat', 28000, 24, 'cio@yashoda.example', 'active', 'Two API seats with webhook delivery'),
  (NULL, 'Mindray Ventilator Fleet', 'report_subscription', 9500, 12, 'biomed@kims.example', 'paused', 'Paused during fleet expansion'),
  (NULL, 'Siemens Cath Lab', 'analytics_pack', 45000, 36, 'finance@medanta.example', 'upgraded', 'Upgraded from report sub last quarter'),
  (NULL, 'Drager Anaesthesia Bundle', 'training_credit', 6500, 6, 'edu@manipal.example', 'cancelled', 'Cancelled after one cycle');

INSERT INTO public.data_export_renewal_log_r2616 (export_id, event_at, event_kind, revenue_delta_rupees, owner_email, status, notes)
SELECT id, now() - interval '14 days', 'renewed', 0, owner_email, 'done', 'Standard annual renewal'
FROM public.customer_data_export_revenue_r2616 WHERE equipment_label = 'Philips MRI 1.5T' LIMIT 1;

INSERT INTO public.data_export_renewal_log_r2616 (export_id, event_at, event_kind, revenue_delta_rupees, owner_email, status, notes)
SELECT id, now() - interval '7 days', 'upgraded', 17000, owner_email, 'done', 'Bumped report sub to analytics pack'
FROM public.customer_data_export_revenue_r2616 WHERE equipment_label = 'Siemens Cath Lab' LIMIT 1;

INSERT INTO public.data_export_renewal_log_r2616 (export_id, event_at, event_kind, revenue_delta_rupees, owner_email, status, notes)
SELECT id, now() - interval '2 days', 'cancelled', -6500, owner_email, 'dropped', 'Customer rebuilt training internally'
FROM public.customer_data_export_revenue_r2616 WHERE equipment_label = 'Drager Anaesthesia Bundle' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_data_exports_r2616()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  export_kind text,
  monthly_revenue_rupees bigint,
  contract_months integer,
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
    SELECT r.id, r.equipment_label, r.export_kind, r.monthly_revenue_rupees, r.contract_months,
           r.owner_email, r.status, r.notes, r.created_at
    FROM public.customer_data_export_revenue_r2616 r
    ORDER BY r.monthly_revenue_rupees DESC, r.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_data_exports_r2616() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_data_exports_r2616() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_renewal_log_r2616()
RETURNS TABLE (
  id uuid,
  export_id uuid,
  equipment_label text,
  event_at timestamptz,
  event_kind text,
  revenue_delta_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.export_id, r.equipment_label, l.event_at, l.event_kind,
           l.revenue_delta_rupees, l.owner_email, l.status, l.notes
    FROM public.data_export_renewal_log_r2616 l
    LEFT JOIN public.customer_data_export_revenue_r2616 r ON r.id = l.export_id
    ORDER BY l.event_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_renewal_log_r2616() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_renewal_log_r2616() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_revenue_exports_r2616()
RETURNS TABLE (
  equipment_label text,
  export_kind text,
  monthly_revenue_rupees bigint,
  annualized_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.equipment_label, r.export_kind, r.monthly_revenue_rupees,
           (r.monthly_revenue_rupees * 12)::bigint AS annualized_rupees, r.status
    FROM public.customer_data_export_revenue_r2616 r
    ORDER BY r.monthly_revenue_rupees DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_revenue_exports_r2616() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_revenue_exports_r2616() TO authenticated;

CREATE OR REPLACE FUNCTION public.export_kind_distribution_r2616()
RETURNS TABLE (
  export_kind text,
  contract_count bigint,
  total_monthly_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.export_kind, count(*)::bigint, coalesce(sum(r.monthly_revenue_rupees), 0)::bigint
    FROM public.customer_data_export_revenue_r2616 r
    GROUP BY r.export_kind
    ORDER BY coalesce(sum(r.monthly_revenue_rupees), 0)::bigint DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.export_kind_distribution_r2616() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.export_kind_distribution_r2616() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2616()
RETURNS TABLE (
  status text,
  contract_count bigint,
  total_monthly_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.status, count(*)::bigint, coalesce(sum(r.monthly_revenue_rupees), 0)::bigint
    FROM public.customer_data_export_revenue_r2616 r
    GROUP BY r.status
    ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2616() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2616() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_revenue_trend_r2616()
RETURNS TABLE (
  month_start date,
  net_delta_rupees bigint,
  event_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', l.event_at)::date AS month_start,
           coalesce(sum(l.revenue_delta_rupees), 0)::bigint AS net_delta_rupees,
           count(*)::bigint AS event_count
    FROM public.data_export_renewal_log_r2616 l
    GROUP BY date_trunc('month', l.event_at)
    ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_revenue_trend_r2616() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_revenue_trend_r2616() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2616()
RETURNS TABLE (
  owner_email text,
  active_contracts bigint,
  total_monthly_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT coalesce(r.owner_email, 'unassigned') AS owner_email,
           count(*) FILTER (WHERE r.status = 'active')::bigint AS active_contracts,
           coalesce(sum(r.monthly_revenue_rupees) FILTER (WHERE r.status = 'active'), 0)::bigint AS total_monthly_rupees
    FROM public.customer_data_export_revenue_r2616 r
    GROUP BY coalesce(r.owner_email, 'unassigned')
    ORDER BY total_monthly_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2616() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2616() TO authenticated;
