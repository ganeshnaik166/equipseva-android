BEGIN;

-- Round 2800: Customer Monthly Engineer Arrival Time Window Precision
-- Tracks promised arrival windows vs actual arrival times for engineer dispatches,
-- measuring ETA accuracy, deviation, and feeding promise refinement loop.

CREATE TABLE IF NOT EXISTS engineer_arrival_window_precision_r2800 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  job_ref text NOT NULL,
  customer_org text NOT NULL,
  engineer_name text NOT NULL,
  city text NOT NULL,
  promised_window_start timestamptz NOT NULL,
  promised_window_end timestamptz NOT NULL,
  eta_predicted_at timestamptz NOT NULL,
  actual_arrival_at timestamptz NOT NULL,
  deviation_minutes integer NOT NULL,
  within_window boolean NOT NULL,
  accuracy_band text NOT NULL CHECK (accuracy_band IN ('on_time','early_minor','late_minor','early_major','late_major','grossly_late')),
  promise_refined boolean NOT NULL DEFAULT false,
  refined_window_minutes integer,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_arrival_window_precision_r2800 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_arrival_window_precision_r2800;
CREATE POLICY founder_all ON engineer_arrival_window_precision_r2800
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_arrival_promise_refinement_r2800 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  city text NOT NULL,
  total_jobs integer NOT NULL,
  on_time_count integer NOT NULL,
  late_count integer NOT NULL,
  early_count integer NOT NULL,
  median_deviation_minutes integer NOT NULL,
  p90_deviation_minutes integer NOT NULL,
  previous_window_minutes integer NOT NULL,
  recommended_window_minutes integer NOT NULL,
  recommendation_status text NOT NULL CHECK (recommendation_status IN ('tighten','widen','hold','re_evaluate')),
  applied_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_arrival_promise_refinement_r2800 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_arrival_promise_refinement_r2800;
CREATE POLICY founder_all ON engineer_arrival_promise_refinement_r2800
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_arrival_window_precision_r2800 (month_label, job_ref, customer_org, engineer_name, city, promised_window_start, promised_window_end, eta_predicted_at, actual_arrival_at, deviation_minutes, within_window, accuracy_band, promise_refined, refined_window_minutes, notes)
VALUES
  ('2026-06','JOB-22001','Apollo Hospitals Hyderabad','Ramesh Kumar','Hyderabad','2026-06-02 09:00:00+05:30','2026-06-02 10:00:00+05:30','2026-06-02 09:25:00+05:30','2026-06-02 09:27:00+05:30',-3,true,'on_time',true,45,'Traffic light, on slot'),
  ('2026-06','JOB-22002','Yashoda Super Speciality','Sneha Reddy','Hyderabad','2026-06-03 11:00:00+05:30','2026-06-03 12:00:00+05:30','2026-06-03 11:30:00+05:30','2026-06-03 11:48:00+05:30',18,true,'late_minor',false,NULL,'Slight traffic Banjara'),
  ('2026-06','JOB-22003','Fortis Bannerghatta','Arvind Patel','Bengaluru','2026-06-05 14:00:00+05:30','2026-06-05 15:00:00+05:30','2026-06-05 14:25:00+05:30','2026-06-05 15:42:00+05:30',42,false,'late_major',true,90,'Outer ring road jam'),
  ('2026-06','JOB-22004','Manipal Whitefield','Priya Singh','Bengaluru','2026-06-08 08:30:00+05:30','2026-06-08 09:30:00+05:30','2026-06-08 09:00:00+05:30','2026-06-08 08:18:00+05:30',-12,false,'early_minor',false,NULL,'Customer not ready, waited'),
  ('2026-06','JOB-22005','Kokilaben Mumbai','Vikram Joshi','Mumbai','2026-06-10 10:00:00+05:30','2026-06-10 11:00:00+05:30','2026-06-10 10:30:00+05:30','2026-06-10 12:35:00+05:30',95,false,'grossly_late',true,120,'Bandra-Worli SLA breach'),
  ('2026-06','JOB-22006','Lilavati Hospital','Anjali Mehta','Mumbai','2026-06-12 16:00:00+05:30','2026-06-12 17:00:00+05:30','2026-06-12 16:30:00+05:30','2026-06-12 16:33:00+05:30',3,true,'on_time',false,NULL,'Clean run'),
  ('2026-06','JOB-22007','AIIMS Delhi','Rajesh Sharma','Delhi','2026-06-15 09:30:00+05:30','2026-06-15 10:30:00+05:30','2026-06-15 10:00:00+05:30','2026-06-15 09:08:00+05:30',-22,false,'early_major',true,30,'Engineer overestimated travel');

