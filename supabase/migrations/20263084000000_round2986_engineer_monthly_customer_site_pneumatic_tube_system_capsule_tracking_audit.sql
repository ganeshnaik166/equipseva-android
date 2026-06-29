-- Round 2986: Engineer Monthly Customer Site Pneumatic-Tube System Capsule-Tracking Audit
-- HEAVY ★★★★ — 2 tables + 7 RPCs + seeds

BEGIN;

-- =====================================================================
-- TABLE 1: pneumatic_tube_audits_r2986
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.pneumatic_tube_audits_r2986 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_date date not null,
  hospital_name text not null,
  city text not null,
  engineer_name text not null,
  system_vendor text not null check (system_vendor in ('swisslog','aerocom','pevco','sumetzberger','quirepace')),
  station_count int not null check (station_count between 1 and 200),
  capsules_total int not null check (capsules_total between 10 and 5000),
  capsules_missing int not null check (capsules_missing between 0 and 500),
  capsules_damaged int not null check (capsules_damaged between 0 and 200),
  avg_transit_seconds int not null check (avg_transit_seconds between 5 and 600),
  blower_pressure_kpa numeric(5,2) not null check (blower_pressure_kpa between 5.00 and 60.00),
  diverter_failures int not null check (diverter_failures between 0 and 50),
  status text not null check (status in ('pass','minor_issues','major_issues','fail')),
  followup_required boolean not null default false
);

ALTER TABLE public.pneumatic_tube_audits_r2986 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pta_r2986_founder_select ON public.pneumatic_tube_audits_r2986;
CREATE POLICY pta_r2986_founder_select ON public.pneumatic_tube_audits_r2986
  FOR SELECT TO authenticated USING (public.is_founder());

REVOKE ALL ON public.pneumatic_tube_audits_r2986 FROM PUBLIC, anon;
GRANT SELECT ON public.pneumatic_tube_audits_r2986 TO authenticated;

INSERT INTO public.pneumatic_tube_audits_r2986
  (audit_date, hospital_name, city, engineer_name, system_vendor, station_count, capsules_total, capsules_missing, capsules_damaged, avg_transit_seconds, blower_pressure_kpa, diverter_failures, status, followup_required) VALUES
  ('2026-06-01'::date, 'Apollo Jubilee', 'Hyderabad', 'Ravi Teja', 'swisslog', 84, 2400, 6, 11, 42, 28.50, 2, 'pass', false),
  ('2026-06-02'::date, 'Fortis BG Road', 'Bengaluru', 'Anitha Rao', 'aerocom', 62, 1800, 14, 22, 55, 24.20, 5, 'minor_issues', true),
  ('2026-06-03'::date, 'Manipal Whitefield', 'Bengaluru', 'Karthik N', 'pevco', 48, 1500, 3, 7, 38, 30.10, 1, 'pass', false),
  ('2026-06-04'::date, 'AIIMS Delhi Block C', 'Delhi', 'Suresh Pillai', 'swisslog', 120, 3200, 22, 41, 68, 22.80, 8, 'major_issues', true),
  ('2026-06-05'::date, 'KIMS Secunderabad', 'Hyderabad', 'Meena Iyer', 'sumetzberger', 56, 1700, 4, 9, 44, 27.40, 2, 'pass', false),
  ('2026-06-06'::date, 'Yashoda Somajiguda', 'Hyderabad', 'Praveen K', 'aerocom', 72, 2100, 18, 28, 61, 23.50, 6, 'minor_issues', true),
  ('2026-06-07'::date, 'Lilavati Bandra', 'Mumbai', 'Shabbir Khan', 'pevco', 90, 2600, 9, 15, 47, 29.00, 3, 'pass', false),
  ('2026-06-08'::date, 'Hinduja Mahim', 'Mumbai', 'Joseph D', 'swisslog', 78, 2200, 31, 52, 74, 19.60, 11, 'fail', true),
  ('2026-06-09'::date, 'CMC Vellore Block A', 'Vellore', 'Daniel J', 'quirepace', 64, 1900, 5, 10, 40, 31.20, 2, 'pass', false),
  ('2026-06-10'::date, 'Christian Medical Ludhiana', 'Ludhiana', 'Harpreet Singh', 'aerocom', 52, 1600, 12, 20, 58, 25.10, 4, 'minor_issues', true),
  ('2026-06-11'::date, 'Tata Memorial Parel', 'Mumbai', 'Vikas More', 'swisslog', 110, 3000, 27, 38, 65, 21.30, 9, 'major_issues', true),
  ('2026-06-12'::date, 'Narayana Health City', 'Bengaluru', 'Rohit Shetty', 'pevco', 96, 2800, 8, 14, 45, 28.90, 3, 'pass', false),
  ('2026-06-13'::date, 'Medanta Gurugram', 'Gurugram', 'Saurabh G', 'swisslog', 130, 3500, 19, 30, 56, 26.40, 7, 'minor_issues', true),
  ('2026-06-14'::date, 'PGIMER Chandigarh', 'Chandigarh', 'Inderpal S', 'sumetzberger', 88, 2500, 35, 60, 78, 18.20, 13, 'fail', true),
  ('2026-06-15'::date, 'Sahyadri Hospital', 'Pune', 'Ajay Deshpande', 'aerocom', 44, 1400, 3, 6, 39, 30.50, 1, 'pass', false),
  ('2026-06-16'::date, 'Ruby Hall Clinic', 'Pune', 'Pradeep B', 'pevco', 58, 1700, 11, 18, 52, 26.10, 4, 'minor_issues', true),
  ('2026-06-17'::date, 'Wockhardt South Mumbai', 'Mumbai', 'Farhan Sheikh', 'quirepace', 50, 1500, 7, 12, 48, 27.80, 3, 'minor_issues', false),
  ('2026-06-18'::date, 'Continental Gachibowli', 'Hyderabad', 'Naveen Reddy', 'swisslog', 76, 2300, 5, 9, 41, 29.40, 2, 'pass', false),
  ('2026-06-19'::date, 'Care Banjara', 'Hyderabad', 'Lakshmi P', 'aerocom', 60, 1800, 23, 36, 70, 20.10, 10, 'major_issues', true),
  ('2026-06-20'::date, 'Global Lakdikapul', 'Hyderabad', 'Mahesh V', 'pevco', 54, 1600, 4, 8, 43, 28.20, 2, 'pass', false);

