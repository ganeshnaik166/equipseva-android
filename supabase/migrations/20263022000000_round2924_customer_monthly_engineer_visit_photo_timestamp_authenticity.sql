-- Round r2924: Customer Monthly Engineer Visit-Photo Time-Stamp Authenticity Verification
-- HEAVY founder console: photo authenticity verification for monthly engineer visits

BEGIN;

-- =========================================================================
-- Table 1: visit_photo_authenticity_checks_r2924
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.visit_photo_authenticity_checks_r2924 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  visit_date date NOT NULL,
  hospital_name text NOT NULL,
  engineer_handle text NOT NULL,
  device_serial text NOT NULL,
  photo_count int NOT NULL DEFAULT 0,
  exif_timestamp_match boolean NOT NULL DEFAULT false,
  gps_coord_match boolean NOT NULL DEFAULT false,
  hash_unique boolean NOT NULL DEFAULT true,
  reverse_image_search_clean boolean NOT NULL DEFAULT true,
  authenticity_score numeric(5,2) NOT NULL DEFAULT 0,
  verdict text NOT NULL CHECK (verdict IN ('authentic','suspicious','fraudulent','pending')),
  reviewer_notes text
);

ALTER TABLE public.visit_photo_authenticity_checks_r2924 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- Table 2: photo_fraud_incidents_r2924
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.photo_fraud_incidents_r2924 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  check_id uuid REFERENCES public.visit_photo_authenticity_checks_r2924(id) ON DELETE CASCADE,
  incident_type text NOT NULL CHECK (incident_type IN ('exif_tampered','duplicate_photo','wrong_gps','stale_photo','reused_photo','no_metadata')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  detected_at timestamptz NOT NULL DEFAULT now(),
  engineer_handle text NOT NULL,
  hospital_name text NOT NULL,
  resolved boolean NOT NULL DEFAULT false,
  resolution_action text,
  loss_amount_rupees numeric(12,2) NOT NULL DEFAULT 0
);

ALTER TABLE public.photo_fraud_incidents_r2924 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- Seed data: visit_photo_authenticity_checks_r2924 (20 rows)
-- =========================================================================
INSERT INTO public.visit_photo_authenticity_checks_r2924
  (visit_date, hospital_name, engineer_handle, device_serial, photo_count, exif_timestamp_match, gps_coord_match, hash_unique, reverse_image_search_clean, authenticity_score, verdict, reviewer_notes)
