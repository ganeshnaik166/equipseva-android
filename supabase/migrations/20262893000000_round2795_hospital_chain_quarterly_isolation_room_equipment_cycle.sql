BEGIN;

-- =========================================================================
-- Round 2795 — Hospital Chain Quarterly Isolation Room Equipment Cycle
-- chain × isolation room × biohazard equipment × decontam × cycles × outcome
-- =========================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_isolation_rooms_r2795 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code      text NOT NULL,
  hospital_name   text NOT NULL,
  city            text NOT NULL,
  room_code       text NOT NULL,
  room_class      text NOT NULL CHECK (room_class IN ('airborne_negative','protective_positive','combined_anteroom','bsl3_lab')),
  bed_count       int  NOT NULL CHECK (bed_count BETWEEN 1 AND 20),
  hepa_pass_rate_pct numeric(5,2) NOT NULL CHECK (hepa_pass_rate_pct BETWEEN 0 AND 100),
  last_audit_date date NOT NULL,
  quarter_tag     text NOT NULL CHECK (quarter_tag IN ('q1_2026','q2_2026','q3_2026','q4_2026')),
  status          text NOT NULL CHECK (status IN ('active','suspended','retired')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_isolation_rooms_r2795 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON hospital_chain_isolation_rooms_r2795
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_isolation_rooms_r2795
  (chain_code,hospital_name,city,room_code,room_class,bed_count,hepa_pass_rate_pct,last_audit_date,quarter_tag,status,notes) VALUES
  ('APOLLO','Apollo Jubilee','Hyderabad','ISO-A14','airborne_negative',4,99.10,'2026-05-12'::date,'q2_2026','active','TB ward, twin anteroom'),
  ('FORTIS','Fortis Anandapur','Kolkata','ISO-B07','protective_positive',2,98.45,'2026-04-28'::date,'q2_2026','active','BMT recovery'),
  ('MAX','Max Saket','Delhi','ISO-C22','combined_anteroom',6,97.80,'2026-06-02'::date,'q2_2026','active','COVID legacy retrofit'),
  ('MANIPAL','Manipal Whitefield','Bengaluru','ISO-D03','bsl3_lab',1,99.85,'2026-03-19'::date,'q1_2026','active','clinical micro lab'),
  ('NARAYANA','Narayana Bommasandra','Bengaluru','ISO-E11','airborne_negative',3,92.10,'2026-05-30'::date,'q2_2026','suspended','HEPA breach pending fix'),
  ('MEDANTA','Medanta Gurgaon','Gurgaon','ISO-F18','protective_positive',4,99.40,'2026-06-08'::date,'q2_2026','active','transplant ICU');

CREATE TABLE IF NOT EXISTS isolation_decontam_cycles_r2795 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id         uuid NOT NULL REFERENCES hospital_chain_isolation_rooms_r2795(id) ON DELETE CASCADE,
  cycle_code      text NOT NULL,
  equipment_kind  text NOT NULL CHECK (equipment_kind IN ('hepa_filter','uvgi_lamp','vhp_generator','negative_pressure_sensor','pass_through_autoclave','biosafety_cabinet')),
  cycle_started   timestamptz NOT NULL,
  cycle_minutes   int  NOT NULL CHECK (cycle_minutes BETWEEN 5 AND 720),
  decontam_method text NOT NULL CHECK (decontam_method IN ('vhp_fumigation','uvgi_pulse','chlorine_dioxide','formaldehyde_legacy','combined')),
  outcome         text NOT NULL CHECK (outcome IN ('pass','fail','partial','rerun_required')),
  spore_log_kill  numeric(4,2) NOT NULL CHECK (spore_log_kill BETWEEN 0 AND 9),
  technician      text NOT NULL,
  cost_rupees     int  NOT NULL CHECK (cost_rupees BETWEEN 0 AND 1000000),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE isolation_decontam_cycles_r2795 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON isolation_decontam_cycles_r2795
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO isolation_decontam_cycles_r2795
  (room_id,cycle_code,equipment_kind,cycle_started,cycle_minutes,decontam_method,outcome,spore_log_kill,technician,cost_rupees,notes)
SELECT id,'CY-2795-001','vhp_generator','2026-06-10 02:00+05:30'::timestamptz,180,'vhp_fumigation','pass',6.10,'Ramesh K',18500,'quarterly cycle' FROM hospital_chain_isolation_rooms_r2795 WHERE room_code='ISO-A14'
UNION ALL SELECT id,'CY-2795-002','hepa_filter','2026-06-11 06:30+05:30'::timestamptz,45,'uvgi_pulse','pass',5.80,'Suresh P',4200,'filter swap clean' FROM hospital_chain_isolation_rooms_r2795 WHERE room_code='ISO-B07'
UNION ALL SELECT id,'CY-2795-003','biosafety_cabinet','2026-06-12 23:15+05:30'::timestamptz,240,'combined','partial',4.20,'Anita R',26000,'rerun queued' FROM hospital_chain_isolation_rooms_r2795 WHERE room_code='ISO-C22'
UNION ALL SELECT id,'CY-2795-004','pass_through_autoclave','2026-03-22 10:00+05:30'::timestamptz,90,'chlorine_dioxide','pass',6.50,'Dinesh V',9100,'BSL3 routine' FROM hospital_chain_isolation_rooms_r2795 WHERE room_code='ISO-D03'
UNION ALL SELECT id,'CY-2795-005','negative_pressure_sensor','2026-05-30 19:00+05:30'::timestamptz,30,'uvgi_pulse','fail',2.10,'Mohan T',2200,'sensor drift, recalibrate' FROM hospital_chain_isolation_rooms_r2795 WHERE room_code='ISO-E11'
UNION ALL SELECT id,'CY-2795-006','uvgi_lamp','2026-06-09 05:45+05:30'::timestamptz,60,'uvgi_pulse','pass',5.40,'Priya S',3800,'lamp replaced' FROM hospital_chain_isolation_rooms_r2795 WHERE room_code='ISO-F18'
UNION ALL SELECT id,'CY-2795-007','vhp_generator','2026-06-13 01:30+05:30'::timestamptz,200,'vhp_fumigation','rerun_required',3.90,'Ramesh K',19500,'humidity excursion' FROM hospital_chain_isolation_rooms_r2795 WHERE room_code='ISO-A14';

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS founder_r2795_kpis();
CREATE OR REPLACE FUNCTION founder_r2795_kpis()
RETURNS TABLE(total_rooms int, active_rooms int, suspended_rooms int, total_cycles int, pass_rate_pct numeric, total_spend_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM hospital_chain_isolation_rooms_r2795),
    (SELECT COUNT(*)::int FROM hospital_chain_isolation_rooms_r2795 WHERE status='active'),
    (SELECT COUNT(*)::int FROM hospital_chain_isolation_rooms_r2795 WHERE status='suspended'),
    (SELECT COUNT(*)::int FROM isolation_decontam_cycles_r2795),
    COALESCE(ROUND(100.0 * (SELECT COUNT(*) FILTER (WHERE outcome='pass') FROM isolation_decontam_cycles_r2795)
                   / NULLIF((SELECT COUNT(*) FROM isolation_decontam_cycles_r2795),0), 2), 0),
    COALESCE((SELECT SUM(cost_rupees)::bigint FROM isolation_decontam_cycles_r2795), 0);
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2795_rooms();
CREATE OR REPLACE FUNCTION founder_r2795_rooms()
RETURNS TABLE(id uuid, chain_code text, hospital_name text, city text, room_code text, room_class text, bed_count int, hepa_pass_rate_pct numeric, status text, quarter_tag text, last_audit_date date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_code, r.hospital_name, r.city, r.room_code, r.room_class, r.bed_count, r.hepa_pass_rate_pct, r.status, r.quarter_tag, r.last_audit_date
  FROM hospital_chain_isolation_rooms_r2795 r
  ORDER BY r.chain_code, r.room_code;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_rooms() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_rooms() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2795_cycles();
CREATE OR REPLACE FUNCTION founder_r2795_cycles()
RETURNS TABLE(id uuid, cycle_code text, hospital_name text, room_code text, equipment_kind text, decontam_method text, outcome text, cycle_minutes int, spore_log_kill numeric, technician text, cost_rupees int, cycle_started timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.cycle_code, r.hospital_name, r.room_code, c.equipment_kind, c.decontam_method, c.outcome, c.cycle_minutes, c.spore_log_kill, c.technician, c.cost_rupees, c.cycle_started
  FROM isolation_decontam_cycles_r2795 c
  JOIN hospital_chain_isolation_rooms_r2795 r ON r.id = c.room_id
  ORDER BY c.cycle_started DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_cycles() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_cycles() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2795_chain_rollup();
CREATE OR REPLACE FUNCTION founder_r2795_chain_rollup()
RETURNS TABLE(chain_code text, rooms int, cycles int, pass_rate_pct numeric, avg_log_kill numeric, total_spend_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_code,
         COUNT(DISTINCT r.id)::int,
         COUNT(c.id)::int,
         COALESCE(ROUND(100.0 * COUNT(c.id) FILTER (WHERE c.outcome='pass') / NULLIF(COUNT(c.id),0), 2), 0),
         COALESCE(ROUND(AVG(c.spore_log_kill)::numeric, 2), 0),
         COALESCE(SUM(c.cost_rupees)::bigint, 0)
  FROM hospital_chain_isolation_rooms_r2795 r
  LEFT JOIN isolation_decontam_cycles_r2795 c ON c.room_id = r.id
  GROUP BY r.chain_code
  ORDER BY r.chain_code;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_chain_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_chain_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2795_equipment_mix();
CREATE OR REPLACE FUNCTION founder_r2795_equipment_mix()
RETURNS TABLE(equipment_kind text, cycles int, pass_cycles int, fail_cycles int, avg_minutes numeric, avg_cost numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.equipment_kind,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE c.outcome='pass')::int,
         COUNT(*) FILTER (WHERE c.outcome='fail')::int,
         ROUND(AVG(c.cycle_minutes)::numeric, 1),
         ROUND(AVG(c.cost_rupees)::numeric, 0)
  FROM isolation_decontam_cycles_r2795 c
  GROUP BY c.equipment_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_equipment_mix() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_equipment_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2795_failures();
CREATE OR REPLACE FUNCTION founder_r2795_failures()
RETURNS TABLE(cycle_code text, hospital_name text, room_code text, equipment_kind text, outcome text, spore_log_kill numeric, notes text, cycle_started timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.cycle_code, r.hospital_name, r.room_code, c.equipment_kind, c.outcome, c.spore_log_kill, c.notes, c.cycle_started
  FROM isolation_decontam_cycles_r2795 c
  JOIN hospital_chain_isolation_rooms_r2795 r ON r.id = c.room_id
  WHERE c.outcome IN ('fail','partial','rerun_required')
  ORDER BY c.cycle_started DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_failures() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_failures() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2795_quarter_breakdown();
CREATE OR REPLACE FUNCTION founder_r2795_quarter_breakdown()
RETURNS TABLE(quarter_tag text, rooms int, suspended int, avg_hepa_pass numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.quarter_tag,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE r.status='suspended')::int,
         ROUND(AVG(r.hepa_pass_rate_pct)::numeric, 2)
  FROM hospital_chain_isolation_rooms_r2795 r
  GROUP BY r.quarter_tag
  ORDER BY r.quarter_tag;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_quarter_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_quarter_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2795_method_outcomes();
CREATE OR REPLACE FUNCTION founder_r2795_method_outcomes()
RETURNS TABLE(decontam_method text, cycles int, pass_rate_pct numeric, avg_log_kill numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.decontam_method,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE c.outcome='pass') / NULLIF(COUNT(*),0), 2),
         ROUND(AVG(c.spore_log_kill)::numeric, 2)
  FROM isolation_decontam_cycles_r2795 c
  GROUP BY c.decontam_method
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2795_method_outcomes() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2795_method_outcomes() TO authenticated;

COMMIT;