-- =====================================================================
-- TABLE 2: capsule_route_events_r2986
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.capsule_route_events_r2986 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  event_at timestamptz not null,
  hospital_name text not null,
  capsule_id text not null,
  origin_station text not null,
  destination_station text not null,
  payload_type text not null check (payload_type in ('blood_sample','medication','document','specimen','xray_film')),
  transit_seconds int not null check (transit_seconds between 3 and 900),
  outcome text not null check (outcome in ('delivered','stuck_in_transit','lost','damaged_on_arrival','rerouted')),
  station_count_traversed int not null check (station_count_traversed between 1 and 50),
  diverter_count int not null check (diverter_count between 0 and 30),
  priority text not null check (priority in ('routine','urgent','stat','critical'))
);

ALTER TABLE public.capsule_route_events_r2986 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cre_r2986_founder_select ON public.capsule_route_events_r2986;
CREATE POLICY cre_r2986_founder_select ON public.capsule_route_events_r2986
  FOR SELECT TO authenticated USING (public.is_founder());

REVOKE ALL ON public.capsule_route_events_r2986 FROM PUBLIC, anon;
GRANT SELECT ON public.capsule_route_events_r2986 TO authenticated;

INSERT INTO public.capsule_route_events_r2986
  (event_at, hospital_name, capsule_id, origin_station, destination_station, payload_type, transit_seconds, outcome, station_count_traversed, diverter_count, priority) VALUES
  ('2026-06-20 08:12:00+00'::timestamptz, 'Apollo Jubilee', 'CAP-A001', 'ER-12', 'LAB-03', 'blood_sample', 38, 'delivered', 4, 2, 'stat'),
  ('2026-06-20 08:25:00+00'::timestamptz, 'Apollo Jubilee', 'CAP-A014', 'OT-04', 'PHARM-01', 'medication', 52, 'delivered', 6, 3, 'urgent'),
  ('2026-06-20 09:01:00+00'::timestamptz, 'Fortis BG Road', 'CAP-F022', 'ICU-02', 'LAB-01', 'specimen', 78, 'rerouted', 7, 4, 'critical'),
  ('2026-06-20 09:14:00+00'::timestamptz, 'AIIMS Delhi Block C', 'CAP-D108', 'WARD-7B', 'LAB-04', 'blood_sample', 145, 'stuck_in_transit', 9, 5, 'stat'),
  ('2026-06-20 09:33:00+00'::timestamptz, 'Manipal Whitefield', 'CAP-M045', 'ER-01', 'BLOOD-BANK', 'blood_sample', 41, 'delivered', 5, 2, 'critical'),
  ('2026-06-20 09:55:00+00'::timestamptz, 'Yashoda Somajiguda', 'CAP-Y077', 'OT-02', 'CSSD-01', 'document', 62, 'delivered', 5, 3, 'routine'),
  ('2026-06-20 10:12:00+00'::timestamptz, 'Hinduja Mahim', 'CAP-H019', 'WARD-4A', 'LAB-02', 'specimen', 215, 'lost', 8, 4, 'urgent'),
  ('2026-06-20 10:30:00+00'::timestamptz, 'KIMS Secunderabad', 'CAP-K033', 'ER-03', 'XRAY-01', 'xray_film', 48, 'delivered', 4, 2, 'urgent'),
  ('2026-06-20 10:48:00+00'::timestamptz, 'Lilavati Bandra', 'CAP-L091', 'OT-01', 'PHARM-02', 'medication', 55, 'delivered', 5, 2, 'stat'),
  ('2026-06-20 11:05:00+00'::timestamptz, 'Tata Memorial Parel', 'CAP-T044', 'ONCO-WARD', 'PHARM-01', 'medication', 90, 'damaged_on_arrival', 7, 4, 'critical'),
  ('2026-06-20 11:22:00+00'::timestamptz, 'CMC Vellore Block A', 'CAP-C012', 'ICU-01', 'LAB-03', 'blood_sample', 39, 'delivered', 4, 2, 'stat'),
  ('2026-06-20 11:40:00+00'::timestamptz, 'Narayana Health City', 'CAP-N088', 'CARDIAC-OT', 'BLOOD-BANK', 'blood_sample', 44, 'delivered', 5, 2, 'critical'),
  ('2026-06-20 11:58:00+00'::timestamptz, 'Medanta Gurugram', 'CAP-MG201', 'WARD-9C', 'LAB-05', 'specimen', 71, 'rerouted', 8, 5, 'urgent'),
  ('2026-06-20 12:15:00+00'::timestamptz, 'PGIMER Chandigarh', 'CAP-P166', 'ER-04', 'LAB-02', 'blood_sample', 312, 'stuck_in_transit', 11, 6, 'stat'),
  ('2026-06-20 12:33:00+00'::timestamptz, 'Sahyadri Hospital', 'CAP-S028', 'OPD-12', 'PHARM-01', 'medication', 47, 'delivered', 4, 2, 'routine'),
  ('2026-06-20 12:51:00+00'::timestamptz, 'Ruby Hall Clinic', 'CAP-R055', 'WARD-3A', 'LAB-01', 'document', 58, 'delivered', 5, 3, 'routine'),
  ('2026-06-20 13:08:00+00'::timestamptz, 'Continental Gachibowli', 'CAP-CG017', 'ER-02', 'XRAY-02', 'xray_film', 50, 'delivered', 4, 2, 'urgent'),
  ('2026-06-20 13:26:00+00'::timestamptz, 'Care Banjara', 'CAP-CB099', 'ICU-03', 'LAB-04', 'specimen', 188, 'lost', 9, 5, 'critical'),
  ('2026-06-20 13:44:00+00'::timestamptz, 'Global Lakdikapul', 'CAP-G041', 'OT-03', 'PHARM-02', 'medication', 49, 'delivered', 5, 2, 'stat'),
  ('2026-06-20 14:02:00+00'::timestamptz, 'Wockhardt South Mumbai', 'CAP-W024', 'WARD-5B', 'LAB-01', 'blood_sample', 64, 'delivered', 5, 3, 'urgent'),
  ('2026-06-20 14:20:00+00'::timestamptz, 'Christian Medical Ludhiana', 'CAP-CL036', 'ER-01', 'BLOOD-BANK', 'blood_sample', 82, 'rerouted', 6, 3, 'critical'),
  ('2026-06-20 14:38:00+00'::timestamptz, 'Fortis BG Road', 'CAP-F029', 'OT-05', 'CSSD-02', 'document', 67, 'delivered', 5, 3, 'routine');

