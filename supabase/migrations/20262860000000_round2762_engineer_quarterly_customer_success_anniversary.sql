BEGIN;

-- ============================================================================
-- Round 2762: Engineer Quarterly Customer Success Anniversary
-- engineer x customer x tenure x gesture x pulse x retention impact
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: anniversary milestones tracker
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_customer_anniversary_milestones_r2762 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name               text NOT NULL,
  engineer_tier               text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum','diamond')),
  customer_org                text NOT NULL,
  customer_segment            text NOT NULL CHECK (customer_segment IN ('hospital','clinic','diagnostic','dental','homecare')),
  tenure_quarters             int NOT NULL CHECK (tenure_quarters >= 1 AND tenure_quarters <= 40),
  anniversary_date            date NOT NULL,
  gesture_type                text NOT NULL CHECK (gesture_type IN ('handwritten_note','site_visit','cake_delivery','tech_upgrade','training_session','plaque','none')),
  gesture_cost_rupees         int NOT NULL DEFAULT 0 CHECK (gesture_cost_rupees >= 0),
  customer_pulse_score        numeric(3,1) NOT NULL CHECK (customer_pulse_score >= 0 AND customer_pulse_score <= 10),
  retention_lift_pct          numeric(5,2) NOT NULL CHECK (retention_lift_pct >= -100 AND retention_lift_pct <= 100),
  amc_renewal_likelihood_pct  numeric(5,2) NOT NULL CHECK (amc_renewal_likelihood_pct >= 0 AND amc_renewal_likelihood_pct <= 100),
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_customer_anniversary_milestones_r2762 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_customer_anniversary_milestones_r2762;
CREATE POLICY founder_all ON engineer_customer_anniversary_milestones_r2762
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_customer_anniversary_milestones_r2762
  (engineer_name, engineer_tier, customer_org, customer_segment, tenure_quarters, anniversary_date, gesture_type, gesture_cost_rupees, customer_pulse_score, retention_lift_pct, amc_renewal_likelihood_pct, notes)
VALUES
  ('Ravi Kumar',     'platinum', 'Apollo Hyderabad',   'hospital',   12, '2026-06-01'::date, 'plaque',           4500, 9.2, 18.50, 96.00, 'Q12 plaque + ribbon ceremony with biomed lead'),
  ('Priya Sharma',   'gold',     'Yashoda Secunderabad','hospital',   8,  '2026-06-08'::date, 'site_visit',       1800, 8.7, 12.30, 88.50, 'Surprise visit + lunch with maintenance crew'),
  ('Anjali Reddy',   'diamond',  'Care Hospitals',     'hospital',   20, '2026-06-15'::date, 'tech_upgrade',    18500, 9.8, 24.80, 99.20, '5-year anniversary — free CR plate calibration'),
  ('Suresh Naidu',   'silver',   'Dental Plus Banjara','dental',     4,  '2026-06-20'::date, 'handwritten_note', 150,  7.4, 6.80,  72.00, 'First-year card + chai meetup'),
  ('Meera Iyer',     'gold',     'Vijaya Diagnostics', 'diagnostic', 16, '2026-06-22'::date, 'cake_delivery',    950,  8.9, 15.40, 91.00, 'Custom cake + sonography tech training'),
  ('Karthik Rao',    'platinum', 'KIMS Begumpet',      'hospital',   24, '2026-06-25'::date, 'training_session', 6500, 9.4, 20.10, 95.50, '6-year — free workshop for 4 biomed staff'),
  ('Lakshmi Devi',   'bronze',   'Sunrise Homecare',   'homecare',   2,  '2026-06-28'::date, 'none',             0,    6.8, 2.10,  58.00, 'Missed — engineer on leave; gesture deferred');

