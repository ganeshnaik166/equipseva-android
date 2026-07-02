-- Round 2912: Customer Monthly Engineer After-Hours WhatsApp-Response Latency
-- Heavy founder ops round. 2 tables + 7 RPCs.

CREATE TABLE IF NOT EXISTS after_hours_wa_messages_r2912 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  month_label text NOT NULL,
  customer_org text NOT NULL,
  customer_city text NOT NULL,
  engineer_code text NOT NULL,
  engineer_tier text NOT NULL,
  message_sent_at timestamptz NOT NULL,
  first_response_at timestamptz,
  latency_minutes numeric(10,2),
  message_window text NOT NULL,
  issue_severity text NOT NULL,
  sla_target_minutes int NOT NULL,
  breached_sla boolean NOT NULL DEFAULT false,
  customer_csat smallint
);
ALTER TABLE after_hours_wa_messages_r2912 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS after_hours_wa_engineer_scorecard_r2912 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  month_label text NOT NULL,
  engineer_code text NOT NULL,
  engineer_tier text NOT NULL,
  messages_received int NOT NULL,
  messages_responded int NOT NULL,
  avg_latency_minutes numeric(10,2) NOT NULL,
  p90_latency_minutes numeric(10,2) NOT NULL,
  sla_breaches int NOT NULL,
  customer_complaints int NOT NULL,
  incentive_bonus_rupees int NOT NULL,
  penalty_rupees int NOT NULL,
  rank_in_tier int NOT NULL
);
ALTER TABLE after_hours_wa_engineer_scorecard_r2912 ENABLE ROW LEVEL SECURITY;

-- Seeds: messages
INSERT INTO after_hours_wa_messages_r2912 (month_label, customer_org, customer_city, engineer_code, engineer_tier, message_sent_at, first_response_at, latency_minutes, message_window, issue_severity, sla_target_minutes, breached_sla, customer_csat) VALUES
('Jun 2026','Apollo Jubilee','Hyderabad','ENG-A21','platinum','2026-06-02 22:14:00+05:30'::timestamptz,'2026-06-02 22:21:00+05:30'::timestamptz,7.00,'late_night','p1',15,false,5),
('Jun 2026','Yashoda Hitec City','Hyderabad','ENG-A22','gold','2026-06-03 23:48:00+05:30'::timestamptz,'2026-06-04 00:31:00+05:30'::timestamptz,43.00,'late_night','p2',30,true,3),
('Jun 2026','KIMS Secunderabad','Hyderabad','ENG-A23','silver','2026-06-05 21:05:00+05:30'::timestamptz,'2026-06-05 21:18:00+05:30'::timestamptz,13.00,'evening','p2',30,false,4),
('Jun 2026','Continental Gachibowli','Hyderabad','ENG-A24','platinum','2026-06-06 02:11:00+05:30'::timestamptz,'2026-06-06 02:14:00+05:30'::timestamptz,3.00,'late_night','p0',10,false,5),
('Jun 2026','Care Banjara','Hyderabad','ENG-A25','gold','2026-06-08 22:55:00+05:30'::timestamptz,'2026-06-08 23:46:00+05:30'::timestamptz,51.00,'late_night','p1',15,true,2),
('Jun 2026','Star Begumpet','Hyderabad','ENG-A26','silver','2026-06-09 20:42:00+05:30'::timestamptz,'2026-06-09 21:02:00+05:30'::timestamptz,20.00,'evening','p2',30,false,4),
('Jun 2026','Sunshine Paradise','Hyderabad','ENG-A27','platinum','2026-06-11 23:30:00+05:30'::timestamptz,'2026-06-11 23:38:00+05:30'::timestamptz,8.00,'late_night','p1',15,false,5),
('Jun 2026','MaxCure Madhapur','Hyderabad','ENG-A28','bronze','2026-06-12 22:18:00+05:30'::timestamptz,'2026-06-12 23:55:00+05:30'::timestamptz,97.00,'late_night','p2',30,true,2),
('Jun 2026','Citizens Nallagandla','Hyderabad','ENG-A29','gold','2026-06-14 21:22:00+05:30'::timestamptz,'2026-06-14 21:34:00+05:30'::timestamptz,12.00,'evening','p1',15,false,4),
('Jun 2026','Olive Mehdipatnam','Hyderabad','ENG-A30','silver','2026-06-15 23:11:00+05:30'::timestamptz,'2026-06-15 23:48:00+05:30'::timestamptz,37.00,'late_night','p2',30,true,3),
('Jun 2026','Aware Gachibowli','Hyderabad','ENG-A21','platinum','2026-06-17 22:01:00+05:30'::timestamptz,'2026-06-17 22:07:00+05:30'::timestamptz,6.00,'late_night','p0',10,false,5),
('Jun 2026','Sunshine Secunderabad','Hyderabad','ENG-A22','gold','2026-06-18 20:33:00+05:30'::timestamptz,'2026-06-18 20:55:00+05:30'::timestamptz,22.00,'evening','p2',30,false,4),
('Jun 2026','Renova Begumpet','Hyderabad','ENG-A23','silver','2026-06-19 23:44:00+05:30'::timestamptz,NULL,180.00,'late_night','p1',15,true,1),
('Jun 2026','Virinchi LB Nagar','Hyderabad','ENG-A24','platinum','2026-06-20 21:14:00+05:30'::timestamptz,'2026-06-20 21:19:00+05:30'::timestamptz,5.00,'evening','p1',15,false,5),
('Jun 2026','Pranaam Madhapur','Hyderabad','ENG-A25','gold','2026-06-21 22:50:00+05:30'::timestamptz,'2026-06-21 23:25:00+05:30'::timestamptz,35.00,'late_night','p2',30,true,3),
('Jun 2026','Yashoda Somajiguda','Hyderabad','ENG-A26','silver','2026-06-23 02:30:00+05:30'::timestamptz,'2026-06-23 02:55:00+05:30'::timestamptz,25.00,'late_night','p2',30,false,4),
('Jun 2026','Apollo DRDO','Hyderabad','ENG-A27','platinum','2026-06-25 23:01:00+05:30'::timestamptz,'2026-06-25 23:11:00+05:30'::timestamptz,10.00,'late_night','p1',15,false,5),
('Jun 2026','KIMS Kondapur','Hyderabad','ENG-A28','bronze','2026-06-27 21:55:00+05:30'::timestamptz,'2026-06-27 23:18:00+05:30'::timestamptz,83.00,'late_night','p2',30,true,2),
('Jun 2026','Aster Prime','Hyderabad','ENG-A29','gold','2026-06-28 22:22:00+05:30'::timestamptz,'2026-06-28 22:36:00+05:30'::timestamptz,14.00,'late_night','p1',15,true,3),
('Jun 2026','Citizens Serilingampally','Hyderabad','ENG-A30','silver','2026-06-30 23:59:00+05:30'::timestamptz,'2026-07-01 00:48:00+05:30'::timestamptz,49.00,'late_night','p2',30,true,2);