VALUES
  ('2026-06-01'::date, 'Apollo Hyderabad', 'eng_ravi_01', 'PHILIPS-MX450-001', 8, true, true, true, true, 98.5, 'authentic', 'all checks clean'),
  ('2026-06-02'::date, 'Yashoda Secunderabad', 'eng_kiran_02', 'GE-VENUE-002', 6, true, true, true, true, 96.2, 'authentic', 'gps within 30m'),
  ('2026-06-03'::date, 'KIMS Kondapur', 'eng_arjun_03', 'SIEMENS-ACUSON-003', 5, false, true, true, true, 62.0, 'suspicious', 'exif timestamp 3 days old'),
  ('2026-06-04'::date, 'Care Banjara', 'eng_meera_04', 'MINDRAY-DC70-004', 7, true, false, true, true, 70.5, 'suspicious', 'gps drift 4km'),
  ('2026-06-05'::date, 'Continental Gachibowli', 'eng_rohit_05', 'PHILIPS-IE33-005', 9, true, true, true, true, 99.0, 'authentic', 'perfect'),
  ('2026-06-06'::date, 'Star Banjara', 'eng_priya_06', 'GE-LOGIQ-006', 4, true, true, false, true, 35.0, 'fraudulent', 'duplicate hash with may visit'),
  ('2026-06-07'::date, 'Sunshine Begumpet', 'eng_naveen_07', 'SIEMENS-CYPRESS-007', 8, true, true, true, true, 97.8, 'authentic', 'clean'),
  ('2026-06-08'::date, 'AIG Gachibowli', 'eng_lakshmi_08', 'PHILIPS-CX50-008', 6, true, true, true, false, 45.0, 'fraudulent', 'reverse search hit on stock photo'),
  ('2026-06-09'::date, 'Olive Banjara', 'eng_vikram_09', 'MINDRAY-M9-009', 7, true, true, true, true, 95.5, 'authentic', 'all good'),
  ('2026-06-10'::date, 'Renova Sarojini', 'eng_anjali_10', 'GE-VIVID-010', 5, false, false, true, true, 28.0, 'fraudulent', 'both exif + gps fail'),
  ('2026-06-11'::date, 'Medicover Hitec', 'eng_suresh_11', 'PHILIPS-EPIQ-011', 10, true, true, true, true, 99.5, 'authentic', 'excellent'),
  ('2026-06-12'::date, 'Asian Inst Gastro', 'eng_pooja_12', 'SIEMENS-AURA-012', 6, true, true, true, true, 96.8, 'authentic', 'clean'),
  ('2026-06-13'::date, 'Citizens Nallagandla', 'eng_kumar_13', 'MINDRAY-DC80-013', 8, true, true, true, true, 97.2, 'authentic', 'verified'),
  ('2026-06-14'::date, 'Pace Madhapur', 'eng_deepa_14', 'GE-VOLUSON-014', 4, false, true, true, true, 58.0, 'suspicious', 'exif missing'),
  ('2026-06-15'::date, 'Rainbow Hyderguda', 'eng_mahesh_15', 'PHILIPS-AFFINITI-015', 7, true, true, true, true, 96.0, 'authentic', 'all good'),
  ('2026-06-16'::date, 'Sunshine Karkhana', 'eng_swathi_16', 'SIEMENS-NX3-016', 5, true, true, true, true, 94.5, 'authentic', 'clean'),
  ('2026-06-17'::date, 'Maxcure Madhapur', 'eng_naga_17', 'GE-VIVID-S60-017', 6, true, false, true, true, 68.0, 'suspicious', 'gps drift 6km'),
  ('2026-06-18'::date, 'Krishna Inst Med', 'eng_radha_18', 'MINDRAY-Z6-018', 9, true, true, true, true, 98.0, 'authentic', 'excellent'),
  ('2026-06-19'::date, 'Aware Gleneagles', 'eng_chandra_19', 'PHILIPS-SPARQ-019', 7, true, true, true, true, 97.5, 'authentic', 'all good'),
  ('2026-06-20'::date, 'Kamineni LB Nagar', 'eng_gopal_20', 'SIEMENS-ANTARES-020', 4, true, true, false, true, 40.0, 'fraudulent', 'hash collision with apr visit');

-- =========================================================================
-- Seed data: photo_fraud_incidents_r2924 (15 rows)
-- =========================================================================
INSERT INTO public.photo_fraud_incidents_r2924
  (incident_type, severity, detected_at, engineer_handle, hospital_name, resolved, resolution_action, loss_amount_rupees)
