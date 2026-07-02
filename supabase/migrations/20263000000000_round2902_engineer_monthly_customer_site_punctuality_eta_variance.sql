-- Round 2902: Engineer Monthly Customer Site Punctuality & ETA-vs-Actual Variance
-- BATCH 400 MILESTONE

CREATE TABLE engineer_monthly_punctuality_r2902 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  engineer_id uuid,
  engineer_code text not null,
  month_label text not null,
  total_visits int not null,
  on_time_visits int not null,
  late_visits int not null,
  early_visits int not null,
  avg_eta_minutes int not null,
  avg_actual_minutes int not null,
  variance_minutes int not null,
  punctuality_pct numeric(5,2) not null,
  tier text not null
);
ALTER TABLE engineer_monthly_punctuality_r2902 ENABLE ROW LEVEL SECURITY;

CREATE TABLE engineer_site_visit_eta_r2902 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  engineer_code text not null,
  hospital_name text not null,
  city text not null,
  scheduled_at timestamptz not null,
  eta_promised_at timestamptz not null,
  actual_arrival_at timestamptz not null,
  variance_minutes int not null,
  status text not null,
  customer_rating int,
  notes text
);
ALTER TABLE engineer_site_visit_eta_r2902 ENABLE ROW LEVEL SECURITY;

-- Seeds
INSERT INTO engineer_monthly_punctuality_r2902 (engineer_code, month_label, total_visits, on_time_visits, late_visits, early_visits, avg_eta_minutes, avg_actual_minutes, variance_minutes, punctuality_pct, tier) VALUES
('ENG-A01','2026-06',42,38,3,1,45,47,2,90.48,'gold'),
('ENG-A02','2026-06',38,30,7,1,40,55,15,78.95,'silver'),
('ENG-A03','2026-06',51,49,1,1,35,36,1,96.08,'platinum'),
('ENG-A04','2026-06',29,20,8,1,50,68,18,68.97,'bronze'),
('ENG-A05','2026-06',33,31,1,1,42,44,2,93.94,'gold'),
('ENG-A06','2026-06',47,40,6,1,38,49,11,85.11,'silver'),
('ENG-A07','2026-06',22,15,6,1,55,72,17,68.18,'bronze'),
('ENG-A08','2026-06',44,42,1,1,40,41,1,95.45,'platinum'),
('ENG-A09','2026-06',36,32,3,1,45,48,3,88.89,'gold'),
('ENG-A10','2026-06',40,35,4,1,42,49,7,87.50,'silver'),
('ENG-A11','2026-06',25,18,6,1,50,65,15,72.00,'bronze'),
('ENG-A12','2026-06',48,46,1,1,38,39,1,95.83,'platinum'),
('ENG-A13','2026-06',31,28,2,1,44,46,2,90.32,'gold'),
('ENG-A14','2026-06',39,33,5,1,40,51,11,84.62,'silver'),
('ENG-A15','2026-06',27,19,7,1,52,69,17,70.37,'bronze');

INSERT INTO engineer_site_visit_eta_r2902 (engineer_code, hospital_name, city, scheduled_at, eta_promised_at, actual_arrival_at, variance_minutes, status, customer_rating, notes) VALUES
('ENG-A01','Apollo Jubilee','Hyderabad','2026-06-15 10:00'::timestamptz,'2026-06-15 10:00'::timestamptz,'2026-06-15 10:02'::timestamptz,2,'on_time',5,'Smooth'),
('ENG-A02','Fortis BG Road','Bangalore','2026-06-15 11:30'::timestamptz,'2026-06-15 11:30'::timestamptz,'2026-06-15 11:48'::timestamptz,18,'late',3,'Traffic'),
('ENG-A03','Manipal Whitefield','Bangalore','2026-06-16 09:00'::timestamptz,'2026-06-16 09:00'::timestamptz,'2026-06-16 08:59'::timestamptz,-1,'on_time',5,'Early'),
('ENG-A04','KIMS Secunderabad','Hyderabad','2026-06-16 14:00'::timestamptz,'2026-06-16 14:00'::timestamptz,'2026-06-16 14:25'::timestamptz,25,'late',2,'Stuck'),
('ENG-A05','Yashoda Somajiguda','Hyderabad','2026-06-17 10:30'::timestamptz,'2026-06-17 10:30'::timestamptz,'2026-06-17 10:31'::timestamptz,1,'on_time',5,'Excellent'),
('ENG-A06','Narayana Health','Bangalore','2026-06-17 13:00'::timestamptz,'2026-06-17 13:00'::timestamptz,'2026-06-17 13:12'::timestamptz,12,'late',4,'Minor delay'),
('ENG-A07','Continental Gachibowli','Hyderabad','2026-06-18 11:00'::timestamptz,'2026-06-18 11:00'::timestamptz,'2026-06-18 11:30'::timestamptz,30,'late',2,'Customer upset'),
('ENG-A08','AIG Hospitals','Hyderabad','2026-06-18 15:00'::timestamptz,'2026-06-18 15:00'::timestamptz,'2026-06-18 15:01'::timestamptz,1,'on_time',5,'Perfect'),
('ENG-A09','Sakra World','Bangalore','2026-06-19 09:30'::timestamptz,'2026-06-19 09:30'::timestamptz,'2026-06-19 09:35'::timestamptz,5,'on_time',5,'Good'),
('ENG-A10','Aster CMI','Bangalore','2026-06-19 12:00'::timestamptz,'2026-06-19 12:00'::timestamptz,'2026-06-19 12:10'::timestamptz,10,'late',4,'Light delay'),
('ENG-A11','Care Banjara','Hyderabad','2026-06-20 10:00'::timestamptz,'2026-06-20 10:00'::timestamptz,'2026-06-20 10:28'::timestamptz,28,'late',2,'Apologized'),
('ENG-A12','Rainbow Childrens','Hyderabad','2026-06-20 14:30'::timestamptz,'2026-06-20 14:30'::timestamptz,'2026-06-20 14:30'::timestamptz,0,'on_time',5,'Spot on'),
('ENG-A13','Columbia Asia','Bangalore','2026-06-21 11:00'::timestamptz,'2026-06-21 11:00'::timestamptz,'2026-06-21 11:04'::timestamptz,4,'on_time',5,'Quick'),
('ENG-A14','Sparsh Hospital','Bangalore','2026-06-21 13:30'::timestamptz,'2026-06-21 13:30'::timestamptz,'2026-06-21 13:50'::timestamptz,20,'late',3,'Customer ok'),
('ENG-A15','Sunshine Paradise','Hyderabad','2026-06-22 09:00'::timestamptz,'2026-06-22 09:00'::timestamptz,'2026-06-22 09:32'::timestamptz,32,'late',1,'Escalation');