-- Seeds: engineer scorecard
INSERT INTO after_hours_wa_engineer_scorecard_r2912 (month_label, engineer_code, engineer_tier, messages_received, messages_responded, avg_latency_minutes, p90_latency_minutes, sla_breaches, customer_complaints, incentive_bonus_rupees, penalty_rupees, rank_in_tier) VALUES
('Jun 2026','ENG-A21','platinum',24,24,6.50,11.20,0,0,4500,0,1),
('Jun 2026','ENG-A22','gold',22,21,28.40,49.00,5,2,1200,800,4),
('Jun 2026','ENG-A23','silver',19,17,42.00,180.00,7,3,0,2400,7),
('Jun 2026','ENG-A24','platinum',26,26,4.20,8.00,0,0,5000,0,2),
('Jun 2026','ENG-A25','gold',20,20,30.10,55.00,6,2,800,1200,5),
('Jun 2026','ENG-A26','silver',18,18,22.40,38.00,2,1,1500,400,2),
('Jun 2026','ENG-A27','platinum',21,21,8.90,14.00,0,0,4200,0,3),
('Jun 2026','ENG-A28','bronze',15,14,68.00,97.00,8,4,0,3200,9),
('Jun 2026','ENG-A29','gold',23,22,18.20,35.00,3,1,2200,600,3),
('Jun 2026','ENG-A30','silver',17,16,38.50,49.00,5,2,400,1600,5),
('Jun 2026','ENG-A31','platinum',19,19,7.10,12.50,0,0,4000,0,4),
('Jun 2026','ENG-A32','gold',24,23,21.00,42.00,4,1,1800,800,2),
('Jun 2026','ENG-A33','silver',16,15,33.00,55.00,4,2,600,1200,4),
('Jun 2026','ENG-A34','bronze',13,12,72.00,110.00,7,3,0,2800,8),
('Jun 2026','ENG-A35','platinum',22,22,5.80,9.50,0,0,4600,0,5);

-- Helper for is_founder; if not present, define a stub-safe call
-- (Assumes is_founder() already exists in this project.)

