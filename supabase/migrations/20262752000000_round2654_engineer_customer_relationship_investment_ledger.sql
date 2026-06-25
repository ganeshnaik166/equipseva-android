-- r2654 engineer_customer_relationship_investment_ledger

CREATE TABLE IF NOT EXISTS public.engineer_relationship_investments_r2654 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invested_at timestamptz NOT NULL DEFAULT now(),
  investment_kind text NOT NULL CHECK (investment_kind IN ('time','money','gift','event','personal_favor')),
  value_rupees int NOT NULL DEFAULT 0,
  hours_invested numeric(8,2) NOT NULL DEFAULT 0,
  expected_return_kind text NOT NULL CHECK (expected_return_kind IN ('arr','retention','referral','champion_advocate','none')),
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.relationship_investment_outcomes_r2654 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investment_id uuid NOT NULL REFERENCES public.engineer_relationship_investments_r2654(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('arr_uplift','retained','referred','championed','none')),
  revenue_realized_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_relationship_investments_r2654 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relationship_investment_outcomes_r2654 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_relationship_investments_r2654;
CREATE POLICY founder_all ON public.engineer_relationship_investments_r2654
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.relationship_investment_outcomes_r2654;
CREATE POLICY founder_all ON public.relationship_investment_outcomes_r2654
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS eri_r2654_engineer_idx ON public.engineer_relationship_investments_r2654(engineer_user_id);
CREATE INDEX IF NOT EXISTS eri_r2654_hospital_idx ON public.engineer_relationship_investments_r2654(hospital_user_id);
CREATE INDEX IF NOT EXISTS eri_r2654_invested_at_idx ON public.engineer_relationship_investments_r2654(invested_at);
CREATE INDEX IF NOT EXISTS rio_r2654_inv_idx ON public.relationship_investment_outcomes_r2654(investment_id);
CREATE INDEX IF NOT EXISTS rio_r2654_observed_idx ON public.relationship_investment_outcomes_r2654(observed_at);