-- RPC 1
CREATE OR REPLACE FUNCTION rpc_r2902_monthly_summary()
RETURNS TABLE(engineer_code text, month_label text, total_visits int, punctuality_pct numeric, variance_minutes int, tier text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.engineer_code, m.month_label, m.total_visits, m.punctuality_pct, m.variance_minutes, m.tier
    FROM engineer_monthly_punctuality_r2902 m ORDER BY m.punctuality_pct DESC;
END $$;

-- RPC 2
CREATE OR REPLACE FUNCTION rpc_r2902_top_punctual()
RETURNS TABLE(engineer_code text, punctuality_pct numeric, on_time_visits int, total_visits int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.engineer_code, m.punctuality_pct, m.on_time_visits, m.total_visits
    FROM engineer_monthly_punctuality_r2902 m ORDER BY m.punctuality_pct DESC LIMIT 5;
END $$;

-- RPC 3
CREATE OR REPLACE FUNCTION rpc_r2902_chronic_late()
RETURNS TABLE(engineer_code text, late_visits int, variance_minutes int, punctuality_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.engineer_code, m.late_visits, m.variance_minutes, m.punctuality_pct
    FROM engineer_monthly_punctuality_r2902 m WHERE m.punctuality_pct < 80 ORDER BY m.punctuality_pct ASC;
END $$;

-- RPC 4
CREATE OR REPLACE FUNCTION rpc_r2902_variance_by_tier()
RETURNS TABLE(tier text, engineer_count bigint, avg_variance numeric, avg_punctuality numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.tier, count(*)::bigint, round(avg(m.variance_minutes)::numeric,2), round(avg(m.punctuality_pct)::numeric,2)
    FROM engineer_monthly_punctuality_r2902 m GROUP BY m.tier ORDER BY avg(m.punctuality_pct) DESC;
END $$;

-- RPC 5
CREATE OR REPLACE FUNCTION rpc_r2902_recent_visits()
RETURNS TABLE(engineer_code text, hospital_name text, city text, scheduled_at timestamptz, variance_minutes int, status text, customer_rating int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT v.engineer_code, v.hospital_name, v.city, v.scheduled_at, v.variance_minutes, v.status, v.customer_rating
    FROM engineer_site_visit_eta_r2902 v ORDER BY v.scheduled_at DESC LIMIT 20;
END $$;

-- RPC 6
CREATE OR REPLACE FUNCTION rpc_r2902_late_visits_30plus()
RETURNS TABLE(engineer_code text, hospital_name text, variance_minutes int, customer_rating int, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT v.engineer_code, v.hospital_name, v.variance_minutes, v.customer_rating, v.notes
    FROM engineer_site_visit_eta_r2902 v WHERE v.variance_minutes >= 25 ORDER BY v.variance_minutes DESC;
END $$;

-- RPC 7
CREATE OR REPLACE FUNCTION rpc_r2902_kpis()
RETURNS TABLE(total_engineers bigint, avg_punctuality numeric, avg_variance numeric, total_visits bigint, late_visits_total bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT count(*)::bigint, round(avg(m.punctuality_pct)::numeric,2), round(avg(m.variance_minutes)::numeric,2),
    sum(m.total_visits)::bigint, sum(m.late_visits)::bigint FROM engineer_monthly_punctuality_r2902 m;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2902_monthly_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2902_top_punctual() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2902_chronic_late() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2902_variance_by_tier() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2902_recent_visits() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2902_late_visits_30plus() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2902_kpis() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_r2902_monthly_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2902_top_punctual() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2902_chronic_late() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2902_variance_by_tier() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2902_recent_visits() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2902_late_visits_30plus() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2902_kpis() TO authenticated;
