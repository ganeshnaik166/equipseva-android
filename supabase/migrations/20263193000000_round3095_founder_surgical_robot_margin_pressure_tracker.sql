-- Round 3095: Founder Quarterly Strategic Engineer-Hospital Surgical-Robot Service Contract Margin Pressure Tracker
-- Tracks YoY margin compression on multi-year surgical robot service contracts across hospitals.

BEGIN;

-- ============================================================
-- TABLE 1: surgical_robot_service_contracts_r3095
-- One row per (robot_model x hospital x contract year)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.surgical_robot_service_contracts_r3095 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_code            text NOT NULL UNIQUE,
  hospital_name            text NOT NULL,
  hospital_city            text NOT NULL,
  robot_model              text NOT NULL CHECK (robot_model IN (
                              'da_vinci_xi','da_vinci_x','versius_cmr','hugo_medtronic',
                              'mako_stryker','rosa_zimmer','mantra_ssi','revo_meerecompany')),
  robot_oem                text NOT NULL CHECK (robot_oem IN (
                              'intuitive_surgical','cmr_surgical','medtronic','stryker',
                              'zimmer_biomet','ssi_mantra','meerecompany')),
  contract_year            int NOT NULL CHECK (contract_year BETWEEN 2022 AND 2030),
  contract_tier            text NOT NULL CHECK (contract_tier IN ('platinum','gold','silver','bronze')),
  annual_contract_value_rupees numeric(14,2) NOT NULL CHECK (annual_contract_value_rupees BETWEEN 1000000 AND 200000000),
  parts_cost_rupees        numeric(14,2) NOT NULL CHECK (parts_cost_rupees >= 0),
  labor_hours_logged       numeric(10,2) NOT NULL CHECK (labor_hours_logged BETWEEN 0 AND 20000),
  labor_cost_rupees        numeric(14,2) NOT NULL CHECK (labor_cost_rupees >= 0),
  oem_royalty_rupees       numeric(14,2) NOT NULL CHECK (oem_royalty_rupees >= 0),
  logistics_cost_rupees    numeric(14,2) NOT NULL CHECK (logistics_cost_rupees >= 0),
  gross_margin_rupees      numeric(14,2) NOT NULL,
  gross_margin_pct         numeric(6,2) NOT NULL CHECK (gross_margin_pct BETWEEN -100 AND 100),
  yoy_margin_delta_pct     numeric(6,2) NOT NULL CHECK (yoy_margin_delta_pct BETWEEN -100 AND 100),
  renewal_risk             text NOT NULL CHECK (renewal_risk IN ('low','medium','high','critical')),
  renewal_due_on           date NOT NULL,
  lead_engineer_id         uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  status                   text NOT NULL CHECK (status IN ('active','at_risk','escalated','renegotiating','renewed','lost')),
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_robot_contracts_r3095_status ON public.surgical_robot_service_contracts_r3095(status);
CREATE INDEX IF NOT EXISTS idx_robot_contracts_r3095_renewal ON public.surgical_robot_service_contracts_r3095(renewal_due_on);
CREATE INDEX IF NOT EXISTS idx_robot_contracts_r3095_oem ON public.surgical_robot_service_contracts_r3095(robot_oem);

ALTER TABLE public.surgical_robot_service_contracts_r3095 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- TABLE 2: surgical_robot_margin_pressure_events_r3095
-- Monthly cost-pressure events (parts inflation, OEM royalty hike, engineer overrun)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.surgical_robot_margin_pressure_events_r3095 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id              uuid NOT NULL REFERENCES public.surgical_robot_service_contracts_r3095(id) ON DELETE CASCADE,
  event_month              date NOT NULL,
  event_type               text NOT NULL CHECK (event_type IN (
                              'parts_price_hike','oem_royalty_increase','labor_overrun',
                              'logistics_surge','warranty_claim_denial','customs_duty_change',
                              'forex_inr_depreciation','pricing_lever_applied')),
  pressure_rupees          numeric(14,2) NOT NULL,
  pressure_severity        text NOT NULL CHECK (pressure_severity IN ('low','medium','high','critical')),
  pricing_lever            text NOT NULL CHECK (pricing_lever IN (
                              'pass_through','absorb','renegotiate','escalate_to_oem',
                              'substitute_part','reduce_scope','tier_upgrade_offer','none')),
  recovered_rupees         numeric(14,2) NOT NULL DEFAULT 0 CHECK (recovered_rupees >= 0),
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_robot_events_r3095_contract ON public.surgical_robot_margin_pressure_events_r3095(contract_id);
CREATE INDEX IF NOT EXISTS idx_robot_events_r3095_month ON public.surgical_robot_margin_pressure_events_r3095(event_month);

