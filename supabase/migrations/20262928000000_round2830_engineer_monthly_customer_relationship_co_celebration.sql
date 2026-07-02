BEGIN;

CREATE TABLE IF NOT EXISTS engineer_customer_milestone_r2830 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  customer_name text NOT NULL,
  milestone_type text NOT NULL CHECK (milestone_type IN ('one_year','two_year','three_year','tenth_repair','fiftieth_repair','first_amc_renewal','zero_downtime_quarter')),
  milestone_date date NOT NULL,
  gesture_type text NOT NULL CHECK (gesture_type IN ('handwritten_card','sweet_box','flower_bouquet','team_photo_frame','complimentary_service','founder_call')),
  gesture_cost_rupees integer NOT NULL CHECK (gesture_cost_rupees >= 0),
  engagement_score integer NOT NULL CHECK (engagement_score BETWEEN 0 AND 100),
  ltv_uplift_rupees integer NOT NULL CHECK (ltv_uplift_rupees >= 0),
  verdict text NOT NULL CHECK (verdict IN ('green','amber','red')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_customer_milestone_r2830 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_customer_milestone_r2830;
CREATE POLICY founder_all ON engineer_customer_milestone_r2830 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_celebration_outcome_r2830 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  customer_name text NOT NULL,
  celebration_month date NOT NULL,
  gestures_delivered integer NOT NULL CHECK (gestures_delivered >= 0),
  customer_response text NOT NULL CHECK (customer_response IN ('delighted','pleased','neutral','no_response','negative')),
  referrals_generated integer NOT NULL DEFAULT 0 CHECK (referrals_generated >= 0),
  amc_renewed boolean NOT NULL DEFAULT false,
  nps_delta integer NOT NULL DEFAULT 0,
  next_action text NOT NULL CHECK (next_action IN ('scale_program','continue','adjust_gesture','pause','escalate')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_celebration_outcome_r2830 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_celebration_outcome_r2830;
CREATE POLICY founder_all ON engineer_celebration_outcome_r2830 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_customer_milestone_r2830 (engineer_name, customer_name, milestone_type, milestone_date, gesture_type, gesture_cost_rupees, engagement_score, ltv_uplift_rupees, verdict, notes) VALUES
('Ravi Kumar','Apollo Hyderabad','one_year','2026-06-10','handwritten_card',200,92,180000,'green','One year partnership card from engineer + founder'),
('Sneha Patel','KIMS Secunderabad','tenth_repair','2026-06-12','sweet_box',850,88,120000,'green','Tenth successful repair milestone'),
('Arjun Reddy','Yashoda Somajiguda','first_amc_renewal','2026-06-15','complimentary_service',2500,95,250000,'green','AMC renewed for second year'),
('Priya Sharma','Continental Gachibowli','zero_downtime_quarter','2026-06-18','team_photo_frame',1200,90,150000,'green','Zero unplanned downtime in Q1'),
('Vikas Singh','Care Banjara Hills','two_year','2026-06-20','founder_call',0,85,200000,'amber','Two year mark - founder personally called'),
('Meena Iyer','Sunshine Paradise','fiftieth_repair','2026-06-22','flower_bouquet',650,78,90000,'amber','Fiftieth repair - relationship strong'),
('Kiran Rao','Rainbow Childrens','three_year','2026-06-24','founder_call',0,72,60000,'red','Three year mark but slipping NPS');

INSERT INTO engineer_celebration_outcome_r2830 (engineer_name, customer_name, celebration_month, gestures_delivered, customer_response, referrals_generated, amc_renewed, nps_delta, next_action) VALUES
('Ravi Kumar','Apollo Hyderabad','2026-06-01',2,'delighted',3,true,15,'scale_program'),
('Sneha Patel','KIMS Secunderabad','2026-06-01',1,'pleased',1,true,8,'continue'),
('Arjun Reddy','Yashoda Somajiguda','2026-06-01',2,'delighted',2,true,12,'scale_program'),
('Priya Sharma','Continental Gachibowli','2026-06-01',1,'pleased',1,false,5,'continue'),
('Vikas Singh','Care Banjara Hills','2026-06-01',1,'neutral',0,true,2,'adjust_gesture'),
('Meena Iyer','Sunshine Paradise','2026-06-01',1,'pleased',0,false,3,'continue'),
('Kiran Rao','Rainbow Childrens','2026-06-01',1,'no_response',0,false,-2,'escalate');

DROP FUNCTION IF EXISTS founder_r2830_milestone_summary();
CREATE OR REPLACE FUNCTION founder_r2830_milestone_summary()
RETURNS TABLE(total_milestones bigint, green_count bigint, amber_count bigint, red_count bigint, total_ltv_uplift bigint, avg_engagement numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT COUNT(*), COUNT(*) FILTER (WHERE verdict='green'), COUNT(*) FILTER (WHERE verdict='amber'), COUNT(*) FILTER (WHERE verdict='red'), COALESCE(SUM(ltv_uplift_rupees),0), COALESCE(ROUND(AVG(engagement_score),2),0) FROM engineer_customer_milestone_r2830;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_milestone_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_milestone_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2830_milestone_list();
CREATE OR REPLACE FUNCTION founder_r2830_milestone_list()
RETURNS SETOF engineer_customer_milestone_r2830
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_customer_milestone_r2830 ORDER BY milestone_date DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_milestone_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_milestone_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2830_outcome_list();
CREATE OR REPLACE FUNCTION founder_r2830_outcome_list()
RETURNS SETOF engineer_celebration_outcome_r2830
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_celebration_outcome_r2830 ORDER BY celebration_month DESC, nps_delta DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_outcome_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_outcome_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2830_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2830_engineer_leaderboard()
RETURNS TABLE(engineer_name text, milestones_celebrated bigint, total_ltv_uplift bigint, avg_engagement numeric, green_share numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.engineer_name, COUNT(*)::bigint, COALESCE(SUM(m.ltv_uplift_rupees),0)::bigint, ROUND(AVG(m.engagement_score),2), ROUND(100.0 * COUNT(*) FILTER (WHERE m.verdict='green') / NULLIF(COUNT(*),0), 2) FROM engineer_customer_milestone_r2830 m GROUP BY m.engineer_name ORDER BY total_ltv_uplift DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2830_gesture_mix();
CREATE OR REPLACE FUNCTION founder_r2830_gesture_mix()
RETURNS TABLE(gesture_type text, count bigint, total_cost bigint, total_ltv_uplift bigint, roi_multiple numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.gesture_type, COUNT(*)::bigint, COALESCE(SUM(m.gesture_cost_rupees),0)::bigint, COALESCE(SUM(m.ltv_uplift_rupees),0)::bigint, CASE WHEN SUM(m.gesture_cost_rupees) > 0 THEN ROUND(SUM(m.ltv_uplift_rupees)::numeric / SUM(m.gesture_cost_rupees), 2) ELSE NULL END FROM engineer_customer_milestone_r2830 m GROUP BY m.gesture_type ORDER BY total_ltv_uplift DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_gesture_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_gesture_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2830_response_mix();
CREATE OR REPLACE FUNCTION founder_r2830_response_mix()
RETURNS TABLE(customer_response text, count bigint, total_referrals bigint, amc_renewal_rate numeric, avg_nps_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT o.customer_response, COUNT(*)::bigint, COALESCE(SUM(o.referrals_generated),0)::bigint, ROUND(100.0 * COUNT(*) FILTER (WHERE o.amc_renewed) / NULLIF(COUNT(*),0), 2), ROUND(AVG(o.nps_delta),2) FROM engineer_celebration_outcome_r2830 o GROUP BY o.customer_response ORDER BY count DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_response_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_response_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2830_red_milestones();
CREATE OR REPLACE FUNCTION founder_r2830_red_milestones()
RETURNS SETOF engineer_customer_milestone_r2830
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_customer_milestone_r2830 WHERE verdict='red' OR engagement_score < 75 ORDER BY engagement_score ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_red_milestones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_red_milestones() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2830_program_kpis();
CREATE OR REPLACE FUNCTION founder_r2830_program_kpis()
RETURNS TABLE(total_outcomes bigint, total_referrals bigint, renewal_rate numeric, avg_nps_delta numeric, scale_signals bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT COUNT(*)::bigint, COALESCE(SUM(referrals_generated),0)::bigint, ROUND(100.0 * COUNT(*) FILTER (WHERE amc_renewed) / NULLIF(COUNT(*),0), 2), ROUND(AVG(nps_delta),2), COUNT(*) FILTER (WHERE next_action='scale_program')::bigint FROM engineer_celebration_outcome_r2830;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2830_program_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2830_program_kpis() TO authenticated;

COMMIT;