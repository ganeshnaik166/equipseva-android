-- Round 2472: customer-equipment-end-of-life-replacement-pipeline
-- Equipment × age × replacement urgency × replacement cost × upsell opportunity × decision date.

BEGIN;

CREATE TABLE IF NOT EXISTS public.equipment_end_of_life_r2472 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_model text,
  age_years numeric NOT NULL DEFAULT 0 CHECK (age_years >= 0),
  mfg_eol_date date,
  replacement_urgency text NOT NULL DEFAULT 'low' CHECK (replacement_urgency IN ('low','medium','high','critical')),
  replacement_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (replacement_cost_rupees >= 0),
  upsell_opportunity_rupees bigint NOT NULL DEFAULT 0 CHECK (upsell_opportunity_rupees >= 0),
  decision_due_at timestamptz,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','quoted','decided','replaced','dropped')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eol_r2472_hospital ON public.equipment_end_of_life_r2472(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_eol_r2472_urgency ON public.equipment_end_of_life_r2472(replacement_urgency);
CREATE INDEX IF NOT EXISTS idx_eol_r2472_status ON public.equipment_end_of_life_r2472(status);
CREATE INDEX IF NOT EXISTS idx_eol_r2472_decision_due ON public.equipment_end_of_life_r2472(decision_due_at);

CREATE TABLE IF NOT EXISTS public.equipment_replacement_quotes_r2472 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  eol_id uuid NOT NULL REFERENCES public.equipment_end_of_life_r2472(id) ON DELETE CASCADE,
  quote_external_ref text,
  vendor_name text NOT NULL,
  quote_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (quote_amount_rupees >= 0),
  valid_until date,
  decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('accept','reject','negotiate','pending')),
  decided_at timestamptz,
  decision_owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eol_quotes_r2472_eol ON public.equipment_replacement_quotes_r2472(eol_id);
CREATE INDEX IF NOT EXISTS idx_eol_quotes_r2472_decision ON public.equipment_replacement_quotes_r2472(decision);
CREATE INDEX IF NOT EXISTS idx_eol_quotes_r2472_vendor ON public.equipment_replacement_quotes_r2472(vendor_name);