ALTER TABLE public.surgical_robot_margin_pressure_events_r3095 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.surgical_robot_service_contracts_r3095 (
  contract_code, hospital_name, hospital_city, robot_model, robot_oem,
  contract_year, contract_tier, annual_contract_value_rupees, parts_cost_rupees,
  labor_hours_logged, labor_cost_rupees, oem_royalty_rupees, logistics_cost_rupees,
  gross_margin_rupees, gross_margin_pct, yoy_margin_delta_pct, renewal_risk,
  renewal_due_on, status, notes
) VALUES
  ('SRC-APOL-DVX-2026','Apollo Hospitals Chennai','Chennai','da_vinci_xi','intuitive_surgical',
   2026,'platinum',45000000,18500000,3200,4800000,9000000,1200000,
   11500000,25.56,-6.20,'high','2026-12-31','at_risk','Parts cost up 18% YoY; OEM royalty renegotiated upward'),
  ('SRC-MEDA-VRS-2026','Medanta Gurugram','Gurugram','versius_cmr','cmr_surgical',
   2026,'gold',28000000,9800000,2400,3600000,4200000,800000,
   9600000,34.29,-3.10,'medium','2027-03-31','active','Stable; CMR royalty fixed for 3 years'),
  ('SRC-FORT-MAKO-2026','Fortis Bangalore','Bengaluru','mako_stryker','stryker',
   2026,'gold',32000000,12400000,2800,4200000,5600000,950000,
   8850000,27.66,-8.40,'high','2026-09-30','escalated','Labor overrun on 4 emergency call-outs'),
  ('SRC-MAX-HUGO-2026','Max Saket Delhi','New Delhi','hugo_medtronic','medtronic',
   2026,'silver',18500000,7200000,1800,2700000,2800000,520000,
   5280000,28.54,-4.80,'medium','2027-06-30','renegotiating','Medtronic offered 5% royalty cut for 5yr commit'),
  ('SRC-AIIMS-MANT-2026','AIIMS Delhi','New Delhi','mantra_ssi','ssi_mantra',
   2026,'platinum',38000000,11200000,3600,5400000,1900000,650000,
   18850000,49.61,2.10,'low','2027-12-31','active','Indigenous Mantra; lowest royalty + customs exempt'),
  ('SRC-KOKILA-ROSA-2026','Kokilaben Mumbai','Mumbai','rosa_zimmer','zimmer_biomet',
   2026,'silver',22000000,9100000,2100,3150000,3300000,720000,
   5730000,26.05,-7.90,'high','2026-10-31','at_risk','Forex hit Q2; logistics 22% over budget'),
  ('SRC-MANIP-DVX-2026','Manipal Bengaluru','Bengaluru','da_vinci_x','intuitive_surgical',
   2026,'bronze',12500000,5400000,1400,2100000,2500000,420000,
   2080000,16.64,-11.20,'critical','2026-08-15','renegotiating','Margin collapse; pricing lever review urgent'),
  ('SRC-RUBY-VRS-2026','Ruby Hall Pune','Pune','versius_cmr','cmr_surgical',
   2026,'silver',16500000,5800000,1600,2400000,2475000,510000,
   5315000,32.21,-1.50,'low','2027-09-30','active','CMR support strong; renewal likely'),
  ('SRC-APOL-DVX-2025','Apollo Hospitals Chennai','Chennai','da_vinci_xi','intuitive_surgical',
   2025,'platinum',42000000,15600000,3100,4500000,8400000,1050000,
   12450000,29.64,-1.80,'medium','2025-12-31','renewed','Prior year baseline'),
  ('SRC-NARAY-REVO-2026','Narayana Bengaluru','Bengaluru','revo_meerecompany','meerecompany',
   2026,'bronze',9800000,4200000,1100,1650000,1960000,380000,
   1610000,16.43,-9.60,'critical','2026-07-31','escalated','Korean OEM parts ETA 12 weeks; Revo program at risk');

