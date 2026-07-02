BEGIN;

-- ============================================================================
-- Round 2856 — Customer Monthly Engineer Bundled AMC Cross-Sell
-- HEAVY ★★★★ founder console
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: monthly customer × engineer bundle cross-sell opportunities
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_engineer_bundle_amc_r2856 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL,
  customer_org_code text NOT NULL,
  customer_name text NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  bundle_code text NOT NULL,
  bundle_name text NOT NULL,
  device_count int NOT NULL CHECK (device_count >= 1),
  monthly_bundle_value_rupees bigint NOT NULL CHECK (monthly_bundle_value_rupees >= 0),
  proposed_amc_value_rupees bigint NOT NULL CHECK (proposed_amc_value_rupees >= 0),
  close_probability_pct numeric(5,2) NOT NULL CHECK (close_probability_pct >= 0 AND close_probability_pct <= 100),
  opportunity_stage text NOT NULL CHECK (opportunity_stage IN ('lead','qualified','proposal_sent','negotiation','won','lost')),
  cross_sell_status text NOT NULL CHECK (cross_sell_status IN ('queued','active','paused','closed')),
  refine_action text NOT NULL,
  last_touch_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_engineer_bundle_amc_r2856 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_engineer_bundle_amc_r2856;
CREATE POLICY founder_all ON customer_engineer_bundle_amc_r2856
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_engineer_bundle_amc_r2856
  (cycle_month, customer_org_code, customer_name, engineer_code, engineer_name,
   bundle_code, bundle_name, device_count, monthly_bundle_value_rupees,
   proposed_amc_value_rupees, close_probability_pct, opportunity_stage,
   cross_sell_status, refine_action, last_touch_at)
VALUES
  ('2026-06-01'::date,'HOSP-APL-001','Apollo Hyderabad','ENG-7701','Ravi Kumar',
   'BND-DENT-PRO','Dental Pro Bundle',12,84000,540000,72.50,'proposal_sent','active',
   'Send tier-2 AMC quote with dental sterilizer add-on by Friday','2026-06-19 10:15:00+05:30'),
  ('2026-06-01'::date,'HOSP-FRT-002','Fortis Bangalore','ENG-7702','Anita Sharma',
   'BND-IMG-CORE','Imaging Core Bundle',8,156000,1080000,58.00,'negotiation','active',
   'Counter at 14% discount with 2 free PMs; await procurement reply','2026-06-20 14:40:00+05:30'),
  ('2026-06-01'::date,'CLN-CTC-003','City Care Clinic','ENG-7703','Vinay Reddy',
   'BND-OPD-BASIC','OPD Basics Bundle',5,28000,168000,84.25,'won','closed',
   'Trigger onboarding workflow; assign monthly visit cadence','2026-06-18 09:00:00+05:30'),
  ('2026-06-01'::date,'HOSP-MAX-004','Max Saket Delhi','ENG-7704','Priya Nair',
   'BND-SURG-PRM','Surgical Premium Bundle',15,210000,1620000,42.10,'qualified','active',
   'Schedule on-site demo with biomed head; loop in CFO for tier pricing','2026-06-17 16:25:00+05:30'),
  ('2026-06-01'::date,'CLN-WLN-005','Wellness Clinic Pune','ENG-7705','Karthik Iyer',
   'BND-PHY-LITE','Physio Lite Bundle',3,12000,72000,65.00,'lead','queued',
   'Cold call decision-maker; share case study from Apollo Hyd','2026-06-21 08:30:00+05:30'),
  ('2026-06-01'::date,'HOSP-NRC-006','Narayana Cardiac','ENG-7706','Sneha Pillai',
   'BND-CARD-ADV','Cardiac Advanced Bundle',9,168000,1260000,38.75,'lost','closed',
   'Re-engage in Q3; competitor won on price — prepare aggressive renewal pitch','2026-06-15 11:45:00+05:30'),
  ('2026-06-01'::date,'HOSP-MED-007','Medanta Gurgaon','ENG-7707','Arjun Mehta',
   'BND-ICU-FULL','ICU Full Stack Bundle',20,360000,2700000,55.50,'proposal_sent','active',
   'Bundle ventilator AMC with monitor stack; offer 5% multi-year lock','2026-06-19 17:00:00+05:30');

