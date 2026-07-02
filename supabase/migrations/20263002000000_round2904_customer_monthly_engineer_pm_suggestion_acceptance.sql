-- Round 2904: Customer Monthly Engineer-Initiated Preventive-Maintenance Suggestion Acceptance
-- Batch 400 milestone HEAVY founder ops round

BEGIN;

-- ============================================================================
-- TABLE 1: engineer_pm_suggestions_r2904
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_pm_suggestions_r2904 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  suggested_at timestamptz NOT NULL,
  engineer_user_id uuid,
  customer_org_id uuid,
  customer_org_name text NOT NULL,
  city text NOT NULL,
  device_category text NOT NULL,
  device_model text NOT NULL,
  pm_task_summary text NOT NULL,
  estimated_rupees integer NOT NULL,
  urgency text NOT NULL CHECK (urgency IN ('low','medium','high','critical')),
  status text NOT NULL CHECK (status IN ('pending','accepted','declined','expired','converted_to_job')),
  decided_at timestamptz,
  acceptance_lag_hours numeric,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  rationale text
);

ALTER TABLE public.engineer_pm_suggestions_r2904 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.engineer_pm_suggestions_r2904
  (suggested_at, customer_org_name, city, device_category, device_model, pm_task_summary, estimated_rupees, urgency, status, decided_at, acceptance_lag_hours, engineer_tier, rationale)
VALUES
  ('2026-06-01 09:12:00'::timestamptz,'Apollo Jubilee Hills','Hyderabad','Ventilator','Drager Evita V300','Replace O2 sensor + calibrate flow',4200,'high','accepted','2026-06-01 14:30:00'::timestamptz,5.3,'gold','sensor drift detected last visit'),
  ('2026-06-02 10:05:00'::timestamptz,'Yashoda Secunderabad','Hyderabad','Anesthesia','GE Aisys CS2','Vaporizer service + leak test',6800,'medium','accepted','2026-06-03 08:00:00'::timestamptz,21.9,'platinum','annual PM due'),
  ('2026-06-03 11:30:00'::timestamptz,'KIMS Kondapur','Hyderabad','Ultrasound','Philips EPIQ 7','Probe cable inspection + transducer clean',2500,'low','declined','2026-06-05 16:00:00'::timestamptz,52.5,'silver','budget constraint cited'),
  ('2026-06-04 14:20:00'::timestamptz,'Care Banjara Hills','Hyderabad','Patient Monitor','Mindray BeneVision N15','Battery replacement + ECG calibration',3100,'medium','accepted','2026-06-04 18:00:00'::timestamptz,3.7,'gold','battery health 38%'),
  ('2026-06-05 08:45:00'::timestamptz,'Sunshine Paradise','Hyderabad','Defibrillator','Philips HeartStart XL+','Pad expiry replacement + capacitor test',5500,'critical','accepted','2026-06-05 09:30:00'::timestamptz,0.75,'platinum','pad expiry 7d'),
  ('2026-06-06 12:00:00'::timestamptz,'Manipal Old Airport','Bangalore','MRI','Siemens Magnetom Aera','Cold head check + helium top-up advisory',38000,'high','pending',NULL,NULL,'platinum','helium boil-off trending up'),
  ('2026-06-07 13:15:00'::timestamptz,'Fortis Bannerghatta','Bangalore','CT Scanner','GE Revolution EVO','Tube cooling fan service',8200,'medium','accepted','2026-06-08 11:00:00'::timestamptz,21.75,'gold','fan vibration logged'),
  ('2026-06-08 09:30:00'::timestamptz,'Aster CMI','Bangalore','Ventilator','Hamilton C3','Expiratory valve clean + flow sensor',3800,'medium','converted_to_job','2026-06-08 12:00:00'::timestamptz,2.5,'silver','ICU usage high'),
  ('2026-06-09 15:50:00'::timestamptz,'Narayana Health City','Bangalore','C-Arm','Ziehm Vision RFD','Image intensifier calibration',12500,'low','declined','2026-06-12 10:00:00'::timestamptz,66.2,'gold','already scheduled with OEM'),
  ('2026-06-10 11:10:00'::timestamptz,'Columbia Asia Yeshwanthpur','Bangalore','Dialysis','Fresenius 4008S','RO water test + concentrate lines',4500,'high','accepted','2026-06-10 13:00:00'::timestamptz,1.83,'platinum','conductivity alarm prior week'),
  ('2026-06-11 08:00:00'::timestamptz,'Lilavati Mumbai','Mumbai','Endoscope','Olympus CV-190','Channel flush + bite block stock',2200,'low','expired',NULL,NULL,'bronze','no response 72h'),
  ('2026-06-12 14:45:00'::timestamptz,'Kokilaben Andheri','Mumbai','Linear Accelerator','Varian TrueBeam','Daily QA + MLC leaf calibration',45000,'critical','accepted','2026-06-12 16:00:00'::timestamptz,1.25,'platinum','radiation QA window'),
  ('2026-06-13 10:20:00'::timestamptz,'Hinduja Mahim','Mumbai','Mammography','Hologic Selenia','Compression paddle alignment',3600,'medium','accepted','2026-06-14 09:00:00'::timestamptz,22.67,'gold','accreditation audit Dec'),
  ('2026-06-14 16:30:00'::timestamptz,'Jaslok Mumbai','Mumbai','Infusion Pump','BD Alaris GP','Battery pack swap fleet of 20',8000,'medium','converted_to_job','2026-06-15 10:00:00'::timestamptz,17.5,'silver','battery <2yr policy'),
  ('2026-06-15 09:00:00'::timestamptz,'AIIMS Delhi','Delhi','Ventilator','Drager Savina 300','Inspiratory valve service',4100,'high','accepted','2026-06-15 11:30:00'::timestamptz,2.5,'platinum','peak ICU census'),
  ('2026-06-16 13:00:00'::timestamptz,'Max Saket','Delhi','Patient Monitor','GE B450','Touchscreen recalibration fleet 8',5200,'low','declined','2026-06-18 14:00:00'::timestamptz,49.0,'bronze','deferred to Q3'),
  ('2026-06-17 11:45:00'::timestamptz,'Sir Ganga Ram','Delhi','Anesthesia','Mindray A7','APL valve service + soda lime',2900,'medium','accepted','2026-06-17 15:00:00'::timestamptz,3.25,'gold','OT prep'),
  ('2026-06-18 08:30:00'::timestamptz,'Fortis Vasant Kunj','Delhi','Defibrillator','Zoll R Series','Battery replacement + analyze test',4800,'high','accepted','2026-06-18 10:00:00'::timestamptz,1.5,'platinum','battery cycle count'),
  ('2026-06-19 14:00:00'::timestamptz,'Medanta Gurugram','Delhi','ECMO','Maquet CardioHelp','Pump head replacement advisory',62000,'critical','pending',NULL,NULL,'platinum','runtime hours threshold'),
  ('2026-06-20 10:00:00'::timestamptz,'Apollo Chennai Greams','Chennai','Ultrasound','Samsung HS70A','Probe gel reservoir + cable inspect',2400,'low','accepted','2026-06-20 13:00:00'::timestamptz,3.0,'silver','user reported intermittent image');

