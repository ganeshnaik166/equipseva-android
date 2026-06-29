-- Round 2894: Engineer Monthly Customer Premises Damage Incident Log
-- HEAVY founder ops: engineer accountability for on-site damage incidents.

BEGIN;

-- ============================================================
-- Table 1: Damage incidents logged at customer premises
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_premises_damage_incidents_r2894 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  incident_month date not null,
  engineer_code text not null,
  engineer_tier text not null,
  hospital_name text not null,
  city text not null,
  incident_date timestamptz not null,
  incident_type text not null,  -- 'wall_dent','floor_scratch','door_damage','equipment_drop','wiring_damage','flooring','cabinet_damage','ceiling_tile'
  severity text not null,        -- 'minor','moderate','major','severe'
  damage_estimate_rupees integer not null,
  reimbursement_status text not null,  -- 'pending','approved','paid','disputed','denied','adjusted'
  reimbursed_rupees integer not null default 0,
  payout_clawback_rupees integer not null default 0,
  customer_satisfaction text not null, -- 'resolved','accepted','still_unhappy','escalated'
  photo_evidence_count integer not null default 0,
  resolution_days integer
);
ALTER TABLE engineer_premises_damage_incidents_r2894 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Table 2: Engineer monthly damage scorecards
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_damage_monthly_scorecard_r2894 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  scorecard_month date not null,
  engineer_code text not null,
  engineer_tier text not null,
  jobs_completed integer not null,
  incidents_logged integer not null,
  damage_rate_pct numeric(5,2) not null,
  total_damage_rupees integer not null,
  total_clawback_rupees integer not null,
  net_payout_impact_rupees integer not null,
  training_required boolean not null default false,
  warning_letter_issued boolean not null default false,
  probation_status text not null,  -- 'clear','watch','probation','final_warning','terminated'
  coaching_session_count integer not null default 0,
  trend_vs_prev_month text not null  -- 'improving','flat','worsening'
);
ALTER TABLE engineer_damage_monthly_scorecard_r2894 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Seeds
-- ============================================================
INSERT INTO engineer_premises_damage_incidents_r2894
  (incident_month, engineer_code, engineer_tier, hospital_name, city, incident_date, incident_type, severity, damage_estimate_rupees, reimbursement_status, reimbursed_rupees, payout_clawback_rupees, customer_satisfaction, photo_evidence_count, resolution_days)
VALUES
  ('2026-06-01','ENG-1042','gold','Apollo Hyderabad','Hyderabad', now() - interval '2 day','wall_dent','minor',1800,'paid',1800,1800,'resolved',4,3),
  ('2026-06-01','ENG-1042','gold','Yashoda Secunderabad','Hyderabad', now() - interval '5 day','floor_scratch','moderate',6500,'approved',6500,6500,'accepted',6,5),
  ('2026-06-01','ENG-1183','silver','KIMS Kondapur','Hyderabad', now() - interval '7 day','door_damage','major',18500,'disputed',0,0,'still_unhappy',8,NULL),
  ('2026-06-01','ENG-1183','silver','Care Banjara','Hyderabad', now() - interval '9 day','equipment_drop','severe',45000,'pending',0,0,'escalated',12,NULL),
  ('2026-06-01','ENG-1207','bronze','Continental Gachibowli','Hyderabad', now() - interval '12 day','wiring_damage','moderate',8200,'paid',8200,8200,'resolved',5,4),
  ('2026-06-01','ENG-1207','bronze','Rainbow Banjara','Hyderabad', now() - interval '14 day','flooring','minor',2400,'adjusted',1500,1500,'accepted',3,6),
  ('2026-06-01','ENG-1322','gold','AIG Gachibowli','Hyderabad', now() - interval '16 day','cabinet_damage','moderate',9800,'paid',9800,9800,'resolved',7,4),
  ('2026-06-01','ENG-1322','gold','Sunshine Begumpet','Hyderabad', now() - interval '18 day','ceiling_tile','minor',1200,'paid',1200,1200,'resolved',2,2),
  ('2026-06-01','ENG-1455','platinum','Fortis Bangalore','Bangalore', now() - interval '20 day','wall_dent','minor',1600,'paid',1600,1600,'resolved',3,3),
  ('2026-06-01','ENG-1612','silver','Manipal Old Airport','Bangalore', now() - interval '22 day','equipment_drop','major',28000,'denied',0,0,'escalated',10,NULL),
  ('2026-06-01','ENG-1612','silver','Narayana Health','Bangalore', now() - interval '24 day','door_damage','moderate',7500,'disputed',0,0,'still_unhappy',6,NULL),
  ('2026-06-01','ENG-1789','bronze','Hinduja Mahim','Mumbai', now() - interval '26 day','floor_scratch','minor',2200,'paid',2200,2200,'resolved',4,2),
  ('2026-06-01','ENG-1789','bronze','Wockhardt Mira','Mumbai', now() - interval '28 day','wiring_damage','severe',38000,'approved',38000,38000,'accepted',14,7),
  ('2026-06-01','ENG-1854','gold','Max Saket','Delhi', now() - interval '3 day','cabinet_damage','minor',1900,'paid',1900,1900,'resolved',3,3),
  ('2026-06-01','ENG-1922','platinum','Medanta Gurgaon','Gurgaon', now() - interval '6 day','wall_dent','minor',1400,'paid',1400,1400,'resolved',2,2),
  ('2026-06-01','ENG-2018','silver','Columbia Asia Whitefield','Bangalore', now() - interval '11 day','ceiling_tile','moderate',5500,'adjusted',4000,4000,'accepted',5,5),
  ('2026-06-01','ENG-2018','silver','Aster CMI','Bangalore', now() - interval '15 day','equipment_drop','severe',52000,'pending',0,0,'escalated',16,NULL),
  ('2026-06-01','ENG-2144','bronze','MGM Healthcare','Chennai', now() - interval '19 day','flooring','major',14500,'disputed',0,0,'still_unhappy',9,NULL),
  ('2026-06-01','ENG-2144','bronze','SIMS Vadapalani','Chennai', now() - interval '23 day','door_damage','minor',2100,'paid',2100,2100,'resolved',3,3);