-- RPC 1: KPI summary
CREATE OR REPLACE FUNCTION founder_r2912_kpi_summary()
RETURNS TABLE(metric text, value text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'total_after_hours_messages'::text, COUNT(*)::text FROM after_hours_wa_messages_r2912
  UNION ALL SELECT 'avg_latency_min', ROUND(AVG(latency_minutes),2)::text FROM after_hours_wa_messages_r2912
  UNION ALL SELECT 'p90_latency_min', ROUND(percentile_cont(0.9) WITHIN GROUP (ORDER BY latency_minutes)::numeric,2)::text FROM after_hours_wa_messages_r2912
  UNION ALL SELECT 'sla_breach_count', COUNT(*) FILTER (WHERE breached_sla)::text FROM after_hours_wa_messages_r2912
  UNION ALL SELECT 'sla_breach_pct', ROUND(100.0*COUNT(*) FILTER (WHERE breached_sla)/NULLIF(COUNT(*),0),2)::text FROM after_hours_wa_messages_r2912
  UNION ALL SELECT 'avg_csat', ROUND(AVG(customer_csat),2)::text FROM after_hours_wa_messages_r2912;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_kpi_summary() TO authenticated;

-- RPC 2: top breachers
CREATE OR REPLACE FUNCTION founder_r2912_top_breachers()
RETURNS TABLE(engineer_code text, engineer_tier text, sla_breaches int, avg_latency_minutes numeric, penalty_rupees int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_tier, s.sla_breaches, s.avg_latency_minutes, s.penalty_rupees
  FROM after_hours_wa_engineer_scorecard_r2912 s
  ORDER BY s.sla_breaches DESC, s.avg_latency_minutes DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_top_breachers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_top_breachers() TO authenticated;

-- RPC 3: tier roll-up
CREATE OR REPLACE FUNCTION founder_r2912_tier_rollup()
RETURNS TABLE(engineer_tier text, eng_count bigint, avg_latency numeric, total_breaches bigint, total_bonus bigint, total_penalty bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_tier, COUNT(*)::bigint, ROUND(AVG(s.avg_latency_minutes),2),
         SUM(s.sla_breaches)::bigint, SUM(s.incentive_bonus_rupees)::bigint, SUM(s.penalty_rupees)::bigint
  FROM after_hours_wa_engineer_scorecard_r2912 s
  GROUP BY s.engineer_tier
  ORDER BY avg_latency ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_tier_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_tier_rollup() TO authenticated;

-- RPC 4: late-night vs evening latency
CREATE OR REPLACE FUNCTION founder_r2912_window_split()
RETURNS TABLE(message_window text, msg_count bigint, avg_latency numeric, breach_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.message_window, COUNT(*)::bigint, ROUND(AVG(m.latency_minutes),2),
         ROUND(100.0*COUNT(*) FILTER (WHERE m.breached_sla)/NULLIF(COUNT(*),0),2)
  FROM after_hours_wa_messages_r2912 m
  GROUP BY m.message_window
  ORDER BY avg_latency DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_window_split() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_window_split() TO authenticated;

-- RPC 5: customer org pain
CREATE OR REPLACE FUNCTION founder_r2912_customer_pain()
RETURNS TABLE(customer_org text, msg_count bigint, breached bigint, avg_csat numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.customer_org, COUNT(*)::bigint, COUNT(*) FILTER (WHERE m.breached_sla)::bigint, ROUND(AVG(m.customer_csat),2)
  FROM after_hours_wa_messages_r2912 m
  GROUP BY m.customer_org
  ORDER BY breached DESC, msg_count DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_customer_pain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_customer_pain() TO authenticated;

-- RPC 6: severity heatmap
CREATE OR REPLACE FUNCTION founder_r2912_severity_heatmap()
RETURNS TABLE(issue_severity text, sla_target_minutes int, msg_count bigint, avg_latency numeric, breaches bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.issue_severity, m.sla_target_minutes, COUNT(*)::bigint, ROUND(AVG(m.latency_minutes),2), COUNT(*) FILTER (WHERE m.breached_sla)::bigint
  FROM after_hours_wa_messages_r2912 m
  GROUP BY m.issue_severity, m.sla_target_minutes
  ORDER BY m.issue_severity;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_severity_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_severity_heatmap() TO authenticated;

-- RPC 7: leaderboard top performers
CREATE OR REPLACE FUNCTION founder_r2912_top_performers()
RETURNS TABLE(engineer_code text, engineer_tier text, avg_latency_minutes numeric, incentive_bonus_rupees int, rank_in_tier int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_tier, s.avg_latency_minutes, s.incentive_bonus_rupees, s.rank_in_tier
  FROM after_hours_wa_engineer_scorecard_r2912 s
  WHERE s.sla_breaches = 0
  ORDER BY s.avg_latency_minutes ASC, s.incentive_bonus_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_top_performers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_top_performers() TO authenticated;

-- RPC 8: unresponded messages
CREATE OR REPLACE FUNCTION founder_r2912_unresponded()
RETURNS TABLE(customer_org text, engineer_code text, message_sent_at timestamptz, issue_severity text, sla_target_minutes int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.customer_org, m.engineer_code, m.message_sent_at, m.issue_severity, m.sla_target_minutes
  FROM after_hours_wa_messages_r2912 m
  WHERE m.first_response_at IS NULL
  ORDER BY m.message_sent_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2912_unresponded() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2912_unresponded() TO authenticated;