ALTER TABLE public.equipment_end_of_life_r2472 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_replacement_quotes_r2472 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.equipment_end_of_life_r2472;
CREATE POLICY founder_all ON public.equipment_end_of_life_r2472
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.equipment_replacement_quotes_r2472;
CREATE POLICY founder_all ON public.equipment_replacement_quotes_r2472
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_e1 uuid;
  v_e2 uuid;
  v_e3 uuid;
  v_e4 uuid;
  v_e5 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at ASC LIMIT 1;

  IF v_h1 IS NOT NULL THEN
    INSERT INTO public.equipment_end_of_life_r2472(hospital_user_id, equipment_label, equipment_model, age_years, mfg_eol_date, replacement_urgency, replacement_cost_rupees, upsell_opportunity_rupees, decision_due_at, status, owner_email, notes)
    VALUES (v_h1, 'OT Ventilator 1', 'Drager Evita V300', 11.5, '2025-12-31', 'critical', 2200000, 600000, '2026-07-15 18:00:00'::timestamptz, 'quoted', 'founder@equipseva.com', 'Past mfg EOL, spares scarce')
    RETURNING id INTO v_e1;

    INSERT INTO public.equipment_end_of_life_r2472(hospital_user_id, equipment_label, equipment_model, age_years, mfg_eol_date, replacement_urgency, replacement_cost_rupees, upsell_opportunity_rupees, decision_due_at, status, owner_email, notes)
    VALUES (v_h1, 'ICU Monitor Bay 3', 'Mindray uMEC12', 7.2, '2027-06-30', 'high', 450000, 120000, '2026-09-30 18:00:00'::timestamptz, 'monitoring', 'biomed@equipseva.com', 'Battery degraded, screen flicker')
    RETURNING id INTO v_e2;
  END IF;

  IF v_h2 IS NOT NULL THEN
    INSERT INTO public.equipment_end_of_life_r2472(hospital_user_id, equipment_label, equipment_model, age_years, mfg_eol_date, replacement_urgency, replacement_cost_rupees, upsell_opportunity_rupees, decision_due_at, status, owner_email, notes)
    VALUES (v_h2, 'Anesthesia Machine OT2', 'GE Aisys CS2', 9.0, '2026-03-31', 'high', 3500000, 900000, '2026-08-01 18:00:00'::timestamptz, 'decided', 'founder@equipseva.com', 'PO under negotiation')
    RETURNING id INTO v_e3;

    INSERT INTO public.equipment_end_of_life_r2472(hospital_user_id, equipment_label, equipment_model, age_years, mfg_eol_date, replacement_urgency, replacement_cost_rupees, upsell_opportunity_rupees, decision_due_at, status, owner_email, notes)
    VALUES (v_h2, 'Portable X-Ray', 'Siemens Mobilett Mira', 6.5, '2028-01-31', 'medium', 1800000, 250000, '2027-01-15 18:00:00'::timestamptz, 'monitoring', 'radiology@equipseva.com', 'Working but slow boot')
    RETURNING id INTO v_e4;
  END IF;

  IF v_h3 IS NOT NULL THEN
    INSERT INTO public.equipment_end_of_life_r2472(hospital_user_id, equipment_label, equipment_model, age_years, mfg_eol_date, replacement_urgency, replacement_cost_rupees, upsell_opportunity_rupees, decision_due_at, status, owner_email, notes)
    VALUES (v_h3, 'Defibrillator ER', 'Philips HeartStart MRx', 12.0, '2024-12-31', 'critical', 750000, 180000, '2026-07-05 18:00:00'::timestamptz, 'replaced', 'er@equipseva.com', 'Replaced last week')
    RETURNING id INTO v_e5;
  END IF;

  IF v_e1 IS NOT NULL THEN
    INSERT INTO public.equipment_replacement_quotes_r2472(eol_id, quote_external_ref, vendor_name, quote_amount_rupees, valid_until, decision, decided_at, decision_owner_email, notes)
    VALUES (v_e1, 'Q-DRG-2026-117', 'Drager India', 2100000, '2026-07-31', 'negotiate', NULL, 'founder@equipseva.com', 'Asking 5% discount + AMC bundle');
    INSERT INTO public.equipment_replacement_quotes_r2472(eol_id, quote_external_ref, vendor_name, quote_amount_rupees, valid_until, decision, notes)
    VALUES (v_e1, 'Q-MND-2026-44', 'Mindray', 1850000, '2026-08-15', 'pending', 'Lower spec, evaluating');
  END IF;

  IF v_e3 IS NOT NULL THEN
    INSERT INTO public.equipment_replacement_quotes_r2472(eol_id, quote_external_ref, vendor_name, quote_amount_rupees, valid_until, decision, decided_at, decision_owner_email, notes)
    VALUES (v_e3, 'Q-GE-2026-201', 'GE Healthcare', 3400000, '2026-08-31', 'accept', '2026-06-18 14:00:00'::timestamptz, 'founder@equipseva.com', 'Final PO terms agreed');
    INSERT INTO public.equipment_replacement_quotes_r2472(eol_id, quote_external_ref, vendor_name, quote_amount_rupees, valid_until, decision, decided_at, decision_owner_email, notes)
    VALUES (v_e3, 'Q-DRG-2026-118', 'Drager India', 3650000, '2026-08-15', 'reject', '2026-06-15 11:00:00'::timestamptz, 'founder@equipseva.com', 'Too expensive vs GE');
  END IF;

  IF v_e5 IS NOT NULL THEN
    INSERT INTO public.equipment_replacement_quotes_r2472(eol_id, quote_external_ref, vendor_name, quote_amount_rupees, valid_until, decision, decided_at, decision_owner_email, notes)
    VALUES (v_e5, 'Q-PHL-2026-77', 'Philips', 720000, '2026-07-15', 'accept', '2026-06-10 09:00:00'::timestamptz, 'er@equipseva.com', 'Replaced unit installed');
  END IF;
END $$;

-- RPC 1: list_eol_r2472
CREATE OR REPLACE FUNCTION public.list_eol_r2472()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_label text,
  equipment_model text,
  age_years numeric,
  mfg_eol_date date,
  replacement_urgency text,
  replacement_cost_rupees bigint,
  upsell_opportunity_rupees bigint,
  decision_due_at timestamptz,
  status text,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_user_id, p.email, e.equipment_label, e.equipment_model,
         e.age_years, e.mfg_eol_date, e.replacement_urgency,
         e.replacement_cost_rupees, e.upsell_opportunity_rupees,
         e.decision_due_at, e.status, e.owner_email, e.notes, e.created_at
  FROM public.equipment_end_of_life_r2472 e
  LEFT JOIN public.profiles p ON p.id = e.hospital_user_id
  ORDER BY
    CASE e.replacement_urgency
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END,
    e.decision_due_at ASC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_eol_r2472() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_eol_r2472() TO authenticated;

