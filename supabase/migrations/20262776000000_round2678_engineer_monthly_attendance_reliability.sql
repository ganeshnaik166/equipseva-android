BEGIN;

-- Round r2678: Engineer Monthly Attendance Reliability

DROP TABLE IF EXISTS engineer_attendance_consequences_r2678 CASCADE;
DROP TABLE IF EXISTS engineer_monthly_attendance_r2678 CASCADE;

CREATE TABLE engineer_monthly_attendance_r2678 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  month_label text NOT NULL,
  scheduled_jobs int NOT NULL CHECK (scheduled_jobs >= 0),
  completed_jobs int NOT NULL CHECK (completed_jobs >= 0),
  no_show_jobs int NOT NULL CHECK (no_show_jobs >= 0),
  late_jobs int NOT NULL CHECK (late_jobs >= 0),
  reliability_pct numeric(5,2) NOT NULL CHECK (reliability_pct >= 0 AND reliability_pct <= 100),
  reliability_tier text NOT NULL CHECK (reliability_tier IN ('platinum','gold','silver','bronze','watchlist')),
  primary_reason text NOT NULL CHECK (primary_reason IN ('on_time','traffic','illness','spare_part_delay','customer_reschedule','no_reason','personal_emergency')),
  status text NOT NULL CHECK (status IN ('green','amber','red')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_attendance_r2678 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_attendance_r2678;
CREATE POLICY founder_all ON engineer_monthly_attendance_r2678 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_attendance_r2678 (engineer_name, engineer_code, month_label, scheduled_jobs, completed_jobs, no_show_jobs, late_jobs, reliability_pct, reliability_tier, primary_reason, status) VALUES
('Ravi Kumar','ENG-001','2026-05',48,47,0,1,97.92,'platinum','on_time','green'),
('Suresh Babu','ENG-002','2026-05',52,49,1,2,94.23,'gold','traffic','green'),
('Anil Reddy','ENG-003','2026-05',45,40,3,2,88.89,'silver','spare_part_delay','amber'),
('Mahesh Rao','ENG-004','2026-05',50,42,5,3,84.00,'bronze','illness','amber'),
('Vinod Sharma','ENG-005','2026-05',46,36,7,3,78.26,'watchlist','no_reason','red'),
('Kiran Goud','ENG-006','2026-05',44,43,0,1,97.73,'platinum','on_time','green'),
('Praveen Naidu','ENG-007','2026-05',49,38,8,3,77.55,'watchlist','personal_emergency','red');

CREATE TABLE engineer_attendance_consequences_r2678 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  month_label text NOT NULL,
  consequence_type text NOT NULL CHECK (consequence_type IN ('bonus','warning','probation','suspension','termination_notice','recognition')),
  amount_rupees int NOT NULL CHECK (amount_rupees >= 0),
  notes text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL CHECK (status IN ('pending','applied','reversed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_attendance_consequences_r2678 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_attendance_consequences_r2678;
CREATE POLICY founder_all ON engineer_attendance_consequences_r2678 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_attendance_consequences_r2678 (engineer_code, month_label, consequence_type, amount_rupees, notes, status) VALUES
('ENG-001','2026-05','bonus',5000,'Platinum reliability bonus','applied'),
('ENG-002','2026-05','recognition',2000,'Gold tier recognition payout','applied'),
('ENG-003','2026-05','warning',0,'First written warning for 3 no-shows','applied'),
('ENG-004','2026-05','warning',0,'Second warning issued','applied'),
('ENG-005','2026-05','probation',0,'30-day probation begins 2026-06-01','applied'),
('ENG-006','2026-05','bonus',5000,'Platinum reliability bonus','applied'),
('ENG-007','2026-05','suspension',0,'7-day suspension for 8 no-shows','pending');

-- RPC 1: list monthly attendance
DROP FUNCTION IF EXISTS founder_attendance_list_r2678();
CREATE FUNCTION founder_attendance_list_r2678()
RETURNS SETOF engineer_monthly_attendance_r2678
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_monthly_attendance_r2678 ORDER BY reliability_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_list_r2678() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_list_r2678() TO authenticated;

-- RPC 2: list consequences
DROP FUNCTION IF EXISTS founder_attendance_consequences_r2678();
CREATE FUNCTION founder_attendance_consequences_r2678()
RETURNS SETOF engineer_attendance_consequences_r2678
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_attendance_consequences_r2678 ORDER BY applied_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_consequences_r2678() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_consequences_r2678() TO authenticated;

-- RPC 3: KPI summary
DROP FUNCTION IF EXISTS founder_attendance_kpis_r2678();
CREATE FUNCTION founder_attendance_kpis_r2678()
RETURNS TABLE(total_engineers int, total_scheduled int, total_completed int, total_no_shows int, avg_reliability numeric, watchlist_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int,
         COALESCE(SUM(scheduled_jobs),0)::int,
         COALESCE(SUM(completed_jobs),0)::int,
         COALESCE(SUM(no_show_jobs),0)::int,
         COALESCE(ROUND(AVG(reliability_pct),2),0),
         COUNT(*) FILTER (WHERE reliability_tier = 'watchlist')::int
  FROM engineer_monthly_attendance_r2678;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_kpis_r2678() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_kpis_r2678() TO authenticated;

-- RPC 4: tier breakdown
DROP FUNCTION IF EXISTS founder_attendance_tier_breakdown_r2678();
CREATE FUNCTION founder_attendance_tier_breakdown_r2678()
RETURNS TABLE(reliability_tier text, engineer_count int, avg_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.reliability_tier, COUNT(*)::int, ROUND(AVG(a.reliability_pct),2)
  FROM engineer_monthly_attendance_r2678 a
  GROUP BY a.reliability_tier
  ORDER BY AVG(a.reliability_pct) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_tier_breakdown_r2678() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_tier_breakdown_r2678() TO authenticated;

-- RPC 5: reason breakdown
DROP FUNCTION IF EXISTS founder_attendance_reason_breakdown_r2678();
CREATE FUNCTION founder_attendance_reason_breakdown_r2678()
RETURNS TABLE(primary_reason text, occurrence_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.primary_reason, COUNT(*)::int
  FROM engineer_monthly_attendance_r2678 a
  GROUP BY a.primary_reason
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_reason_breakdown_r2678() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_reason_breakdown_r2678() TO authenticated;

-- RPC 6: watchlist
DROP FUNCTION IF EXISTS founder_attendance_watchlist_r2678();
CREATE FUNCTION founder_attendance_watchlist_r2678()
RETURNS SETOF engineer_monthly_attendance_r2678
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_monthly_attendance_r2678
  WHERE status = 'red' OR reliability_tier = 'watchlist'
  ORDER BY reliability_pct ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_watchlist_r2678() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_watchlist_r2678() TO authenticated;

-- RPC 7: bonus payout total
DROP FUNCTION IF EXISTS founder_attendance_bonus_total_r2678();
CREATE FUNCTION founder_attendance_bonus_total_r2678()
RETURNS TABLE(consequence_type text, count_rows int, total_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.consequence_type, COUNT(*)::int, COALESCE(SUM(c.amount_rupees),0)::bigint
  FROM engineer_attendance_consequences_r2678 c
  GROUP BY c.consequence_type
  ORDER BY SUM(c.amount_rupees) DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_bonus_total_r2678() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_bonus_total_r2678() TO authenticated;

-- RPC 8: apply consequence
DROP FUNCTION IF EXISTS founder_attendance_apply_consequence_r2678(text, text, text, int, text);
CREATE FUNCTION founder_attendance_apply_consequence_r2678(p_engineer_code text, p_month text, p_type text, p_amount int, p_notes text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_attendance_consequences_r2678 (engineer_code, month_label, consequence_type, amount_rupees, notes, status)
  VALUES (p_engineer_code, p_month, p_type, p_amount, p_notes, 'pending')
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_attendance_apply_consequence_r2678(text, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_attendance_apply_consequence_r2678(text, text, text, int, text) TO authenticated;

COMMIT;