VALUES
  ('exif_tampered', 'p1', '2026-06-03 10:30:00+05:30'::timestamptz, 'eng_arjun_03', 'KIMS Kondapur', true, 'engineer warned', 0),
  ('wrong_gps', 'p2', '2026-06-04 14:15:00+05:30'::timestamptz, 'eng_meera_04', 'Care Banjara', true, 'revisit scheduled', 1500),
  ('duplicate_photo', 'p0', '2026-06-06 09:00:00+05:30'::timestamptz, 'eng_priya_06', 'Star Banjara', false, 'engineer suspended', 8500),
  ('reused_photo', 'p0', '2026-06-08 16:45:00+05:30'::timestamptz, 'eng_lakshmi_08', 'AIG Gachibowli', false, 'investigation open', 12000),
  ('exif_tampered', 'p0', '2026-06-10 11:20:00+05:30'::timestamptz, 'eng_anjali_10', 'Renova Sarojini', false, 'terminate engineer', 15000),
  ('wrong_gps', 'p0', '2026-06-10 11:25:00+05:30'::timestamptz, 'eng_anjali_10', 'Renova Sarojini', false, 'terminate engineer', 15000),
  ('no_metadata', 'p3', '2026-06-14 13:00:00+05:30'::timestamptz, 'eng_deepa_14', 'Pace Madhapur', true, 'camera config fixed', 0),
  ('wrong_gps', 'p2', '2026-06-17 15:30:00+05:30'::timestamptz, 'eng_naga_17', 'Maxcure Madhapur', false, 'revisit scheduled', 2000),
  ('duplicate_photo', 'p1', '2026-06-20 10:00:00+05:30'::timestamptz, 'eng_gopal_20', 'Kamineni LB Nagar', false, 'engineer warned', 5000),
  ('stale_photo', 'p2', '2026-05-15 12:00:00+05:30'::timestamptz, 'eng_arjun_03', 'KIMS Kondapur', true, 'closed', 1200),
  ('reused_photo', 'p1', '2026-05-22 14:00:00+05:30'::timestamptz, 'eng_priya_06', 'Star Banjara', true, 'warned', 3000),
  ('exif_tampered', 'p2', '2026-05-28 16:00:00+05:30'::timestamptz, 'eng_meera_04', 'Care Banjara', true, 'training redone', 800),
  ('no_metadata', 'p3', '2026-06-05 09:30:00+05:30'::timestamptz, 'eng_vikram_09', 'Olive Banjara', true, 'closed', 0),
  ('stale_photo', 'p1', '2026-06-12 11:00:00+05:30'::timestamptz, 'eng_lakshmi_08', 'AIG Gachibowli', false, 'open', 4500),
  ('duplicate_photo', 'p0', '2026-06-19 17:00:00+05:30'::timestamptz, 'eng_anjali_10', 'Renova Sarojini', false, 'terminate engineer', 18000);

-- =========================================================================
-- RPC 1: kpi_summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2924_kpi_summary()
RETURNS TABLE (
  total_checks bigint,
  authentic_count bigint,
  suspicious_count bigint,
  fraudulent_count bigint,
  avg_authenticity_score numeric,
  open_incidents bigint,
  total_loss_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.visit_photo_authenticity_checks_r2924),
    (SELECT count(*) FROM public.visit_photo_authenticity_checks_r2924 WHERE verdict = 'authentic'),
    (SELECT count(*) FROM public.visit_photo_authenticity_checks_r2924 WHERE verdict = 'suspicious'),
    (SELECT count(*) FROM public.visit_photo_authenticity_checks_r2924 WHERE verdict = 'fraudulent'),
    (SELECT round(avg(authenticity_score)::numeric, 2) FROM public.visit_photo_authenticity_checks_r2924),
    (SELECT count(*) FROM public.photo_fraud_incidents_r2924 WHERE resolved = false),
    (SELECT coalesce(sum(loss_amount_rupees), 0) FROM public.photo_fraud_incidents_r2924);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2924_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2924_kpi_summary() TO authenticated;