INSERT INTO public.surgical_robot_margin_pressure_events_r3095 (
  contract_id, event_month, event_type, pressure_rupees, pressure_severity,
  pricing_lever, recovered_rupees, notes
)
SELECT id, DATE '2026-04-01','parts_price_hike',1850000,'high','renegotiate',420000,'Intuitive raised EndoWrist pricing 14%'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-APOL-DVX-2026'
UNION ALL SELECT id, DATE '2026-05-01','oem_royalty_increase',2100000,'critical','escalate_to_oem',0,'OEM royalty hiked mid-cycle'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-APOL-DVX-2026'
UNION ALL SELECT id, DATE '2026-04-01','labor_overrun',680000,'medium','absorb',0,'Two emergency dispatches Bengaluru'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-FORT-MAKO-2026'
UNION ALL SELECT id, DATE '2026-05-01','forex_inr_depreciation',520000,'medium','pass_through',310000,'INR slipped vs USD; parts import hit'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-KOKILA-ROSA-2026'
UNION ALL SELECT id, DATE '2026-03-01','logistics_surge',290000,'low','absorb',0,'Sea-freight surcharge'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-KOKILA-ROSA-2026'
UNION ALL SELECT id, DATE '2026-04-01','pricing_lever_applied',0,'low','tier_upgrade_offer',850000,'Pitched platinum upgrade with caps'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-MAX-HUGO-2026'
UNION ALL SELECT id, DATE '2026-05-01','warranty_claim_denial',940000,'high','escalate_to_oem',0,'Intuitive denied 3 warranty claims'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-MANIP-DVX-2026'
UNION ALL SELECT id, DATE '2026-06-01','customs_duty_change',610000,'high','pass_through',0,'Korean parts duty reclassified'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-NARAY-REVO-2026'
UNION ALL SELECT id, DATE '2026-05-01','parts_price_hike',330000,'low','substitute_part',180000,'Switched to indigenous bearing'
  FROM public.surgical_robot_service_contracts_r3095 WHERE contract_code='SRC-AIIMS-MANT-2026';

