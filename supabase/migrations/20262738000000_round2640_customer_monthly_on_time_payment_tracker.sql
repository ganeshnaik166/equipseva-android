-- Round 2640: Customer Monthly On-Time Payment Tracker

CREATE TABLE IF NOT EXISTS public.customer_on_time_payments_r2640 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  month_label text NOT NULL,
  invoiced_rupees bigint NOT NULL DEFAULT 0,
  paid_on_time_rupees bigint NOT NULL DEFAULT 0,
  paid_late_rupees bigint NOT NULL DEFAULT 0,
  unpaid_rupees bigint NOT NULL DEFAULT 0,
  on_time_pct numeric(6,2) NOT NULL DEFAULT 0,
  days_to_pay_avg numeric(6,2) NOT NULL DEFAULT 0,
  payment_grade text NOT NULL DEFAULT 'C' CHECK (payment_grade IN ('A','B','C','D','F')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','escalated','cleared','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payment_collection_actions_r2640 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES public.customer_on_time_payments_r2640(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('reminder_call','early_pay_discount','dunning_email','legal_notice','refund')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_on_time_payments_r2640 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_collection_actions_r2640 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_on_time_payments_r2640;
CREATE POLICY founder_all ON public.customer_on_time_payments_r2640
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.payment_collection_actions_r2640;
CREATE POLICY founder_all ON public.payment_collection_actions_r2640
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.customer_on_time_payments_r2640 (hospital_user_id, month_label, invoiced_rupees, paid_on_time_rupees, paid_late_rupees, unpaid_rupees, on_time_pct, days_to_pay_avg, payment_grade, owner_email, status, notes) VALUES
  (NULL, '2026-03', 450000, 420000, 30000, 0, 93.33, 8.5, 'A', 'finance@equipseva.local', 'cleared', 'Excellent payer; auto-debit live'),
  (NULL, '2026-04', 380000, 200000, 120000, 60000, 52.63, 22.0, 'C', 'finance@equipseva.local', 'escalated', 'Two late cycles; CFO call booked'),
  (NULL, '2026-04', 620000, 80000, 200000, 340000, 12.90, 41.0, 'F', 'collections@equipseva.local', 'escalated', 'Legal notice draft ready'),
  (NULL, '2026-05', 250000, 250000, 0, 0, 100.00, 4.0, 'A', 'finance@equipseva.local', 'cleared', 'Pristine record'),
  (NULL, '2026-05', 510000, 300000, 150000, 60000, 58.82, 18.0, 'B', 'finance@equipseva.local', 'monitoring', 'Trending up; watch June');

INSERT INTO public.payment_collection_actions_r2640 (payment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '5 days')::timestamptz, 'reminder_call', 'positive', 'finance@equipseva.local', 'done', 'CFO promised payment in 3 days'
FROM public.customer_on_time_payments_r2640 WHERE month_label = '2026-04' AND payment_grade = 'C' LIMIT 1;

INSERT INTO public.payment_collection_actions_r2640 (payment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '2 days')::timestamptz, 'legal_notice', 'pending', 'collections@equipseva.local', 'open', 'Counsel drafting demand'
FROM public.customer_on_time_payments_r2640 WHERE payment_grade = 'F' LIMIT 1;

INSERT INTO public.payment_collection_actions_r2640 (payment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '1 day')::timestamptz, 'early_pay_discount', 'positive', 'finance@equipseva.local', 'done', '2 pct discount accepted'
FROM public.customer_on_time_payments_r2640 WHERE month_label = '2026-05' AND payment_grade = 'B' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_payments_r2640()
RETURNS TABLE (
  id uuid,
  month_label text,
  invoiced_rupees bigint,
  paid_on_time_rupees bigint,
  paid_late_rupees bigint,
  unpaid_rupees bigint,
  on_time_pct numeric,
  days_to_pay_avg numeric,
  payment_grade text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.month_label, p.invoiced_rupees, p.paid_on_time_rupees, p.paid_late_rupees,
         p.unpaid_rupees, p.on_time_pct, p.days_to_pay_avg, p.payment_grade,
         p.owner_email, p.status, p.notes, p.created_at
  FROM public.customer_on_time_payments_r2640 p
  ORDER BY p.month_label DESC, p.on_time_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_payments_r2640() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_payments_r2640() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_collection_actions_r2640()
RETURNS TABLE (
  id uuid,
  payment_id uuid,
  month_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.payment_id, p.month_label, a.action_at, a.action_kind,
         a.outcome, a.owner_email, a.status, a.notes
  FROM public.payment_collection_actions_r2640 a
  LEFT JOIN public.customer_on_time_payments_r2640 p ON p.id = a.payment_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_collection_actions_r2640() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_collection_actions_r2640() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_late_focus_r2640()
RETURNS TABLE (
  id uuid,
  month_label text,
  unpaid_rupees bigint,
  on_time_pct numeric,
  payment_grade text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.month_label, p.unpaid_rupees, p.on_time_pct, p.payment_grade, p.status
  FROM public.customer_on_time_payments_r2640 p
  WHERE p.status IN ('monitoring','escalated')
  ORDER BY p.unpaid_rupees DESC, p.on_time_pct ASC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_late_focus_r2640() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_late_focus_r2640() TO authenticated;

CREATE OR REPLACE FUNCTION public.grade_distribution_r2640()
RETURNS TABLE (
  payment_grade text,
  cnt bigint,
  invoiced_rupees bigint,
  unpaid_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.payment_grade, COUNT(*)::bigint AS cnt,
         COALESCE(SUM(p.invoiced_rupees),0)::bigint,
         COALESCE(SUM(p.unpaid_rupees),0)::bigint
  FROM public.customer_on_time_payments_r2640 p
  GROUP BY p.payment_grade
  ORDER BY p.payment_grade;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.grade_distribution_r2640() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grade_distribution_r2640() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2640()
RETURNS TABLE (
  status text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.status, COUNT(*)::bigint
  FROM public.customer_on_time_payments_r2640 p
  GROUP BY p.status
  ORDER BY p.status;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2640() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2640() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_payment_trend_r2640()
RETURNS TABLE (
  month_label text,
  invoiced_rupees bigint,
  paid_on_time_rupees bigint,
  unpaid_rupees bigint,
  on_time_pct_avg numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.month_label,
         COALESCE(SUM(p.invoiced_rupees),0)::bigint,
         COALESCE(SUM(p.paid_on_time_rupees),0)::bigint,
         COALESCE(SUM(p.unpaid_rupees),0)::bigint,
         ROUND(AVG(p.on_time_pct)::numeric, 2)
  FROM public.customer_on_time_payments_r2640 p
  GROUP BY p.month_label
  ORDER BY p.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_payment_trend_r2640() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_payment_trend_r2640() TO authenticated;

CREATE OR REPLACE FUNCTION public.total_unpaid_summary_r2640()
RETURNS TABLE (
  total_invoiced_rupees bigint,
  total_paid_on_time_rupees bigint,
  total_paid_late_rupees bigint,
  total_unpaid_rupees bigint,
  overall_on_time_pct numeric,
  escalated_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(p.invoiced_rupees),0)::bigint,
    COALESCE(SUM(p.paid_on_time_rupees),0)::bigint,
    COALESCE(SUM(p.paid_late_rupees),0)::bigint,
    COALESCE(SUM(p.unpaid_rupees),0)::bigint,
    CASE WHEN COALESCE(SUM(p.invoiced_rupees),0) > 0
      THEN ROUND((SUM(p.paid_on_time_rupees)::numeric * 100.0 / SUM(p.invoiced_rupees)::numeric), 2)
      ELSE 0::numeric END,
    COUNT(*) FILTER (WHERE p.status = 'escalated')::bigint
  FROM public.customer_on_time_payments_r2640 p;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.total_unpaid_summary_r2640() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_unpaid_summary_r2640() TO authenticated;