-- =====================================================================
-- RPC 1: audit summary
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2986_audit_summary()
RETURNS TABLE(total_audits int, passing int, minor int, major int, failing int, followups int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::int,
    (count(*) filter (where status = 'pass'))::int,
    (count(*) filter (where status = 'minor_issues'))::int,
    (count(*) filter (where status = 'major_issues'))::int,
    (count(*) filter (where status = 'fail'))::int,
    (count(*) filter (where followup_required))::int
  FROM public.pneumatic_tube_audits_r2986;
END $$;
REVOKE ALL ON FUNCTION public.r2986_audit_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2986_audit_summary() TO authenticated;

-- =====================================================================
-- RPC 2: vendor breakdown
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2986_vendor_breakdown()
RETURNS TABLE(system_vendor text, audits int, avg_transit numeric, total_missing int, fail_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.system_vendor,
    count(*)::int,
    round(avg(a.avg_transit_seconds)::numeric, 1),
    sum(a.capsules_missing)::int,
    (count(*) filter (where a.status = 'fail'))::int
  FROM public.pneumatic_tube_audits_r2986 a
  GROUP BY a.system_vendor
  ORDER BY count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2986_vendor_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2986_vendor_breakdown() TO authenticated;

-- =====================================================================
-- RPC 3: worst-performing sites
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2986_worst_sites()
RETURNS TABLE(hospital_name text, city text, capsules_missing int, diverter_failures int, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.hospital_name, a.city, a.capsules_missing, a.diverter_failures, a.status
  FROM public.pneumatic_tube_audits_r2986 a
  WHERE a.status IN ('major_issues','fail')
  ORDER BY a.capsules_missing DESC, a.diverter_failures DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2986_worst_sites() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2986_worst_sites() TO authenticated;

-- =====================================================================
-- RPC 4: engineer leaderboard
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2986_engineer_leaderboard()
RETURNS TABLE(engineer_name text, audits int, passes int, avg_pressure numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.engineer_name,
    count(*)::int,
    (count(*) filter (where a.status = 'pass'))::int,
    round(avg(a.blower_pressure_kpa)::numeric, 2)
  FROM public.pneumatic_tube_audits_r2986 a
  GROUP BY a.engineer_name
  ORDER BY (count(*) filter (where a.status = 'pass')) DESC, count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2986_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2986_engineer_leaderboard() TO authenticated;

-- =====================================================================
-- RPC 5: capsule outcome breakdown
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2986_capsule_outcomes()
RETURNS TABLE(outcome text, events int, avg_transit numeric, critical_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.outcome,
    count(*)::int,
    round(avg(e.transit_seconds)::numeric, 1),
    (count(*) filter (where e.priority = 'critical'))::int
  FROM public.capsule_route_events_r2986 e
  GROUP BY e.outcome
  ORDER BY count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2986_capsule_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2986_capsule_outcomes() TO authenticated;

-- =====================================================================
-- RPC 6: payload type stats
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2986_payload_stats()
RETURNS TABLE(payload_type text, events int, delivered int, lost_or_damaged int, avg_transit numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.payload_type,
    count(*)::int,
    (count(*) filter (where e.outcome = 'delivered'))::int,
    (count(*) filter (where e.outcome IN ('lost','damaged_on_arrival')))::int,
    round(avg(e.transit_seconds)::numeric, 1)
  FROM public.capsule_route_events_r2986 e
  GROUP BY e.payload_type
  ORDER BY count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2986_payload_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2986_payload_stats() TO authenticated;

-- =====================================================================
-- RPC 7: stuck and lost capsules incidents
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2986_capsule_incidents()
RETURNS TABLE(event_at timestamptz, hospital_name text, capsule_id text, payload_type text, priority text, outcome text, transit_seconds int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_at, e.hospital_name, e.capsule_id, e.payload_type, e.priority, e.outcome, e.transit_seconds
  FROM public.capsule_route_events_r2986 e
  WHERE e.outcome IN ('stuck_in_transit','lost','damaged_on_arrival','rerouted')
  ORDER BY e.event_at DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2986_capsule_incidents() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2986_capsule_incidents() TO authenticated;

COMMIT;