-- ---------------------------------------------------------------------------
-- Table 2: renewal forecast + refine plays per opportunity
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bundle_amc_renewal_refine_plays_r2856 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES customer_engineer_bundle_amc_r2856(id) ON DELETE CASCADE,
  forecast_month date NOT NULL,
  expected_renew_value_rupees bigint NOT NULL CHECK (expected_renew_value_rupees >= 0),
  renew_probability_pct numeric(5,2) NOT NULL CHECK (renew_probability_pct >= 0 AND renew_probability_pct <= 100),
  refine_play text NOT NULL CHECK (refine_play IN ('discount_lever','engineer_swap','bundle_upsell','tier_downsell','retention_call','exec_escalation')),
  play_notes text NOT NULL,
  play_owner text NOT NULL,
  play_status text NOT NULL CHECK (play_status IN ('planned','in_progress','completed','dropped')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bundle_amc_renewal_refine_plays_r2856 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON bundle_amc_renewal_refine_plays_r2856;
CREATE POLICY founder_all ON bundle_amc_renewal_refine_plays_r2856
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO bundle_amc_renewal_refine_plays_r2856
  (opportunity_id, forecast_month, expected_renew_value_rupees, renew_probability_pct,
   refine_play, play_notes, play_owner, play_status)
SELECT id, '2026-07-01'::date, 486000, 70.00, 'bundle_upsell',
       'Add CT-scan PM module to Apollo bundle; expand devices from 12 to 15',
       'founder', 'in_progress'
FROM customer_engineer_bundle_amc_r2856 WHERE customer_org_code = 'HOSP-APL-001'
UNION ALL
SELECT id, '2026-07-01'::date, 972000, 55.00, 'discount_lever',
       'Authorize 12% renewal discount to lock Fortis for 24 months',
       'sales_head', 'planned'
FROM customer_engineer_bundle_amc_r2856 WHERE customer_org_code = 'HOSP-FRT-002'
UNION ALL
SELECT id, '2026-07-01'::date, 168000, 92.00, 'retention_call',
       'NPS 9 — schedule QBR with City Care for July review',
       'csm_lead', 'completed'
FROM customer_engineer_bundle_amc_r2856 WHERE customer_org_code = 'CLN-CTC-003'
UNION ALL
SELECT id, '2026-07-01'::date, 1296000, 35.00, 'exec_escalation',
       'CEO-to-CEO call needed; Max biomed leaning toward competitor',
       'founder', 'planned'
FROM customer_engineer_bundle_amc_r2856 WHERE customer_org_code = 'HOSP-MAX-004'
UNION ALL
SELECT id, '2026-08-01'::date, 60000, 60.00, 'tier_downsell',
       'Offer lite-tier AMC at 60k to preserve account; upsell later',
       'sales_rep', 'in_progress'
FROM customer_engineer_bundle_amc_r2856 WHERE customer_org_code = 'CLN-WLN-005'
UNION ALL
SELECT id, '2026-09-01'::date, 1100000, 22.00, 'engineer_swap',
       'Reassign senior engineer; Narayana flagged service quality concern',
       'ops_head', 'planned'
FROM customer_engineer_bundle_amc_r2856 WHERE customer_org_code = 'HOSP-NRC-006'
UNION ALL
SELECT id, '2026-07-01'::date, 2430000, 50.00, 'bundle_upsell',
       'Cross-sell ECMO module to Medanta ICU stack; 3-year commit pitch',
       'founder', 'in_progress'
FROM customer_engineer_bundle_amc_r2856 WHERE customer_org_code = 'HOSP-MED-007';

-- ---------------------------------------------------------------------------
-- RPC 1: KPI summary
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_kpis();
CREATE OR REPLACE FUNCTION founder_r2856_kpis()
RETURNS TABLE (
  active_opportunities bigint,
  total_pipeline_value_rupees numeric,
  weighted_pipeline_value_rupees numeric,
  avg_close_probability_pct numeric,
  won_count bigint,
  lost_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE cross_sell_status = 'active')::bigint,
    COALESCE(SUM(proposed_amc_value_rupees), 0)::numeric,
    COALESCE(SUM(proposed_amc_value_rupees * close_probability_pct / 100.0), 0)::numeric,
    COALESCE(AVG(close_probability_pct), 0)::numeric,
    COUNT(*) FILTER (WHERE opportunity_stage = 'won')::bigint,
    COUNT(*) FILTER (WHERE opportunity_stage = 'lost')::bigint
  FROM customer_engineer_bundle_amc_r2856;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_kpis() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: list opportunities
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_list_opportunities();
CREATE OR REPLACE FUNCTION founder_r2856_list_opportunities()
RETURNS TABLE (
  id uuid,
  customer_name text,
  engineer_name text,
  bundle_name text,
  device_count int,
  proposed_amc_value_rupees bigint,
  close_probability_pct numeric,
  opportunity_stage text,
  cross_sell_status text,
  refine_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.id, o.customer_name, o.engineer_name, o.bundle_name, o.device_count,
         o.proposed_amc_value_rupees, o.close_probability_pct, o.opportunity_stage,
         o.cross_sell_status, o.refine_action
  FROM customer_engineer_bundle_amc_r2856 o
  ORDER BY o.proposed_amc_value_rupees * o.close_probability_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_list_opportunities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_list_opportunities() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: stage funnel
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_stage_funnel();
CREATE OR REPLACE FUNCTION founder_r2856_stage_funnel()
RETURNS TABLE (
  opportunity_stage text,
  opp_count bigint,
  stage_pipeline_value_rupees numeric,
  avg_close_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.opportunity_stage,
         COUNT(*)::bigint,
         COALESCE(SUM(o.proposed_amc_value_rupees), 0)::numeric,
         COALESCE(AVG(o.close_probability_pct), 0)::numeric
  FROM customer_engineer_bundle_amc_r2856 o
  GROUP BY o.opportunity_stage
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_stage_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_stage_funnel() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: engineer leaderboard
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2856_engineer_leaderboard()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  opp_count bigint,
  weighted_pipeline_value_rupees numeric,
  best_stage text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.engineer_code, o.engineer_name,
         COUNT(*)::bigint,
         COALESCE(SUM(o.proposed_amc_value_rupees * o.close_probability_pct / 100.0), 0)::numeric,
         (ARRAY_AGG(o.opportunity_stage ORDER BY o.close_probability_pct DESC))[1]
  FROM customer_engineer_bundle_amc_r2856 o
  GROUP BY o.engineer_code, o.engineer_name
  ORDER BY SUM(o.proposed_amc_value_rupees * o.close_probability_pct / 100.0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_engineer_leaderboard() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: renewal forecast
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_renewal_forecast();
CREATE OR REPLACE FUNCTION founder_r2856_renewal_forecast()
RETURNS TABLE (
  forecast_month date,
  play_count bigint,
  expected_value_rupees numeric,
  weighted_value_rupees numeric,
  avg_renew_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT p.forecast_month,
         COUNT(*)::bigint,
         COALESCE(SUM(p.expected_renew_value_rupees), 0)::numeric,
         COALESCE(SUM(p.expected_renew_value_rupees * p.renew_probability_pct / 100.0), 0)::numeric,
         COALESCE(AVG(p.renew_probability_pct), 0)::numeric
  FROM bundle_amc_renewal_refine_plays_r2856 p
  GROUP BY p.forecast_month
  ORDER BY p.forecast_month ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_renewal_forecast() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_renewal_forecast() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: refine plays list
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_refine_plays();
CREATE OR REPLACE FUNCTION founder_r2856_refine_plays()
RETURNS TABLE (
  customer_name text,
  refine_play text,
  expected_renew_value_rupees bigint,
  renew_probability_pct numeric,
  play_owner text,
  play_status text,
  play_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.customer_name, p.refine_play, p.expected_renew_value_rupees,
         p.renew_probability_pct, p.play_owner, p.play_status, p.play_notes
  FROM bundle_amc_renewal_refine_plays_r2856 p
  JOIN customer_engineer_bundle_amc_r2856 o ON o.id = p.opportunity_id
  ORDER BY p.expected_renew_value_rupees * p.renew_probability_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_refine_plays() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_refine_plays() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: advance opportunity stage
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_advance_stage(uuid, text);
CREATE OR REPLACE FUNCTION founder_r2856_advance_stage(p_id uuid, p_stage text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_stage NOT IN ('lead','qualified','proposal_sent','negotiation','won','lost') THEN
    RAISE EXCEPTION 'invalid stage';
  END IF;
  UPDATE customer_engineer_bundle_amc_r2856
     SET opportunity_stage = p_stage,
         last_touch_at = now(),
         cross_sell_status = CASE WHEN p_stage IN ('won','lost') THEN 'closed' ELSE cross_sell_status END
   WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_advance_stage(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_advance_stage(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: bundle ROI roll-up
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2856_bundle_roi();
CREATE OR REPLACE FUNCTION founder_r2856_bundle_roi()
RETURNS TABLE (
  bundle_code text,
  bundle_name text,
  opp_count bigint,
  total_devices bigint,
  monthly_bundle_value_rupees numeric,
  proposed_amc_value_rupees numeric,
  amc_to_bundle_multiple numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.bundle_code, o.bundle_name,
         COUNT(*)::bigint,
         COALESCE(SUM(o.device_count), 0)::bigint,
         COALESCE(SUM(o.monthly_bundle_value_rupees), 0)::numeric,
         COALESCE(SUM(o.proposed_amc_value_rupees), 0)::numeric,
         CASE WHEN SUM(o.monthly_bundle_value_rupees) > 0
              THEN ROUND(SUM(o.proposed_amc_value_rupees)::numeric / SUM(o.monthly_bundle_value_rupees), 2)
              ELSE 0 END
  FROM customer_engineer_bundle_amc_r2856 o
  GROUP BY o.bundle_code, o.bundle_name
  ORDER BY SUM(o.proposed_amc_value_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2856_bundle_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2856_bundle_roi() TO authenticated;

COMMIT;