INSERT INTO engineer_arrival_promise_refinement_r2800 (month_label, engineer_name, city, total_jobs, on_time_count, late_count, early_count, median_deviation_minutes, p90_deviation_minutes, previous_window_minutes, recommended_window_minutes, recommendation_status, applied_at)
VALUES
  ('2026-06','Ramesh Kumar','Hyderabad',38,32,4,2,3,12,60,45,'tighten','2026-06-20 18:00:00+05:30'),
  ('2026-06','Sneha Reddy','Hyderabad',31,24,5,2,8,22,60,60,'hold',NULL),
  ('2026-06','Arvind Patel','Bengaluru',42,22,18,2,28,68,60,90,'widen','2026-06-22 12:00:00+05:30'),
  ('2026-06','Priya Singh','Bengaluru',29,21,3,5,-4,18,60,60,'hold',NULL),
  ('2026-06','Vikram Joshi','Mumbai',35,14,19,2,55,110,60,120,'widen','2026-06-23 09:00:00+05:30'),
  ('2026-06','Anjali Mehta','Mumbai',40,34,4,2,4,14,60,45,'tighten','2026-06-24 11:00:00+05:30'),
  ('2026-06','Rajesh Sharma','Delhi',27,12,5,10,-18,-2,60,30,'re_evaluate',NULL);

DROP FUNCTION IF EXISTS founder_arrival_window_kpis_r2800();
CREATE OR REPLACE FUNCTION founder_arrival_window_kpis_r2800()
RETURNS TABLE(
  total_jobs bigint,
  within_window_count bigint,
  within_window_pct numeric,
  median_deviation_minutes numeric,
  grossly_late_count bigint,
  promises_refined bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE within_window)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE within_window) / NULLIF(COUNT(*),0), 1),
    ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY deviation_minutes)::numeric, 1),
    COUNT(*) FILTER (WHERE accuracy_band = 'grossly_late')::bigint,
    COUNT(*) FILTER (WHERE promise_refined)::bigint
  FROM engineer_arrival_window_precision_r2800;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_window_kpis_r2800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_window_kpis_r2800() TO authenticated;

DROP FUNCTION IF EXISTS founder_arrival_window_list_r2800();
CREATE OR REPLACE FUNCTION founder_arrival_window_list_r2800()
RETURNS TABLE(
  id uuid,
  job_ref text,
  customer_org text,
  engineer_name text,
  city text,
  promised_window_start timestamptz,
  promised_window_end timestamptz,
  actual_arrival_at timestamptz,
  deviation_minutes integer,
  within_window boolean,
  accuracy_band text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT w.id, w.job_ref, w.customer_org, w.engineer_name, w.city,
         w.promised_window_start, w.promised_window_end, w.actual_arrival_at,
         w.deviation_minutes, w.within_window, w.accuracy_band
  FROM engineer_arrival_window_precision_r2800 w
  ORDER BY w.promised_window_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_window_list_r2800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_window_list_r2800() TO authenticated;

DROP FUNCTION IF EXISTS founder_arrival_band_breakdown_r2800();
CREATE OR REPLACE FUNCTION founder_arrival_band_breakdown_r2800()
RETURNS TABLE(
  accuracy_band text,
  job_count bigint,
  share_pct numeric,
  avg_abs_deviation numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*) INTO total FROM engineer_arrival_window_precision_r2800;
  RETURN QUERY
  SELECT w.accuracy_band,
         COUNT(*)::bigint,
         ROUND(100.0 * COUNT(*) / NULLIF(total,0), 1),
         ROUND(AVG(ABS(w.deviation_minutes))::numeric, 1)
  FROM engineer_arrival_window_precision_r2800 w
  GROUP BY w.accuracy_band
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_band_breakdown_r2800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_band_breakdown_r2800() TO authenticated;

DROP FUNCTION IF EXISTS founder_arrival_city_precision_r2800();
CREATE OR REPLACE FUNCTION founder_arrival_city_precision_r2800()
RETURNS TABLE(
  city text,
  total_jobs bigint,
  within_window_pct numeric,
  median_deviation_minutes numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT w.city,
         COUNT(*)::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE within_window) / NULLIF(COUNT(*),0), 1),
         ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY w.deviation_minutes)::numeric, 1)
  FROM engineer_arrival_window_precision_r2800 w
  GROUP BY w.city
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_city_precision_r2800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_city_precision_r2800() TO authenticated;

