-- Round 2596: customer yearly equipment aging replacement budget
-- hospital × equipment age × budget bucket × replacement priority × proposal × decision

CREATE TABLE IF NOT EXISTS public.customer_yearly_replacement_budget_r2596 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fiscal_year text NOT NULL,
  equipment_label text NOT NULL,
  equipment_age_years numeric(5,2),
  budget_bucket_kind text NOT NULL CHECK (budget_bucket_kind IN ('immediate','within_year','next_year','within_3_years','no_budget')),
  replacement_priority_kind text NOT NULL CHECK (replacement_priority_kind IN ('low','medium','high','critical')),
  proposed_replacement_value_rupees bigint,
  decision_kind text NOT NULL CHECK (decision_kind IN ('approved','pending','postponed','rejected')),
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','decided','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.replacement_proposal_log_r2596 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_id uuid NOT NULL REFERENCES public.customer_yearly_replacement_budget_r2596(id) ON DELETE CASCADE,
  proposed_at timestamptz NOT NULL DEFAULT now(),
  proposal_kind text NOT NULL CHECK (proposal_kind IN ('amc_replacement','upgrade_swap','sale_buyback','new_purchase','trade_in')),
  summary_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_yearly_replacement_budget_r2596 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.replacement_proposal_log_r2596 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_yearly_replacement_budget_r2596;
CREATE POLICY founder_all ON public.customer_yearly_replacement_budget_r2596
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.replacement_proposal_log_r2596;
CREATE POLICY founder_all ON public.replacement_proposal_log_r2596
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_hospital uuid;
  v_b1 uuid;
  v_b2 uuid;
  v_b3 uuid;
  v_b4 uuid;
