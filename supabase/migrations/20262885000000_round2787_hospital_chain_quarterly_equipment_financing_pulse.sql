BEGIN;

-- ============================================================
-- Round 2787: Hospital Chain Quarterly Equipment Financing Pulse
-- ============================================================

CREATE TABLE IF NOT EXISTS hospital_chain_financing_deals_r2787 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  deal_code text NOT NULL UNIQUE,
  financing_kind text NOT NULL CHECK (financing_kind IN ('lease','loan','rental','revenue_share','hire_purchase')),
  equipment_category text NOT NULL,
  units integer NOT NULL CHECK (units > 0),
  ticket_size_rupees bigint NOT NULL CHECK (ticket_size_rupees > 0),
  term_months integer NOT NULL CHECK (term_months > 0),
  interest_rate_bps integer NOT NULL CHECK (interest_rate_bps >= 0),
  expected_close_date date NOT NULL,
  quarterly_revenue_rupees bigint NOT NULL CHECK (quarterly_revenue_rupees >= 0),
  renew_probability_bps integer NOT NULL CHECK (renew_probability_bps BETWEEN 0 AND 10000),
  stage text NOT NULL CHECK (stage IN ('pipeline','term_sheet','approved','funded','closed_lost','renewed')),
  quarter text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_financing_deals_r2787 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_financing_deals_r2787;
CREATE POLICY founder_all ON hospital_chain_financing_deals_r2787 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_financing_pulse_events_r2787 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES hospital_chain_financing_deals_r2787(id) ON DELETE CASCADE,
  event_kind text NOT NULL CHECK (event_kind IN ('inquiry','term_sheet_sent','approval','disbursal','renewal_signal','default_signal','prepayment')),
  event_at timestamptz NOT NULL DEFAULT now(),
  delta_rupees bigint NOT NULL DEFAULT 0,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_financing_pulse_events_r2787 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_financing_pulse_events_r2787;
CREATE POLICY founder_all ON hospital_chain_financing_pulse_events_r2787 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed deals
INSERT INTO hospital_chain_financing_deals_r2787 (chain_name, deal_code, financing_kind, equipment_category, units, ticket_size_rupees, term_months, interest_rate_bps, expected_close_date, quarterly_revenue_rupees, renew_probability_bps, stage, quarter) VALUES
('Apollo Group', 'APL-Q3-LEASE-01', 'lease', 'CT Scanner', 4, 38000000, 60, 1150, '2026-08-15'::date, 4800000, 8500, 'term_sheet', 'Q3-2026'),
('Fortis Healthcare', 'FRT-Q3-LOAN-02', 'loan', 'MRI 1.5T', 2, 52000000, 72, 1050, '2026-09-20'::date, 6200000, 7800, 'approved', 'Q3-2026'),
('Manipal Hospitals', 'MNP-Q3-RENT-03', 'rental', 'Ventilator', 40, 9200000, 24, 900, '2026-07-30'::date, 1850000, 9200, 'funded', 'Q3-2026'),
('Yashoda Hospitals', 'YSH-Q3-REVS-04', 'revenue_share', 'Cath Lab', 1, 28000000, 48, 0, '2026-08-05'::date, 3600000, 6500, 'pipeline', 'Q3-2026'),
('Care Hospitals', 'CRE-Q3-HP-05', 'hire_purchase', 'Ultrasound Premium', 12, 14400000, 36, 1300, '2026-09-10'::date, 1200000, 8800, 'term_sheet', 'Q3-2026'),
('KIMS Group', 'KMS-Q3-LEASE-06', 'lease', 'Linear Accelerator', 1, 88000000, 84, 1100, '2026-10-15'::date, 7500000, 7000, 'pipeline', 'Q3-2026'),
('Rainbow Childrens', 'RNB-Q3-LOAN-07', 'loan', 'NICU Bundle', 8, 18500000, 60, 1000, '2026-08-28'::date, 2200000, 8200, 'approved', 'Q3-2026');