DROP FUNCTION IF EXISTS founder_arrival_refinement_list_r2800();
CREATE OR REPLACE FUNCTION founder_arrival_refinement_list_r2800()
RETURNS TABLE(
  id uuid,
  engineer_name text,
  city text,
  total_jobs integer,
  on_time_count integer,
  median_deviation_minutes integer,
  p90_deviation_minutes integer,
  previous_window_minutes integer,
  recommended_window_minutes integer,
  recommendation_status text,
  applied_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_name, r.city, r.total_jobs, r.on_time_count,
         r.median_deviation_minutes, r.p90_deviation_minutes,
         r.previous_window_minutes, r.recommended_window_minutes,
         r.recommendation_status, r.applied_at
  FROM engineer_arrival_promise_refinement_r2800 r
  ORDER BY r.total_jobs DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_refinement_list_r2800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_refinement_list_r2800() TO authenticated;

DROP FUNCTION IF EXISTS founder_arrival_refinement_summary_r2800();
CREATE OR REPLACE FUNCTION founder_arrival_refinement_summary_r2800()
RETURNS TABLE(
  recommendation_status text,
  engineer_count bigint,
  avg_recommended_window numeric,
  applied_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.recommendation_status,
         COUNT(*)::bigint,
         ROUND(AVG(r.recommended_window_minutes)::numeric, 1),
         COUNT(*) FILTER (WHERE r.applied_at IS NOT NULL)::bigint
  FROM engineer_arrival_promise_refinement_r2800 r
  GROUP BY r.recommendation_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_refinement_summary_r2800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_refinement_summary_r2800() TO authenticated;

DROP FUNCTION IF EXISTS founder_arrival_worst_engineers_r2800();
CREATE OR REPLACE FUNCTION founder_arrival_worst_engineers_r2800()
RETURNS TABLE(
  engineer_name text,
  city text,
  late_jobs bigint,
  avg_late_minutes numeric,
  recommended_window_minutes integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT w.engineer_name, w.city,
         COUNT(*) FILTER (WHERE w.deviation_minutes > 0 AND NOT w.within_window)::bigint,
         ROUND(AVG(w.deviation_minutes) FILTER (WHERE w.deviation_minutes > 0)::numeric, 1),
         MAX(r.recommended_window_minutes)
  FROM engineer_arrival_window_precision_r2800 w
  LEFT JOIN engineer_arrival_promise_refinement_r2800 r ON r.engineer_name = w.engineer_name AND r.city = w.city
  GROUP BY w.engineer_name, w.city
  ORDER BY COUNT(*) FILTER (WHERE w.deviation_minutes > 0 AND NOT w.within_window) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_worst_engineers_r2800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_worst_engineers_r2800() TO authenticated;

DROP FUNCTION IF EXISTS founder_arrival_apply_refinement_r2800(uuid);
CREATE OR REPLACE FUNCTION founder_arrival_apply_refinement_r2800(p_id uuid)
RETURNS TABLE(
  id uuid,
  engineer_name text,
  recommended_window_minutes integer,
  applied_at timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  UPDATE engineer_arrival_promise_refinement_r2800
     SET applied_at = now()
   WHERE id = p_id
   RETURNING engineer_arrival_promise_refinement_r2800.id,
             engineer_arrival_promise_refinement_r2800.engineer_name,
             engineer_arrival_promise_refinement_r2800.recommended_window_minutes,
             engineer_arrival_promise_refinement_r2800.applied_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_arrival_apply_refinement_r2800(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_arrival_apply_refinement_r2800(uuid) TO authenticated;

COMMIT;