-- ============================================================================
-- TABLE 2: customer_acceptance_outcomes_r2904
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_acceptance_outcomes_r2904 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  suggestion_id uuid,
  customer_org_name text NOT NULL,
  city text NOT NULL,
  outcome_month date NOT NULL,
  total_suggestions integer NOT NULL,
  accepted_count integer NOT NULL,
  declined_count integer NOT NULL,
  expired_count integer NOT NULL,
  revenue_realized_rupees integer NOT NULL,
  revenue_lost_rupees integer NOT NULL,
  csat_score numeric NOT NULL,
  retention_signal text NOT NULL CHECK (retention_signal IN ('strong','stable','at_risk','churning'))
);

ALTER TABLE public.customer_acceptance_outcomes_r2904 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.customer_acceptance_outcomes_r2904
  (customer_org_name, city, outcome_month, total_suggestions, accepted_count, declined_count, expired_count, revenue_realized_rupees, revenue_lost_rupees, csat_score, retention_signal)
VALUES
  ('Apollo Jubilee Hills','Hyderabad','2026-06-01'::date,12,10,1,1,48500,3200,4.7,'strong'),
  ('Yashoda Secunderabad','Hyderabad','2026-06-01'::date,8,7,1,0,52000,2500,4.8,'strong'),
  ('KIMS Kondapur','Hyderabad','2026-06-01'::date,6,3,2,1,12500,9800,3.9,'at_risk'),
  ('Care Banjara Hills','Hyderabad','2026-06-01'::date,9,8,1,0,28400,1800,4.6,'strong'),
  ('Sunshine Paradise','Hyderabad','2026-06-01'::date,5,5,0,0,22000,0,4.9,'strong'),
  ('Manipal Old Airport','Bangalore','2026-06-01'::date,11,8,2,1,71000,12500,4.3,'stable'),
  ('Fortis Bannerghatta','Bangalore','2026-06-01'::date,10,9,1,0,58000,3000,4.7,'strong'),
  ('Aster CMI','Bangalore','2026-06-01'::date,7,6,1,0,24000,4500,4.5,'stable'),
  ('Narayana Health City','Bangalore','2026-06-01'::date,8,4,3,1,38000,22000,3.7,'at_risk'),
  ('Columbia Asia Yeshwanthpur','Bangalore','2026-06-01'::date,6,6,0,0,31000,0,4.8,'strong'),
  ('Lilavati Mumbai','Mumbai','2026-06-01'::date,9,4,2,3,18000,15000,3.4,'churning'),
  ('Kokilaben Andheri','Mumbai','2026-06-01'::date,14,13,1,0,142000,8000,4.9,'strong'),
  ('Hinduja Mahim','Mumbai','2026-06-01'::date,10,9,1,0,46500,4200,4.6,'strong'),
  ('Jaslok Mumbai','Mumbai','2026-06-01'::date,7,5,1,1,29000,7500,4.2,'stable'),
  ('AIIMS Delhi','Delhi','2026-06-01'::date,15,14,1,0,89000,5200,4.8,'strong'),
  ('Max Saket','Delhi','2026-06-01'::date,11,6,4,1,32500,18900,3.8,'at_risk'),
  ('Sir Ganga Ram','Delhi','2026-06-01'::date,9,8,1,0,34500,2900,4.6,'strong'),
  ('Fortis Vasant Kunj','Delhi','2026-06-01'::date,8,7,1,0,38000,3500,4.7,'strong'),
  ('Medanta Gurugram','Delhi','2026-06-01'::date,12,10,1,1,96000,9800,4.5,'stable'),
  ('Apollo Chennai Greams','Chennai','2026-06-01'::date,9,7,2,0,28000,6200,4.3,'stable'),
  ('Apollo Jubilee Hills','Hyderabad','2026-05-01'::date,11,9,1,1,42000,4500,4.6,'strong'),
  ('KIMS Kondapur','Hyderabad','2026-05-01'::date,7,5,1,1,18500,5400,4.1,'stable'),
  ('Lilavati Mumbai','Mumbai','2026-05-01'::date,8,5,2,1,20500,11000,3.7,'at_risk'),
  ('Max Saket','Delhi','2026-05-01'::date,10,7,2,1,38000,12500,4.0,'stable');

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r2904_kpi_summary()
RETURNS TABLE(metric text, value text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT 'total_suggestions'::text, COUNT(*)::text FROM engineer_pm_suggestions_r2904
    UNION ALL SELECT 'accepted'::text, COUNT(*)::text FROM engineer_pm_suggestions_r2904 WHERE status='accepted'
    UNION ALL SELECT 'declined'::text, COUNT(*)::text FROM engineer_pm_suggestions_r2904 WHERE status='declined'
    UNION ALL SELECT 'pending'::text, COUNT(*)::text FROM engineer_pm_suggestions_r2904 WHERE status='pending'
    UNION ALL SELECT 'converted_jobs'::text, COUNT(*)::text FROM engineer_pm_suggestions_r2904 WHERE status='converted_to_job'
    UNION ALL SELECT 'revenue_realized_rupees'::text, COALESCE(SUM(revenue_realized_rupees),0)::text FROM customer_acceptance_outcomes_r2904
    UNION ALL SELECT 'revenue_lost_rupees'::text, COALESCE(SUM(revenue_lost_rupees),0)::text FROM customer_acceptance_outcomes_r2904
    UNION ALL SELECT 'avg_acceptance_lag_hours'::text, ROUND(AVG(acceptance_lag_hours)::numeric,2)::text FROM engineer_pm_suggestions_r2904 WHERE acceptance_lag_hours IS NOT NULL;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_kpi_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2904_recent_suggestions()
RETURNS TABLE(id uuid, suggested_at timestamptz, customer_org_name text, city text, device_model text, pm_task_summary text, estimated_rupees integer, urgency text, status text, engineer_tier text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.suggested_at, s.customer_org_name, s.city, s.device_model, s.pm_task_summary, s.estimated_rupees, s.urgency, s.status, s.engineer_tier
    FROM engineer_pm_suggestions_r2904 s
    ORDER BY s.suggested_at DESC
    LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_recent_suggestions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_recent_suggestions() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2904_acceptance_by_city()
RETURNS TABLE(city text, total bigint, accepted bigint, acceptance_rate numeric, avg_lag_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.city,
           COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE s.status IN ('accepted','converted_to_job'))::bigint,
           ROUND(100.0 * COUNT(*) FILTER (WHERE s.status IN ('accepted','converted_to_job')) / NULLIF(COUNT(*),0), 1),
           ROUND(AVG(s.acceptance_lag_hours)::numeric, 2)
    FROM engineer_pm_suggestions_r2904 s
    GROUP BY s.city
    ORDER BY 4 DESC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_acceptance_by_city() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_acceptance_by_city() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2904_acceptance_by_tier()
RETURNS TABLE(engineer_tier text, total bigint, accepted bigint, acceptance_rate numeric, total_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_tier,
           COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE s.status IN ('accepted','converted_to_job'))::bigint,
           ROUND(100.0 * COUNT(*) FILTER (WHERE s.status IN ('accepted','converted_to_job')) / NULLIF(COUNT(*),0), 1),
           SUM(s.estimated_rupees) FILTER (WHERE s.status IN ('accepted','converted_to_job'))::bigint
    FROM engineer_pm_suggestions_r2904 s
    GROUP BY s.engineer_tier
    ORDER BY 4 DESC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_acceptance_by_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_acceptance_by_tier() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2904_customer_outcomes()
RETURNS TABLE(customer_org_name text, city text, outcome_month date, total_suggestions integer, accepted_count integer, revenue_realized_rupees integer, revenue_lost_rupees integer, csat_score numeric, retention_signal text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.customer_org_name, o.city, o.outcome_month, o.total_suggestions, o.accepted_count, o.revenue_realized_rupees, o.revenue_lost_rupees, o.csat_score, o.retention_signal
    FROM customer_acceptance_outcomes_r2904 o
    ORDER BY o.outcome_month DESC, o.revenue_realized_rupees DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_customer_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_customer_outcomes() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2904_at_risk_customers()
RETURNS TABLE(customer_org_name text, city text, retention_signal text, total_suggestions integer, accepted_count integer, declined_count integer, expired_count integer, revenue_lost_rupees integer, csat_score numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.customer_org_name, o.city, o.retention_signal, o.total_suggestions, o.accepted_count, o.declined_count, o.expired_count, o.revenue_lost_rupees, o.csat_score
    FROM customer_acceptance_outcomes_r2904 o
    WHERE o.retention_signal IN ('at_risk','churning')
    ORDER BY o.revenue_lost_rupees DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_at_risk_customers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_at_risk_customers() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2904_urgency_funnel()
RETURNS TABLE(urgency text, total bigint, accepted bigint, declined bigint, pending bigint, expired bigint, conversion_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.urgency,
           COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE s.status IN ('accepted','converted_to_job'))::bigint,
           COUNT(*) FILTER (WHERE s.status='declined')::bigint,
           COUNT(*) FILTER (WHERE s.status='pending')::bigint,
           COUNT(*) FILTER (WHERE s.status='expired')::bigint,
           ROUND(100.0 * COUNT(*) FILTER (WHERE s.status IN ('accepted','converted_to_job')) / NULLIF(COUNT(*),0), 1)
    FROM engineer_pm_suggestions_r2904 s
    GROUP BY s.urgency
    ORDER BY CASE s.urgency WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_urgency_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_urgency_funnel() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2904_revenue_by_device_category()
RETURNS TABLE(device_category text, total_suggested bigint, total_accepted bigint, accepted_value_rupees bigint, lost_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.device_category,
           COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE s.status IN ('accepted','converted_to_job'))::bigint,
           COALESCE(SUM(s.estimated_rupees) FILTER (WHERE s.status IN ('accepted','converted_to_job')),0)::bigint,
           COALESCE(SUM(s.estimated_rupees) FILTER (WHERE s.status IN ('declined','expired')),0)::bigint
    FROM engineer_pm_suggestions_r2904 s
    GROUP BY s.device_category
    ORDER BY 4 DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.r2904_revenue_by_device_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2904_revenue_by_device_category() TO authenticated;

COMMIT;