BEGIN
  SELECT id INTO v_hospital FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  IF v_hospital IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_yearly_replacement_budget_r2596 (hospital_user_id, fiscal_year, equipment_label, equipment_age_years, budget_bucket_kind, replacement_priority_kind, proposed_replacement_value_rupees, decision_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY26', 'GE Ventilator V200', 9.50, 'immediate', 'critical', 1850000, 'approved', 'founder@equipseva.in', 'decided', 'past EOL, board approved')
  RETURNING id INTO v_b1;

  INSERT INTO public.customer_yearly_replacement_budget_r2596 (hospital_user_id, fiscal_year, equipment_label, equipment_age_years, budget_bucket_kind, replacement_priority_kind, proposed_replacement_value_rupees, decision_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY26', 'Philips Patient Monitor MX700', 6.20, 'within_year', 'high', 425000, 'pending', 'founder@equipseva.in', 'in_review', 'CFO reviewing capex')
  RETURNING id INTO v_b2;

  INSERT INTO public.customer_yearly_replacement_budget_r2596 (hospital_user_id, fiscal_year, equipment_label, equipment_age_years, budget_bucket_kind, replacement_priority_kind, proposed_replacement_value_rupees, decision_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY27', 'Siemens X-ray Multix Fusion', 7.80, 'next_year', 'medium', 2250000, 'postponed', 'founder@equipseva.in', 'in_review', 'pushed to next FY')
  RETURNING id INTO v_b3;

  INSERT INTO public.customer_yearly_replacement_budget_r2596 (hospital_user_id, fiscal_year, equipment_label, equipment_age_years, budget_bucket_kind, replacement_priority_kind, proposed_replacement_value_rupees, decision_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY28', 'Dental Chair Unit A1', 4.10, 'within_3_years', 'low', 180000, 'rejected', 'founder@equipseva.in', 'dropped', 'still serviceable')
  RETURNING id INTO v_b4;

  INSERT INTO public.replacement_proposal_log_r2596 (budget_id, proposal_kind, summary_md, owner_email, status, notes) VALUES
    (v_b1, 'new_purchase', '## New ventilator purchase\nAMC + new unit, GE quote secured.', 'founder@equipseva.in', 'in_progress', 'PO drafted'),
    (v_b1, 'trade_in', '## Trade-in old V200\nSalvage value Rs 220000 estimated.', 'founder@equipseva.in', 'open', 'awaiting buyer quote'),
    (v_b2, 'amc_replacement', '## AMC swap MX700\nReplace under existing AMC ladder.', 'founder@equipseva.in', 'open', 'pending CFO sign-off'),
    (v_b3, 'upgrade_swap', '## Upgrade to Multix Impact', 'founder@equipseva.in', 'open', 'wait for FY27 budget'),
    (v_b4, 'sale_buyback', '## Sale + buyback option', 'founder@equipseva.in', 'dropped', 'declined by hospital');
END
$seed$;

-- list_yearly_budget_r2596
CREATE OR REPLACE FUNCTION public.list_yearly_budget_r2596()
RETURNS TABLE(id uuid, hospital_user_id uuid, fiscal_year text, equipment_label text, equipment_age_years numeric, budget_bucket_kind text, replacement_priority_kind text, proposed_replacement_value_rupees bigint, decision_kind text, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.hospital_user_id, b.fiscal_year, b.equipment_label, b.equipment_age_years,
         b.budget_bucket_kind, b.replacement_priority_kind, b.proposed_replacement_value_rupees,
         b.decision_kind, b.owner_email, b.status, b.notes, b.created_at
  FROM public.customer_yearly_replacement_budget_r2596 b
  ORDER BY b.created_at DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_yearly_budget_r2596() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_yearly_budget_r2596() TO authenticated;

-- list_proposal_log_r2596
CREATE OR REPLACE FUNCTION public.list_proposal_log_r2596()
RETURNS TABLE(id uuid, budget_id uuid, proposed_at timestamptz, proposal_kind text, summary_md text, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.budget_id, p.proposed_at, p.proposal_kind, p.summary_md, p.owner_email, p.status, p.notes, p.created_at
  FROM public.replacement_proposal_log_r2596 p
  ORDER BY p.proposed_at DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_proposal_log_r2596() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_proposal_log_r2596() TO authenticated;

-- top_priority_focus_r2596
CREATE OR REPLACE FUNCTION public.top_priority_focus_r2596()
RETURNS TABLE(replacement_priority_kind text, n bigint, total_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.replacement_priority_kind,
         COUNT(*)::bigint,
         COALESCE(SUM(b.proposed_replacement_value_rupees), 0)::bigint
  FROM public.customer_yearly_replacement_budget_r2596 b
  GROUP BY b.replacement_priority_kind
  ORDER BY 3 DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_priority_focus_r2596() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_priority_focus_r2596() TO authenticated;

-- budget_bucket_distribution_r2596
CREATE OR REPLACE FUNCTION public.budget_bucket_distribution_r2596()
RETURNS TABLE(budget_bucket_kind text, n bigint, total_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.budget_bucket_kind,
         COUNT(*)::bigint,
         COALESCE(SUM(b.proposed_replacement_value_rupees), 0)::bigint
  FROM public.customer_yearly_replacement_budget_r2596 b
  GROUP BY b.budget_bucket_kind
  ORDER BY 2 DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.budget_bucket_distribution_r2596() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_bucket_distribution_r2596() TO authenticated;

-- decision_kind_summary_r2596
CREATE OR REPLACE FUNCTION public.decision_kind_summary_r2596()
RETURNS TABLE(decision_kind text, n bigint, total_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.decision_kind,
         COUNT(*)::bigint,
         COALESCE(SUM(b.proposed_replacement_value_rupees), 0)::bigint
  FROM public.customer_yearly_replacement_budget_r2596 b
  GROUP BY b.decision_kind
  ORDER BY 2 DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.decision_kind_summary_r2596() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_kind_summary_r2596() TO authenticated;

-- monthly_proposal_trend_r2596
CREATE OR REPLACE FUNCTION public.monthly_proposal_trend_r2596()
RETURNS TABLE(month_label text, n bigint, open_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', p.proposed_at), 'YYYY-MM'),
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.status = 'open')::bigint
  FROM public.replacement_proposal_log_r2596 p
  GROUP BY 1
  ORDER BY 1 DESC NULLS LAST
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_proposal_trend_r2596() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_proposal_trend_r2596() TO authenticated;

-- total_replacement_value_summary_r2596
CREATE OR REPLACE FUNCTION public.total_replacement_value_summary_r2596()
RETURNS TABLE(fiscal_year text, total_value_rupees bigint, equipment_count bigint, avg_age_years numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.fiscal_year,
         COALESCE(SUM(b.proposed_replacement_value_rupees), 0)::bigint,
         COUNT(*)::bigint,
         ROUND(AVG(b.equipment_age_years)::numeric, 2)
  FROM public.customer_yearly_replacement_budget_r2596 b
  GROUP BY b.fiscal_year
  ORDER BY 1 ASC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.total_replacement_value_summary_r2596() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_replacement_value_summary_r2596() TO authenticated;