INSERT INTO engineer_damage_monthly_scorecard_r2894
  (scorecard_month, engineer_code, engineer_tier, jobs_completed, incidents_logged, damage_rate_pct, total_damage_rupees, total_clawback_rupees, net_payout_impact_rupees, training_required, warning_letter_issued, probation_status, coaching_session_count, trend_vs_prev_month)
VALUES
  ('2026-06-01','ENG-1042','gold',48,2,4.17,8300,8300,-8300,false,false,'clear',0,'flat'),
  ('2026-06-01','ENG-1183','silver',32,2,6.25,63500,0,0,true,true,'probation',2,'worsening'),
  ('2026-06-01','ENG-1207','bronze',26,2,7.69,10600,9700,-9700,true,false,'watch',1,'improving'),
  ('2026-06-01','ENG-1322','gold',55,2,3.64,11000,11000,-11000,false,false,'clear',0,'improving'),
  ('2026-06-01','ENG-1455','platinum',62,1,1.61,1600,1600,-1600,false,false,'clear',0,'flat'),
  ('2026-06-01','ENG-1612','silver',29,2,6.90,35500,0,0,true,true,'final_warning',3,'worsening'),
  ('2026-06-01','ENG-1789','bronze',24,2,8.33,40200,40200,-40200,true,false,'watch',2,'worsening'),
  ('2026-06-01','ENG-1854','gold',51,1,1.96,1900,1900,-1900,false,false,'clear',0,'improving'),
  ('2026-06-01','ENG-1922','platinum',68,1,1.47,1400,1400,-1400,false,false,'clear',0,'flat'),
  ('2026-06-01','ENG-2018','silver',31,2,6.45,57500,4000,-4000,true,true,'probation',2,'worsening'),
  ('2026-06-01','ENG-2144','bronze',22,2,9.09,16600,2100,-2100,true,true,'final_warning',3,'worsening'),
  ('2026-06-01','ENG-2299','gold',45,0,0.00,0,0,0,false,false,'clear',0,'improving'),
  ('2026-06-01','ENG-2401','platinum',71,0,0.00,0,0,0,false,false,'clear',0,'flat'),
  ('2026-06-01','ENG-2518','silver',33,1,3.03,2800,2800,-2800,false,false,'clear',0,'improving'),
  ('2026-06-01','ENG-2622','bronze',28,3,10.71,22400,12000,-12000,true,true,'terminated',4,'worsening');

-- ============================================================
-- RPC 1: KPI overview
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_kpi_overview()
RETURNS TABLE(total_incidents bigint, total_damage_rupees bigint, total_clawback_rupees bigint, engineers_on_probation bigint, severe_incidents bigint, pending_reimbursement bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*) FROM engineer_premises_damage_incidents_r2894),
      (SELECT coalesce(sum(damage_estimate_rupees),0)::bigint FROM engineer_premises_damage_incidents_r2894),
      (SELECT coalesce(sum(payout_clawback_rupees),0)::bigint FROM engineer_premises_damage_incidents_r2894),
      (SELECT count(*) FROM engineer_damage_monthly_scorecard_r2894 WHERE probation_status IN ('probation','final_warning','terminated')),
      (SELECT count(*) FROM engineer_premises_damage_incidents_r2894 WHERE severity = 'severe'),
      (SELECT count(*) FROM engineer_premises_damage_incidents_r2894 WHERE reimbursement_status = 'pending');