-- ---------------------------------------------------------------------------
-- Table 2: gesture impact ledger (post-gesture customer pulse readings)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS anniversary_gesture_impact_ledger_r2762 (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id           uuid REFERENCES engineer_customer_anniversary_milestones_r2762(id) ON DELETE CASCADE,
  pulse_check_date       date NOT NULL,
  days_since_gesture     int NOT NULL CHECK (days_since_gesture >= 0),
  pulse_score_post       numeric(3,1) NOT NULL CHECK (pulse_score_post >= 0 AND pulse_score_post <= 10),
  pulse_delta            numeric(3,1) NOT NULL CHECK (pulse_delta >= -10 AND pulse_delta <= 10),
  amc_signed_post        boolean NOT NULL DEFAULT false,
  upsell_value_rupees    int NOT NULL DEFAULT 0 CHECK (upsell_value_rupees >= 0),
  testimonial_received   boolean NOT NULL DEFAULT false,
  referral_made          boolean NOT NULL DEFAULT false,
  outcome_tag            text NOT NULL CHECK (outcome_tag IN ('exceeded','met','partial','missed','reversed')),
  created_at             timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE anniversary_gesture_impact_ledger_r2762 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON anniversary_gesture_impact_ledger_r2762;
CREATE POLICY founder_all ON anniversary_gesture_impact_ledger_r2762
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO anniversary_gesture_impact_ledger_r2762
  (milestone_id, pulse_check_date, days_since_gesture, pulse_score_post, pulse_delta, amc_signed_post, upsell_value_rupees, testimonial_received, referral_made, outcome_tag)
SELECT id, '2026-06-15'::date, 14, 9.6, 0.4, true,  85000, true,  true,  'exceeded' FROM engineer_customer_anniversary_milestones_r2762 WHERE engineer_name='Ravi Kumar'
UNION ALL
SELECT id, '2026-06-22'::date, 14, 8.9, 0.2, true,  42000, false, true,  'met'      FROM engineer_customer_anniversary_milestones_r2762 WHERE engineer_name='Priya Sharma'
UNION ALL
SELECT id, '2026-06-29'::date, 14, 9.9, 0.1, true,  240000,true,  true,  'exceeded' FROM engineer_customer_anniversary_milestones_r2762 WHERE engineer_name='Anjali Reddy'
UNION ALL
SELECT id, '2026-07-04'::date, 14, 7.6, 0.2, false, 0,     false, false, 'partial'  FROM engineer_customer_anniversary_milestones_r2762 WHERE engineer_name='Suresh Naidu'
UNION ALL
SELECT id, '2026-07-06'::date, 14, 9.2, 0.3, true,  68000, true,  false, 'met'      FROM engineer_customer_anniversary_milestones_r2762 WHERE engineer_name='Meera Iyer'
UNION ALL
SELECT id, '2026-07-09'::date, 14, 9.5, 0.1, true,  125000,true,  true,  'exceeded' FROM engineer_customer_anniversary_milestones_r2762 WHERE engineer_name='Karthik Rao'
UNION ALL
SELECT id, '2026-07-12'::date, 14, 5.9, -0.9,false, 0,     false, false, 'missed'   FROM engineer_customer_anniversary_milestones_r2762 WHERE engineer_name='Lakshmi Devi';

-- ---------------------------------------------------------------------------
-- RPC 1: KPI summary
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_anniversary_kpis();
CREATE OR REPLACE FUNCTION founder_r2762_anniversary_kpis()
RETURNS TABLE (
  total_milestones        bigint,
  gestures_executed       bigint,
  avg_pulse               numeric,
  avg_retention_lift      numeric,
  total_gesture_spend     bigint,
  total_upsell_unlocked   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM engineer_customer_anniversary_milestones_r2762),
    (SELECT count(*) FROM engineer_customer_anniversary_milestones_r2762 WHERE gesture_type != 'none'),
    (SELECT round(avg(customer_pulse_score)::numeric, 2) FROM engineer_customer_anniversary_milestones_r2762),
    (SELECT round(avg(retention_lift_pct)::numeric, 2) FROM engineer_customer_anniversary_milestones_r2762),
    (SELECT coalesce(sum(gesture_cost_rupees),0)::bigint FROM engineer_customer_anniversary_milestones_r2762),
    (SELECT coalesce(sum(upsell_value_rupees),0)::bigint FROM anniversary_gesture_impact_ledger_r2762);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_anniversary_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_anniversary_kpis() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: milestone roster
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_milestone_roster();
CREATE OR REPLACE FUNCTION founder_r2762_milestone_roster()
RETURNS TABLE (
  id                          uuid,
  engineer_name               text,
  engineer_tier               text,
  customer_org                text,
  customer_segment            text,
  tenure_quarters             int,
  anniversary_date            date,
  gesture_type                text,
  gesture_cost_rupees         int,
  customer_pulse_score        numeric,
  retention_lift_pct          numeric,
  amc_renewal_likelihood_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.engineer_name, m.engineer_tier, m.customer_org, m.customer_segment,
         m.tenure_quarters, m.anniversary_date, m.gesture_type, m.gesture_cost_rupees,
         m.customer_pulse_score, m.retention_lift_pct, m.amc_renewal_likelihood_pct
  FROM engineer_customer_anniversary_milestones_r2762 m
  ORDER BY m.anniversary_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_milestone_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_milestone_roster() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: gesture-impact ledger
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_impact_ledger();
CREATE OR REPLACE FUNCTION founder_r2762_impact_ledger()
RETURNS TABLE (
  engineer_name         text,
  customer_org          text,
  pulse_check_date      date,
  pulse_score_post      numeric,
  pulse_delta           numeric,
  amc_signed_post       boolean,
  upsell_value_rupees   int,
  testimonial_received  boolean,
  referral_made         boolean,
  outcome_tag           text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.engineer_name, m.customer_org, l.pulse_check_date, l.pulse_score_post,
         l.pulse_delta, l.amc_signed_post, l.upsell_value_rupees,
         l.testimonial_received, l.referral_made, l.outcome_tag
  FROM anniversary_gesture_impact_ledger_r2762 l
  JOIN engineer_customer_anniversary_milestones_r2762 m ON m.id = l.milestone_id
  ORDER BY l.pulse_check_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_impact_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_impact_ledger() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: tenure cohort breakdown
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_tenure_cohort();
CREATE OR REPLACE FUNCTION founder_r2762_tenure_cohort()
RETURNS TABLE (
  tenure_bucket       text,
  cohort_size         bigint,
  avg_pulse           numeric,
  avg_retention_lift  numeric,
  total_upsell        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN m.tenure_quarters <= 4  THEN 'Y1 (1-4 Q)'
      WHEN m.tenure_quarters <= 8  THEN 'Y2 (5-8 Q)'
      WHEN m.tenure_quarters <= 16 THEN 'Y3-4 (9-16 Q)'
      ELSE 'Y5+ (17+ Q)'
    END AS tenure_bucket,
    count(*)::bigint,
    round(avg(m.customer_pulse_score)::numeric, 2),
    round(avg(m.retention_lift_pct)::numeric, 2),
    coalesce(sum(l.upsell_value_rupees), 0)::bigint
  FROM engineer_customer_anniversary_milestones_r2762 m
  LEFT JOIN anniversary_gesture_impact_ledger_r2762 l ON l.milestone_id = m.id
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_tenure_cohort() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_tenure_cohort() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: gesture-type ROI
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_gesture_roi();
CREATE OR REPLACE FUNCTION founder_r2762_gesture_roi()
RETURNS TABLE (
  gesture_type      text,
  uses              bigint,
  avg_cost          numeric,
  avg_pulse_delta   numeric,
  total_upsell      bigint,
  roi_multiple      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.gesture_type,
    count(*)::bigint,
    round(avg(m.gesture_cost_rupees)::numeric, 2),
    round(coalesce(avg(l.pulse_delta), 0)::numeric, 2),
    coalesce(sum(l.upsell_value_rupees), 0)::bigint,
    CASE WHEN coalesce(sum(m.gesture_cost_rupees), 0) = 0 THEN 0
         ELSE round((coalesce(sum(l.upsell_value_rupees),0)::numeric / sum(m.gesture_cost_rupees)::numeric), 2) END
  FROM engineer_customer_anniversary_milestones_r2762 m
  LEFT JOIN anniversary_gesture_impact_ledger_r2762 l ON l.milestone_id = m.id
  GROUP BY m.gesture_type
  ORDER BY 5 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_gesture_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_gesture_roi() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: engineer leaderboard
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2762_engineer_leaderboard()
RETURNS TABLE (
  engineer_name         text,
  engineer_tier         text,
  milestones_handled    bigint,
  avg_pulse_score       numeric,
  avg_retention_lift    numeric,
  total_upsell_driven   bigint,
  testimonials_secured  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.engineer_name,
    max(m.engineer_tier),
    count(*)::bigint,
    round(avg(m.customer_pulse_score)::numeric, 2),
    round(avg(m.retention_lift_pct)::numeric, 2),
    coalesce(sum(l.upsell_value_rupees), 0)::bigint,
    coalesce(sum(CASE WHEN l.testimonial_received THEN 1 ELSE 0 END), 0)::bigint
  FROM engineer_customer_anniversary_milestones_r2762 m
  LEFT JOIN anniversary_gesture_impact_ledger_r2762 l ON l.milestone_id = m.id
  GROUP BY m.engineer_name
  ORDER BY 6 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_engineer_leaderboard() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: at-risk anniversaries (low pulse, missed gesture)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_at_risk_anniversaries();
CREATE OR REPLACE FUNCTION founder_r2762_at_risk_anniversaries()
RETURNS TABLE (
  engineer_name              text,
  customer_org               text,
  customer_segment           text,
  tenure_quarters            int,
  anniversary_date           date,
  gesture_type               text,
  customer_pulse_score       numeric,
  amc_renewal_likelihood_pct numeric,
  risk_flag                  text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.engineer_name, m.customer_org, m.customer_segment, m.tenure_quarters,
         m.anniversary_date, m.gesture_type, m.customer_pulse_score, m.amc_renewal_likelihood_pct,
         CASE
           WHEN m.gesture_type = 'none' AND m.customer_pulse_score < 7.5 THEN 'critical'
           WHEN m.customer_pulse_score < 8.0 THEN 'watch'
           WHEN m.amc_renewal_likelihood_pct < 75 THEN 'renewal_risk'
           ELSE 'healthy'
         END
  FROM engineer_customer_anniversary_milestones_r2762 m
  WHERE m.customer_pulse_score < 8.5 OR m.amc_renewal_likelihood_pct < 80 OR m.gesture_type = 'none'
  ORDER BY m.customer_pulse_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_at_risk_anniversaries() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_at_risk_anniversaries() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: segment x outcome matrix
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2762_segment_outcome_matrix();
CREATE OR REPLACE FUNCTION founder_r2762_segment_outcome_matrix()
RETURNS TABLE (
  customer_segment   text,
  total              bigint,
  exceeded_count     bigint,
  met_count          bigint,
  partial_count      bigint,
  missed_count       bigint,
  exceeded_rate_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.customer_segment,
    count(*)::bigint,
    coalesce(sum(CASE WHEN l.outcome_tag = 'exceeded' THEN 1 ELSE 0 END), 0)::bigint,
    coalesce(sum(CASE WHEN l.outcome_tag = 'met'      THEN 1 ELSE 0 END), 0)::bigint,
    coalesce(sum(CASE WHEN l.outcome_tag = 'partial'  THEN 1 ELSE 0 END), 0)::bigint,
    coalesce(sum(CASE WHEN l.outcome_tag IN ('missed','reversed') THEN 1 ELSE 0 END), 0)::bigint,
    round(100.0 * coalesce(sum(CASE WHEN l.outcome_tag='exceeded' THEN 1 ELSE 0 END), 0)::numeric
                  / NULLIF(count(*),0)::numeric, 2)
  FROM engineer_customer_anniversary_milestones_r2762 m
  LEFT JOIN anniversary_gesture_impact_ledger_r2762 l ON l.milestone_id = m.id
  GROUP BY m.customer_segment
  ORDER BY 7 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2762_segment_outcome_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2762_segment_outcome_matrix() TO authenticated;

COMMIT;