-- =========================================================================
-- RPC 2: recent_checks
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2924_recent_checks()
RETURNS TABLE (
  id uuid,
  visit_date date,
  hospital_name text,
  engineer_handle text,
  photo_count int,
  authenticity_score numeric,
  verdict text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT c.id, c.visit_date, c.hospital_name, c.engineer_handle, c.photo_count, c.authenticity_score, c.verdict
  FROM public.visit_photo_authenticity_checks_r2924 c
  ORDER BY c.visit_date DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2924_recent_checks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2924_recent_checks() TO authenticated;

-- =========================================================================
-- RPC 3: fraudulent_engineers
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2924_fraudulent_engineers()
RETURNS TABLE (
  engineer_handle text,
  fraud_count bigint,
  total_loss numeric,
  worst_severity text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    i.engineer_handle,
    count(*)::bigint,
    coalesce(sum(i.loss_amount_rupees), 0),
    min(i.severity)
  FROM public.photo_fraud_incidents_r2924 i
  GROUP BY i.engineer_handle
  ORDER BY count(*) DESC, sum(i.loss_amount_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2924_fraudulent_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2924_fraudulent_engineers() TO authenticated;

-- =========================================================================
-- RPC 4: incident_breakdown
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2924_incident_breakdown()
RETURNS TABLE (
  incident_type text,
  occurrences bigint,
  open_count bigint,
  total_loss numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    i.incident_type,
    count(*)::bigint,
    count(*) FILTER (WHERE NOT i.resolved)::bigint,
    coalesce(sum(i.loss_amount_rupees), 0)
  FROM public.photo_fraud_incidents_r2924 i
  GROUP BY i.incident_type
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2924_incident_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2924_incident_breakdown() TO authenticated;

-- =========================================================================
-- RPC 5: hospital_authenticity
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2924_hospital_authenticity()
RETURNS TABLE (
  hospital_name text,
  check_count bigint,
  avg_score numeric,
  fraud_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    c.hospital_name,
    count(*)::bigint,
    round(avg(c.authenticity_score)::numeric, 2),
    count(*) FILTER (WHERE c.verdict = 'fraudulent')::bigint
  FROM public.visit_photo_authenticity_checks_r2924 c
  GROUP BY c.hospital_name
  ORDER BY avg(c.authenticity_score) ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2924_hospital_authenticity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2924_hospital_authenticity() TO authenticated;

-- =========================================================================
-- RPC 6: open_p0_incidents
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2924_open_p0_incidents()
RETURNS TABLE (
  id uuid,
  incident_type text,
  engineer_handle text,
  hospital_name text,
  detected_at timestamptz,
  loss_amount_rupees numeric,
  resolution_action text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT i.id, i.incident_type, i.engineer_handle, i.hospital_name, i.detected_at, i.loss_amount_rupees, i.resolution_action
  FROM public.photo_fraud_incidents_r2924 i
  WHERE i.severity IN ('p0','p1') AND i.resolved = false
  ORDER BY i.detected_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2924_open_p0_incidents() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2924_open_p0_incidents() TO authenticated;

-- =========================================================================
-- RPC 7: check_failure_modes
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2924_check_failure_modes()
RETURNS TABLE (
  failure_mode text,
  failed_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total_count numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  SELECT count(*) INTO total_count FROM public.visit_photo_authenticity_checks_r2924;
  IF total_count = 0 THEN total_count := 1; END IF;

  RETURN QUERY
  SELECT 'exif_timestamp_mismatch'::text,
         count(*) FILTER (WHERE NOT exif_timestamp_match)::bigint,
         round((count(*) FILTER (WHERE NOT exif_timestamp_match))::numeric * 100 / total_count, 2)
  FROM public.visit_photo_authenticity_checks_r2924
  UNION ALL
  SELECT 'gps_mismatch'::text,
         count(*) FILTER (WHERE NOT gps_coord_match)::bigint,
         round((count(*) FILTER (WHERE NOT gps_coord_match))::numeric * 100 / total_count, 2)
  FROM public.visit_photo_authenticity_checks_r2924
  UNION ALL
  SELECT 'hash_collision'::text,
         count(*) FILTER (WHERE NOT hash_unique)::bigint,
         round((count(*) FILTER (WHERE NOT hash_unique))::numeric * 100 / total_count, 2)
  FROM public.visit_photo_authenticity_checks_r2924
  UNION ALL
  SELECT 'reverse_image_hit'::text,
         count(*) FILTER (WHERE NOT reverse_image_search_clean)::bigint,
         round((count(*) FILTER (WHERE NOT reverse_image_search_clean))::numeric * 100 / total_count, 2)
  FROM public.visit_photo_authenticity_checks_r2924;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2924_check_failure_modes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2924_check_failure_modes() TO authenticated;

COMMIT;