-- Seed 4 rows
INSERT INTO public.engineer_relationship_investments_r2654 (engineer_user_id, hospital_user_id, invested_at, investment_kind, value_rupees, hours_invested, expected_return_kind, owner_email, status, notes)
SELECT e.id, p.id, (now() - interval '20 days')::timestamptz, 'time', 0, 4.5, 'retention', 'founder@equipseva.in', 'done', 'On-site coffee chat with biomed lead'
FROM public.engineers e, public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.engineer_relationship_investments_r2654 (engineer_user_id, hospital_user_id, invested_at, investment_kind, value_rupees, hours_invested, expected_return_kind, owner_email, status, notes)
SELECT e.id, p.id, (now() - interval '12 days')::timestamptz, 'gift', 2500, 0, 'champion_advocate', 'founder@equipseva.in', 'done', 'Diwali sweets box to admin team'
FROM public.engineers e, public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.engineer_relationship_investments_r2654 (engineer_user_id, hospital_user_id, invested_at, investment_kind, value_rupees, hours_invested, expected_return_kind, owner_email, status, notes)
SELECT e.id, p.id, (now() - interval '5 days')::timestamptz, 'event', 8000, 2.0, 'arr', 'founder@equipseva.in', 'planned', 'Sponsored CME dinner for radiology'
FROM public.engineers e, public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.engineer_relationship_investments_r2654 (engineer_user_id, hospital_user_id, invested_at, investment_kind, value_rupees, hours_invested, expected_return_kind, owner_email, status, notes)
SELECT e.id, p.id, (now() - interval '40 days')::timestamptz, 'personal_favor', 0, 3.0, 'referral', 'founder@equipseva.in', 'done', 'Helped admin source spare cable urgently'
FROM public.engineers e, public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.relationship_investment_outcomes_r2654 (investment_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, (invested_at + interval '15 days')::timestamptz, 'arr_uplift', 45000, 'founder@equipseva.in', 'done', 'AMC tier upgraded after relationship build'
FROM public.engineer_relationship_investments_r2654
WHERE status = 'done'
LIMIT 1;

INSERT INTO public.relationship_investment_outcomes_r2654 (investment_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, (invested_at + interval '8 days')::timestamptz, 'championed', 0, 'founder@equipseva.in', 'open', 'Admin spoke about us in chain WhatsApp group'
FROM public.engineer_relationship_investments_r2654
WHERE investment_kind = 'gift'
LIMIT 1;

INSERT INTO public.relationship_investment_outcomes_r2654 (investment_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, (invested_at + interval '30 days')::timestamptz, 'referred', 120000, 'founder@equipseva.in', 'done', 'Referral led to new hospital onboarding'
FROM public.engineer_relationship_investments_r2654
WHERE investment_kind = 'personal_favor'
LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_investments_r2654()
RETURNS TABLE(id uuid, engineer_user_id uuid, hospital_user_id uuid, invested_at timestamptz, investment_kind text, value_rupees int, hours_invested numeric, expected_return_kind text, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id, i.hospital_user_id, i.invested_at, i.investment_kind, i.value_rupees, i.hours_invested, i.expected_return_kind, i.owner_email, i.status, i.notes, i.created_at
  FROM public.engineer_relationship_investments_r2654 i
  ORDER BY i.invested_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_investments_r2654() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investments_r2654() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_outcomes_r2654()
RETURNS TABLE(id uuid, investment_id uuid, observed_at timestamptz, outcome_kind text, revenue_realized_rupees bigint, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.investment_id, o.observed_at, o.outcome_kind, o.revenue_realized_rupees, o.owner_email, o.status, o.notes, o.created_at
  FROM public.relationship_investment_outcomes_r2654 o
  ORDER BY o.observed_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2654() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2654() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_value_focus_r2654()
RETURNS TABLE(hospital_user_id uuid, investment_count bigint, total_value_rupees bigint, total_hours numeric, total_realized_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.hospital_user_id,
         COUNT(*)::bigint AS investment_count,
         COALESCE(SUM(i.value_rupees),0)::bigint AS total_value_rupees,
         COALESCE(SUM(i.hours_invested),0)::numeric AS total_hours,
         COALESCE((SELECT SUM(o.revenue_realized_rupees) FROM public.relationship_investment_outcomes_r2654 o WHERE o.investment_id IN (SELECT id FROM public.engineer_relationship_investments_r2654 WHERE hospital_user_id = i.hospital_user_id)),0)::bigint AS total_realized_rupees
  FROM public.engineer_relationship_investments_r2654 i
  GROUP BY i.hospital_user_id
  ORDER BY total_realized_rupees DESC, investment_count DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_value_focus_r2654() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_focus_r2654() TO authenticated;

CREATE OR REPLACE FUNCTION public.kind_distribution_r2654()
RETURNS TABLE(investment_kind text, investment_count bigint, total_value_rupees bigint, total_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.investment_kind,
         COUNT(*)::bigint,
         COALESCE(SUM(i.value_rupees),0)::bigint,
         COALESCE(SUM(i.hours_invested),0)::numeric
  FROM public.engineer_relationship_investments_r2654 i
  GROUP BY i.investment_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.kind_distribution_r2654() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_distribution_r2654() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2654()
RETURNS TABLE(status text, investment_count bigint, total_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.status,
         COUNT(*)::bigint,
         COALESCE(SUM(i.value_rupees),0)::bigint
  FROM public.engineer_relationship_investments_r2654 i
  GROUP BY i.status
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2654() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2654() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_investment_trend_r2654()
RETURNS TABLE(month_start date, investment_count bigint, total_value_rupees bigint, total_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', i.invested_at)::date AS month_start,
         COUNT(*)::bigint,
         COALESCE(SUM(i.value_rupees),0)::bigint,
         COALESCE(SUM(i.hours_invested),0)::numeric
  FROM public.engineer_relationship_investments_r2654 i
  GROUP BY 1
  ORDER BY 1 DESC
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_investment_trend_r2654() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_investment_trend_r2654() TO authenticated;

CREATE OR REPLACE FUNCTION public.total_realized_summary_r2654()
RETURNS TABLE(total_investments bigint, total_value_rupees bigint, total_hours numeric, total_outcomes bigint, total_realized_rupees bigint, roi_multiple numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_value bigint;
  v_realized bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(value_rupees),0)::bigint INTO v_value FROM public.engineer_relationship_investments_r2654;
  SELECT COALESCE(SUM(revenue_realized_rupees),0)::bigint INTO v_realized FROM public.relationship_investment_outcomes_r2654;
  RETURN QUERY
  SELECT (SELECT COUNT(*) FROM public.engineer_relationship_investments_r2654)::bigint,
         v_value,
         (SELECT COALESCE(SUM(hours_invested),0)::numeric FROM public.engineer_relationship_investments_r2654),
         (SELECT COUNT(*) FROM public.relationship_investment_outcomes_r2654)::bigint,
         v_realized,
         CASE WHEN v_value > 0 THEN ROUND((v_realized::numeric / v_value::numeric), 2) ELSE 0 END;
END $$;
REVOKE EXECUTE ON FUNCTION public.total_realized_summary_r2654() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_realized_summary_r2654() TO authenticated;