-- RPC 2: list_quotes_r2472
CREATE OR REPLACE FUNCTION public.list_quotes_r2472()
RETURNS TABLE(
  id uuid,
  eol_id uuid,
  equipment_label text,
  hospital_email text,
  quote_external_ref text,
  vendor_name text,
  quote_amount_rupees bigint,
  valid_until date,
  decision text,
  decided_at timestamptz,
  decision_owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.eol_id, e.equipment_label, p.email,
         q.quote_external_ref, q.vendor_name, q.quote_amount_rupees,
         q.valid_until, q.decision, q.decided_at, q.decision_owner_email,
         q.notes, q.created_at
  FROM public.equipment_replacement_quotes_r2472 q
  LEFT JOIN public.equipment_end_of_life_r2472 e ON e.id = q.eol_id
  LEFT JOIN public.profiles p ON p.id = e.hospital_user_id
  ORDER BY q.created_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_quotes_r2472() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_quotes_r2472() TO authenticated;

-- RPC 3: top_urgency_focus_r2472
CREATE OR REPLACE FUNCTION public.top_urgency_focus_r2472()
RETURNS TABLE(
  id uuid,
  hospital_email text,
  equipment_label text,
  replacement_urgency text,
  age_years numeric,
  mfg_eol_date date,
  decision_due_at timestamptz,
  replacement_cost_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, p.email, e.equipment_label, e.replacement_urgency,
         e.age_years, e.mfg_eol_date, e.decision_due_at,
         e.replacement_cost_rupees, e.status
  FROM public.equipment_end_of_life_r2472 e
  LEFT JOIN public.profiles p ON p.id = e.hospital_user_id
  WHERE e.status IN ('monitoring','quoted','decided')
    AND e.replacement_urgency IN ('critical','high')
  ORDER BY
    CASE e.replacement_urgency WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    e.decision_due_at ASC NULLS LAST
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_urgency_focus_r2472() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_urgency_focus_r2472() TO authenticated;

-- RPC 4: top_upsell_opportunities_r2472
CREATE OR REPLACE FUNCTION public.top_upsell_opportunities_r2472()
RETURNS TABLE(
  id uuid,
  hospital_email text,
  equipment_label text,
  upsell_opportunity_rupees bigint,
  replacement_cost_rupees bigint,
  replacement_urgency text,
  decision_due_at timestamptz,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, p.email, e.equipment_label,
         e.upsell_opportunity_rupees, e.replacement_cost_rupees,
         e.replacement_urgency, e.decision_due_at, e.status
  FROM public.equipment_end_of_life_r2472 e
  LEFT JOIN public.profiles p ON p.id = e.hospital_user_id
  WHERE e.status NOT IN ('dropped','replaced')
  ORDER BY e.upsell_opportunity_rupees DESC NULLS LAST
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_upsell_opportunities_r2472() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_upsell_opportunities_r2472() TO authenticated;

-- RPC 5: monthly_replacement_pipeline_r2472
CREATE OR REPLACE FUNCTION public.monthly_replacement_pipeline_r2472()
RETURNS TABLE(
  decision_month text,
  pipeline_count int,
  total_replacement_cost_rupees bigint,
  total_upsell_opportunity_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', e.decision_due_at), 'YYYY-MM') AS decision_month,
         COUNT(*)::int,
         COALESCE(SUM(e.replacement_cost_rupees), 0)::bigint,
         COALESCE(SUM(e.upsell_opportunity_rupees), 0)::bigint
  FROM public.equipment_end_of_life_r2472 e
  WHERE e.decision_due_at IS NOT NULL
    AND e.status NOT IN ('dropped','replaced')
  GROUP BY date_trunc('month', e.decision_due_at)
  ORDER BY date_trunc('month', e.decision_due_at) ASC
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_replacement_pipeline_r2472() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_replacement_pipeline_r2472() TO authenticated;

-- RPC 6: vendor_quote_summary_r2472
CREATE OR REPLACE FUNCTION public.vendor_quote_summary_r2472()
RETURNS TABLE(
  vendor_name text,
  quote_count int,
  accepted_count int,
  rejected_count int,
  total_accepted_rupees bigint,
  avg_quote_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.vendor_name,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE q.decision='accept')::int,
         COUNT(*) FILTER (WHERE q.decision='reject')::int,
         COALESCE(SUM(q.quote_amount_rupees) FILTER (WHERE q.decision='accept'), 0)::bigint,
         ROUND(AVG(q.quote_amount_rupees)::numeric, 2)
  FROM public.equipment_replacement_quotes_r2472 q
  GROUP BY q.vendor_name
  ORDER BY COUNT(*) FILTER (WHERE q.decision='accept') DESC, COUNT(*) DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.vendor_quote_summary_r2472() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vendor_quote_summary_r2472() TO authenticated;

-- RPC 7: decision_funnel_r2472
CREATE OR REPLACE FUNCTION public.decision_funnel_r2472()
RETURNS TABLE(
  status text,
  eol_count int,
  pct numeric,
  total_replacement_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.equipment_end_of_life_r2472;
  RETURN QUERY
  SELECT e.status,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total,0), 2),
         COALESCE(SUM(e.replacement_cost_rupees), 0)::bigint
  FROM public.equipment_end_of_life_r2472 e
  GROUP BY e.status
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.decision_funnel_r2472() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_funnel_r2472() TO authenticated;