-- ============================================================
-- RPC 1: status summary
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_status_summary()
RETURNS TABLE(
  status text,
  contract_count bigint,
  total_acv_rupees numeric,
  avg_margin_pct numeric,
  avg_yoy_delta_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status,
         COUNT(*)::bigint,
         COALESCE(SUM(c.annual_contract_value_rupees),0)::numeric,
         ROUND(AVG(c.gross_margin_pct)::numeric, 2),
         ROUND(AVG(c.yoy_margin_delta_pct)::numeric, 2)
  FROM public.surgical_robot_service_contracts_r3095 c
  GROUP BY c.status
  ORDER BY 2 DESC;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_status_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_status_summary() TO authenticated;

-- ============================================================
-- RPC 2: OEM vendor breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_oem_breakdown()
RETURNS TABLE(
  robot_oem text,
  contract_count bigint,
  total_royalty_rupees numeric,
  total_parts_cost_rupees numeric,
  avg_margin_pct numeric,
  critical_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.robot_oem,
         COUNT(*)::bigint,
         COALESCE(SUM(c.oem_royalty_rupees),0)::numeric,
         COALESCE(SUM(c.parts_cost_rupees),0)::numeric,
         ROUND(AVG(c.gross_margin_pct)::numeric, 2),
         COUNT(*) FILTER (WHERE c.renewal_risk = 'critical')::bigint
  FROM public.surgical_robot_service_contracts_r3095 c
  GROUP BY c.robot_oem
  ORDER BY 3 DESC;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_oem_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_oem_breakdown() TO authenticated;

-- ============================================================
-- RPC 3: margin trend by month
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_monthly_pressure_trend()
RETURNS TABLE(
  event_month date,
  total_pressure_rupees numeric,
  total_recovered_rupees numeric,
  net_pressure_rupees numeric,
  event_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_month,
         COALESCE(SUM(e.pressure_rupees),0)::numeric,
         COALESCE(SUM(e.recovered_rupees),0)::numeric,
         COALESCE(SUM(e.pressure_rupees - e.recovered_rupees),0)::numeric,
         COUNT(*)::bigint
  FROM public.surgical_robot_margin_pressure_events_r3095 e
  GROUP BY e.event_month
  ORDER BY e.event_month;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_monthly_pressure_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_monthly_pressure_trend() TO authenticated;

-- ============================================================
-- RPC 4: at-risk hotlist
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_at_risk_hotlist()
RETURNS TABLE(
  contract_code text,
  hospital_name text,
  robot_model text,
  acv_rupees numeric,
  gross_margin_pct numeric,
  yoy_margin_delta_pct numeric,
  renewal_due_on date,
  renewal_risk text,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.contract_code, c.hospital_name, c.robot_model,
         c.annual_contract_value_rupees, c.gross_margin_pct,
         c.yoy_margin_delta_pct, c.renewal_due_on, c.renewal_risk, c.status
  FROM public.surgical_robot_service_contracts_r3095 c
  WHERE c.renewal_risk IN ('high','critical') OR c.status IN ('at_risk','escalated','renegotiating')
  ORDER BY
    CASE c.renewal_risk WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    c.renewal_due_on;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_at_risk_hotlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_at_risk_hotlist() TO authenticated;

-- ============================================================
-- RPC 5: pricing-lever effectiveness
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_lever_effectiveness()
RETURNS TABLE(
  pricing_lever text,
  event_count bigint,
  total_pressure_rupees numeric,
  total_recovered_rupees numeric,
  recovery_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.pricing_lever,
         COUNT(*)::bigint,
         COALESCE(SUM(e.pressure_rupees),0)::numeric,
         COALESCE(SUM(e.recovered_rupees),0)::numeric,
         CASE WHEN COALESCE(SUM(e.pressure_rupees),0) > 0
              THEN ROUND((SUM(e.recovered_rupees) / NULLIF(SUM(e.pressure_rupees),0) * 100)::numeric, 2)
              ELSE 0 END
  FROM public.surgical_robot_margin_pressure_events_r3095 e
  GROUP BY e.pricing_lever
  ORDER BY 4 DESC;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_lever_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_lever_effectiveness() TO authenticated;

-- ============================================================
-- RPC 6: robot model scorecard
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_robot_model_scorecard()
RETURNS TABLE(
  robot_model text,
  contract_count bigint,
  total_acv_rupees numeric,
  avg_labor_hours numeric,
  avg_margin_pct numeric,
  worst_yoy_delta_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.robot_model,
         COUNT(*)::bigint,
         COALESCE(SUM(c.annual_contract_value_rupees),0)::numeric,
         ROUND(AVG(c.labor_hours_logged)::numeric, 1),
         ROUND(AVG(c.gross_margin_pct)::numeric, 2),
         MIN(c.yoy_margin_delta_pct)::numeric
  FROM public.surgical_robot_service_contracts_r3095 c
  GROUP BY c.robot_model
  ORDER BY 3 DESC;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_robot_model_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_robot_model_scorecard() TO authenticated;

-- ============================================================
-- RPC 7: upcoming renewal queue (next 180 days)
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_renewal_queue()
RETURNS TABLE(
  contract_code text,
  hospital_name text,
  hospital_city text,
  robot_model text,
  renewal_due_on date,
  days_to_renewal int,
  renewal_risk text,
  acv_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.contract_code, c.hospital_name, c.hospital_city, c.robot_model,
         c.renewal_due_on,
         (c.renewal_due_on - CURRENT_DATE)::int,
         c.renewal_risk,
         c.annual_contract_value_rupees
  FROM public.surgical_robot_service_contracts_r3095 c
  WHERE c.renewal_due_on BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '540 days'
  ORDER BY c.renewal_due_on;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_renewal_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_renewal_queue() TO authenticated;

-- ============================================================
-- RPC 8: event severity breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_event_severity_breakdown()
RETURNS TABLE(
  event_type text,
  pressure_severity text,
  event_count bigint,
  total_pressure_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_type, e.pressure_severity,
         COUNT(*)::bigint,
         COALESCE(SUM(e.pressure_rupees),0)::numeric
  FROM public.surgical_robot_margin_pressure_events_r3095 e
  GROUP BY e.event_type, e.pressure_severity
  ORDER BY 4 DESC;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_event_severity_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_event_severity_breakdown() TO authenticated;

-- ============================================================
-- RPC 9: city-level margin pressure
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r3095_city_pressure()
RETURNS TABLE(
  hospital_city text,
  contract_count bigint,
  total_acv_rupees numeric,
  avg_margin_pct numeric,
  net_pressure_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.hospital_city,
         COUNT(DISTINCT c.id)::bigint,
         COALESCE(SUM(c.annual_contract_value_rupees),0)::numeric,
         ROUND(AVG(c.gross_margin_pct)::numeric, 2),
         COALESCE(SUM(e.pressure_rupees - e.recovered_rupees),0)::numeric
  FROM public.surgical_robot_service_contracts_r3095 c
  LEFT JOIN public.surgical_robot_margin_pressure_events_r3095 e ON e.contract_id = c.id
  GROUP BY c.hospital_city
  ORDER BY 5 DESC;
END$$;

REVOKE EXECUTE ON FUNCTION public.rpc_r3095_city_pressure() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3095_city_pressure() TO authenticated;

COMMIT;