END;
$$;

-- ============================================================
-- RPC 2: Recent incidents
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_recent_incidents()
RETURNS SETOF engineer_premises_damage_incidents_r2894
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY SELECT * FROM engineer_premises_damage_incidents_r2894 ORDER BY incident_date DESC LIMIT 25;
END;
$$;

-- ============================================================
-- RPC 3: By engineer (worst offenders)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_worst_offenders()
RETURNS TABLE(engineer_code text, engineer_tier text, incidents bigint, total_damage_rupees bigint, total_clawback_rupees bigint, severe_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY
    SELECT
      i.engineer_code,
      i.engineer_tier,
      count(*)::bigint,
      coalesce(sum(i.damage_estimate_rupees),0)::bigint,
      coalesce(sum(i.payout_clawback_rupees),0)::bigint,
      count(*) FILTER (WHERE i.severity = 'severe')::bigint
    FROM engineer_premises_damage_incidents_r2894 i
    GROUP BY i.engineer_code, i.engineer_tier
    ORDER BY 4 DESC
    LIMIT 20;
END;
$$;

-- ============================================================
-- RPC 4: Severity breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_severity_breakdown()
RETURNS TABLE(severity text, incident_count bigint, total_damage_rupees bigint, avg_damage_rupees numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY
    SELECT
      i.severity,
      count(*)::bigint,
      coalesce(sum(i.damage_estimate_rupees),0)::bigint,
      round(avg(i.damage_estimate_rupees)::numeric,0)
    FROM engineer_premises_damage_incidents_r2894 i
    GROUP BY i.severity
    ORDER BY 3 DESC;
END;
$$;

-- ============================================================
-- RPC 5: Monthly scorecards on probation/warning
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_probation_scorecards()
RETURNS SETOF engineer_damage_monthly_scorecard_r2894
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY
    SELECT * FROM engineer_damage_monthly_scorecard_r2894
    WHERE probation_status IN ('watch','probation','final_warning','terminated')
    ORDER BY damage_rate_pct DESC;
END;
$$;

-- ============================================================
-- RPC 6: Incident type distribution
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_incident_type_distribution()
RETURNS TABLE(incident_type text, count bigint, total_rupees bigint, denied_disputed bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY
    SELECT
      i.incident_type,
      count(*)::bigint,
      coalesce(sum(i.damage_estimate_rupees),0)::bigint,
      count(*) FILTER (WHERE i.reimbursement_status IN ('denied','disputed'))::bigint
    FROM engineer_premises_damage_incidents_r2894 i
    GROUP BY i.incident_type
    ORDER BY 3 DESC;
END;
$$;

-- ============================================================
-- RPC 7: City-wise damage hotspots
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_city_hotspots()
RETURNS TABLE(city text, incidents bigint, total_damage_rupees bigint, unresolved bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY
    SELECT
      i.city,
      count(*)::bigint,
      coalesce(sum(i.damage_estimate_rupees),0)::bigint,
      count(*) FILTER (WHERE i.customer_satisfaction IN ('still_unhappy','escalated'))::bigint
    FROM engineer_premises_damage_incidents_r2894 i
    GROUP BY i.city
    ORDER BY 3 DESC;
END;
$$;

-- ============================================================
-- RPC 8: Trend analysis (improving vs worsening)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2894_trend_analysis()
RETURNS TABLE(trend text, engineer_count bigint, avg_damage_rate numeric, total_clawback bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not_authorized'; END IF;
  RETURN QUERY
    SELECT
      s.trend_vs_prev_month,
      count(*)::bigint,
      round(avg(s.damage_rate_pct)::numeric,2),
      coalesce(sum(s.total_clawback_rupees),0)::bigint
    FROM engineer_damage_monthly_scorecard_r2894 s
    GROUP BY s.trend_vs_prev_month
    ORDER BY 3 DESC;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE EXECUTE ON FUNCTION founder_r2894_kpi_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2894_recent_incidents() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2894_worst_offenders() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2894_severity_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2894_probation_scorecards() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2894_incident_type_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2894_city_hotspots() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2894_trend_analysis() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2894_kpi_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2894_recent_incidents() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2894_worst_offenders() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2894_severity_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2894_probation_scorecards() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2894_incident_type_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2894_city_hotspots() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2894_trend_analysis() TO authenticated;

COMMIT;