INSERT INTO hospital_chain_financing_pulse_events_r2787 (deal_id, event_kind, event_at, delta_rupees, note)
SELECT id, 'inquiry'::text, now() - interval '30 days', 0, 'Initial inquiry via founder channel'
FROM hospital_chain_financing_deals_r2787 WHERE deal_code = 'APL-Q3-LEASE-01';

INSERT INTO hospital_chain_financing_pulse_events_r2787 (deal_id, event_kind, event_at, delta_rupees, note)
SELECT id, 'term_sheet_sent'::text, now() - interval '12 days', 38000000, 'Term sheet shared with CFO'
FROM hospital_chain_financing_deals_r2787 WHERE deal_code = 'FRT-Q3-LOAN-02';

INSERT INTO hospital_chain_financing_pulse_events_r2787 (deal_id, event_kind, event_at, delta_rupees, note)
SELECT id, 'disbursal'::text, now() - interval '4 days', 9200000, 'First tranche disbursed'
FROM hospital_chain_financing_deals_r2787 WHERE deal_code = 'MNP-Q3-RENT-03';

INSERT INTO hospital_chain_financing_pulse_events_r2787 (deal_id, event_kind, event_at, delta_rupees, note)
SELECT id, 'approval'::text, now() - interval '8 days', 18500000, 'Credit committee approved'
FROM hospital_chain_financing_deals_r2787 WHERE deal_code = 'RNB-Q3-LOAN-07';

INSERT INTO hospital_chain_financing_pulse_events_r2787 (deal_id, event_kind, event_at, delta_rupees, note)
SELECT id, 'renewal_signal'::text, now() - interval '2 days', 0, 'Chain hinted at expansion renewal'
FROM hospital_chain_financing_deals_r2787 WHERE deal_code = 'CRE-Q3-HP-05';

INSERT INTO hospital_chain_financing_pulse_events_r2787 (deal_id, event_kind, event_at, delta_rupees, note)
SELECT id, 'inquiry'::text, now() - interval '20 days', 0, 'Strategic conversation opened'
FROM hospital_chain_financing_deals_r2787 WHERE deal_code = 'KMS-Q3-LEASE-06';

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_hcfp_r2787_pipeline_summary();
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_pipeline_summary()
RETURNS TABLE(total_deals bigint, total_ticket_rupees bigint, weighted_revenue_rupees bigint, avg_renew_prob_bps numeric, funded_deals bigint, pipeline_deals bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    coalesce(sum(ticket_size_rupees),0)::bigint,
    coalesce(sum(quarterly_revenue_rupees * renew_probability_bps / 10000),0)::bigint,
    coalesce(avg(renew_probability_bps),0)::numeric,
    count(*) FILTER (WHERE stage = 'funded')::bigint,
    count(*) FILTER (WHERE stage = 'pipeline')::bigint
  FROM hospital_chain_financing_deals_r2787;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_pipeline_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_pipeline_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_hcfp_r2787_deals_by_chain();
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_deals_by_chain()
RETURNS TABLE(chain_name text, deal_count bigint, total_ticket_rupees bigint, total_quarterly_revenue_rupees bigint, avg_renew_bps numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.chain_name,
    count(*)::bigint,
    sum(d.ticket_size_rupees)::bigint,
    sum(d.quarterly_revenue_rupees)::bigint,
    avg(d.renew_probability_bps)::numeric
  FROM hospital_chain_financing_deals_r2787 d
  GROUP BY d.chain_name
  ORDER BY sum(d.ticket_size_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_deals_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_deals_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS founder_hcfp_r2787_deals_by_financing_kind();
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_deals_by_financing_kind()
RETURNS TABLE(financing_kind text, deal_count bigint, total_ticket_rupees bigint, avg_term_months numeric, avg_interest_bps numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.financing_kind,
    count(*)::bigint,
    sum(d.ticket_size_rupees)::bigint,
    avg(d.term_months)::numeric,
    avg(d.interest_rate_bps)::numeric
  FROM hospital_chain_financing_deals_r2787 d
  GROUP BY d.financing_kind
  ORDER BY sum(d.ticket_size_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_deals_by_financing_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_deals_by_financing_kind() TO authenticated;

DROP FUNCTION IF EXISTS founder_hcfp_r2787_closing_window();
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_closing_window()
RETURNS TABLE(deal_code text, chain_name text, expected_close_date date, days_to_close integer, ticket_size_rupees bigint, stage text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.deal_code,
    d.chain_name,
    d.expected_close_date,
    (d.expected_close_date - current_date)::integer,
    d.ticket_size_rupees,
    d.stage
  FROM hospital_chain_financing_deals_r2787 d
  WHERE d.stage NOT IN ('funded','closed_lost','renewed')
  ORDER BY d.expected_close_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_closing_window() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_closing_window() TO authenticated;

DROP FUNCTION IF EXISTS founder_hcfp_r2787_renew_probability_buckets();
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_renew_probability_buckets()
RETURNS TABLE(bucket text, deal_count bigint, expected_revenue_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN d.renew_probability_bps >= 8500 THEN 'A: 85-100'
      WHEN d.renew_probability_bps >= 7000 THEN 'B: 70-85'
      WHEN d.renew_probability_bps >= 5000 THEN 'C: 50-70'
      ELSE 'D: <50'
    END::text AS bucket,
    count(*)::bigint,
    sum(d.quarterly_revenue_rupees * d.renew_probability_bps / 10000)::bigint
  FROM hospital_chain_financing_deals_r2787 d
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_renew_probability_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_renew_probability_buckets() TO authenticated;

DROP FUNCTION IF EXISTS founder_hcfp_r2787_recent_events(integer);
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_recent_events(p_limit integer DEFAULT 25)
RETURNS TABLE(event_at timestamptz, deal_code text, chain_name text, event_kind text, delta_rupees bigint, note text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_at, d.deal_code, d.chain_name, e.event_kind, e.delta_rupees, e.note
  FROM hospital_chain_financing_pulse_events_r2787 e
  JOIN hospital_chain_financing_deals_r2787 d ON d.id = e.deal_id
  ORDER BY e.event_at DESC
  LIMIT greatest(coalesce(p_limit,25),1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_recent_events(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_recent_events(integer) TO authenticated;

DROP FUNCTION IF EXISTS founder_hcfp_r2787_stage_breakdown();
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_stage_breakdown()
RETURNS TABLE(stage text, deal_count bigint, total_ticket_rupees bigint, expected_revenue_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.stage,
    count(*)::bigint,
    sum(d.ticket_size_rupees)::bigint,
    sum(d.quarterly_revenue_rupees * d.renew_probability_bps / 10000)::bigint
  FROM hospital_chain_financing_deals_r2787 d
  GROUP BY d.stage
  ORDER BY sum(d.ticket_size_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_stage_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_stage_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_hcfp_r2787_top_deals(integer);
CREATE OR REPLACE FUNCTION founder_hcfp_r2787_top_deals(p_limit integer DEFAULT 10)
RETURNS TABLE(deal_code text, chain_name text, equipment_category text, financing_kind text, ticket_size_rupees bigint, term_months integer, interest_rate_bps integer, quarterly_revenue_rupees bigint, renew_probability_bps integer, stage text, expected_close_date date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.deal_code, d.chain_name, d.equipment_category, d.financing_kind, d.ticket_size_rupees, d.term_months, d.interest_rate_bps, d.quarterly_revenue_rupees, d.renew_probability_bps, d.stage, d.expected_close_date
  FROM hospital_chain_financing_deals_r2787 d
  ORDER BY d.ticket_size_rupees DESC
  LIMIT greatest(coalesce(p_limit,10),1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcfp_r2787_top_deals(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcfp_r2787_top_deals(integer) TO authenticated;

COMMIT;
