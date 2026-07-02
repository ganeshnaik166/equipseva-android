BEGIN;

-- ============================================================================
-- Round 2720: Customer Monthly Replacement Loaner Fulfillment
-- Tracks loaner unit dispatch when customer equipment is in long repair
-- request x kind x promised x delivered x duration x satisfaction x outcome
-- ============================================================================

CREATE TABLE IF NOT EXISTS customer_loaner_requests_r2720 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_code text NOT NULL UNIQUE,
  customer_org text NOT NULL,
  equipment_kind text NOT NULL CHECK (equipment_kind IN ('ultrasound','ventilator','monitor','infusion_pump','xray_portable','autoclave','ecg','defibrillator')),
  request_reason text NOT NULL CHECK (request_reason IN ('extended_repair','part_backorder','warranty_swap','amc_clause','goodwill','disaster_recovery')),
  promised_delivery_at timestamptz NOT NULL,
  actual_delivered_at timestamptz,
  loaner_returned_at timestamptz,
  duration_days int,
  satisfaction_score numeric(3,1) CHECK (satisfaction_score IS NULL OR (satisfaction_score >= 0 AND satisfaction_score <= 10)),
  outcome text NOT NULL CHECK (outcome IN ('pending','delivered_ontime','delivered_late','cancelled','converted_to_sale','escalated')),
  daily_rate_rupees int NOT NULL DEFAULT 0,
  total_billed_rupees int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_loaner_requests_r2720 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_loaner_requests_r2720;
CREATE POLICY founder_all ON customer_loaner_requests_r2720 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS customer_loaner_inventory_r2720 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_tag text NOT NULL UNIQUE,
  equipment_kind text NOT NULL CHECK (equipment_kind IN ('ultrasound','ventilator','monitor','infusion_pump','xray_portable','autoclave','ecg','defibrillator')),
  status text NOT NULL CHECK (status IN ('available','deployed','maintenance','retired','in_transit')),
  current_request_id uuid REFERENCES customer_loaner_requests_r2720(id),
  total_deployments int NOT NULL DEFAULT 0,
  total_revenue_rupees int NOT NULL DEFAULT 0,
  last_serviced_at timestamptz,
  acquired_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_loaner_inventory_r2720 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_loaner_inventory_r2720;
CREATE POLICY founder_all ON customer_loaner_inventory_r2720 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed loaner requests
INSERT INTO customer_loaner_requests_r2720
  (request_code, customer_org, equipment_kind, request_reason, promised_delivery_at, actual_delivered_at, loaner_returned_at, duration_days, satisfaction_score, outcome, daily_rate_rupees, total_billed_rupees, notes)
VALUES
  ('LR-2026-0411','Apollo Jubilee','ultrasound','extended_repair','2026-06-15 10:00:00+05:30'::timestamptz,'2026-06-15 09:42:00+05:30'::timestamptz,'2026-06-22 18:00:00+05:30'::timestamptz,7,9.4,'delivered_ontime',2500,17500,'Smooth handoff; cardio dept happy'),
  ('LR-2026-0412','Yashoda Secunderabad','ventilator','part_backorder','2026-06-12 09:00:00+05:30'::timestamptz,'2026-06-12 16:30:00+05:30'::timestamptz,'2026-06-24 12:00:00+05:30'::timestamptz,12,8.2,'delivered_late',4000,48000,'Late by 7h due to traffic; ICU absorbed it'),
  ('LR-2026-0413','KIMS Kondapur','monitor','warranty_swap','2026-06-18 11:00:00+05:30'::timestamptz,'2026-06-18 10:55:00+05:30'::timestamptz,NULL,NULL,NULL,'pending',1500,0,'Active deployment; OEM unit due Jun-28'),
  ('LR-2026-0414','Star Banjara','infusion_pump','amc_clause','2026-06-10 14:00:00+05:30'::timestamptz,'2026-06-10 13:50:00+05:30'::timestamptz,'2026-06-13 09:00:00+05:30'::timestamptz,3,9.8,'delivered_ontime',800,2400,'Free per AMC Gold tier'),
  ('LR-2026-0415','Sunshine Paradise','xray_portable','disaster_recovery','2026-06-08 08:00:00+05:30'::timestamptz,'2026-06-08 07:30:00+05:30'::timestamptz,'2026-06-09 20:00:00+05:30'::timestamptz,2,9.6,'delivered_ontime',5000,10000,'Flood damage; expedited dispatch'),
  ('LR-2026-0416','Care Hospitals HiTec','autoclave','extended_repair','2026-06-14 12:00:00+05:30'::timestamptz,NULL,NULL,NULL,NULL,'cancelled',1200,0,'Customer found local rental cheaper'),
  ('LR-2026-0417','Continental Gachibowli','ecg','warranty_swap','2026-06-16 10:00:00+05:30'::timestamptz,'2026-06-16 11:45:00+05:30'::timestamptz,NULL,5,7.5,'converted_to_sale',600,3000,'Loved unit; bought outright Jun-21'),
  ('LR-2026-0418','AIG Hospitals','defibrillator','goodwill','2026-06-09 13:00:00+05:30'::timestamptz,'2026-06-09 14:20:00+05:30'::timestamptz,'2026-06-11 17:00:00+05:30'::timestamptz,2,6.8,'escalated',0,0,'Unit beeped; replaced with backup');

-- Seed inventory
INSERT INTO customer_loaner_inventory_r2720
  (asset_tag, equipment_kind, status, total_deployments, total_revenue_rupees, last_serviced_at, acquired_at)
VALUES
  ('LOAN-US-001','ultrasound','available',14,287500,'2026-06-20 10:00:00+05:30'::timestamptz,'2025-01-10 09:00:00+05:30'::timestamptz),
  ('LOAN-VT-002','ventilator','deployed',8,512000,'2026-05-30 11:00:00+05:30'::timestamptz,'2025-02-15 10:00:00+05:30'::timestamptz),
  ('LOAN-MN-003','monitor','deployed',22,198000,'2026-06-15 14:00:00+05:30'::timestamptz,'2024-11-05 09:00:00+05:30'::timestamptz),
  ('LOAN-IP-004','infusion_pump','available',31,74400,'2026-06-18 09:00:00+05:30'::timestamptz,'2024-08-20 10:00:00+05:30'::timestamptz),
  ('LOAN-XR-005','xray_portable','maintenance',5,150000,'2026-06-21 08:00:00+05:30'::timestamptz,'2025-03-12 10:00:00+05:30'::timestamptz),
  ('LOAN-AC-006','autoclave','available',9,86400,'2026-06-10 12:00:00+05:30'::timestamptz,'2025-05-05 09:00:00+05:30'::timestamptz),
  ('LOAN-EC-007','ecg','deployed',18,54000,'2026-06-12 11:00:00+05:30'::timestamptz,'2024-09-18 09:00:00+05:30'::timestamptz),
  ('LOAN-DF-008','defibrillator','retired',12,0,'2026-06-09 16:00:00+05:30'::timestamptz,'2024-04-01 09:00:00+05:30'::timestamptz);

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_loaner_kpis_r2720();
CREATE FUNCTION founder_loaner_kpis_r2720()
RETURNS TABLE(
  total_requests bigint,
  active_deployments bigint,
  on_time_rate numeric,
  avg_satisfaction numeric,
  avg_duration_days numeric,
  total_billed_rupees bigint,
  cancelled_count bigint,
  escalated_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE outcome = 'pending')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE outcome = 'delivered_ontime') / NULLIF(COUNT(*) FILTER (WHERE outcome IN ('delivered_ontime','delivered_late')),0), 1),
    ROUND(AVG(satisfaction_score)::numeric, 2),
    ROUND(AVG(duration_days)::numeric, 1),
    COALESCE(SUM(total_billed_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE outcome = 'cancelled')::bigint,
    COUNT(*) FILTER (WHERE outcome = 'escalated')::bigint
  FROM customer_loaner_requests_r2720;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_kpis_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_kpis_r2720() TO authenticated;

DROP FUNCTION IF EXISTS founder_loaner_requests_list_r2720();
CREATE FUNCTION founder_loaner_requests_list_r2720()
RETURNS TABLE(
  request_code text,
  customer_org text,
  equipment_kind text,
  request_reason text,
  promised_delivery_at timestamptz,
  actual_delivered_at timestamptz,
  duration_days int,
  satisfaction_score numeric,
  outcome text,
  total_billed_rupees int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.request_code, r.customer_org, r.equipment_kind, r.request_reason,
         r.promised_delivery_at, r.actual_delivered_at, r.duration_days,
         r.satisfaction_score, r.outcome, r.total_billed_rupees
  FROM customer_loaner_requests_r2720 r
  ORDER BY r.promised_delivery_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_requests_list_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_requests_list_r2720() TO authenticated;

DROP FUNCTION IF EXISTS founder_loaner_by_kind_r2720();
CREATE FUNCTION founder_loaner_by_kind_r2720()
RETURNS TABLE(
  equipment_kind text,
  request_count bigint,
  avg_duration numeric,
  avg_satisfaction numeric,
  total_revenue bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_kind,
         COUNT(*)::bigint,
         ROUND(AVG(r.duration_days)::numeric, 1),
         ROUND(AVG(r.satisfaction_score)::numeric, 2),
         COALESCE(SUM(r.total_billed_rupees),0)::bigint
  FROM customer_loaner_requests_r2720 r
  GROUP BY r.equipment_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_by_kind_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_by_kind_r2720() TO authenticated;

DROP FUNCTION IF EXISTS founder_loaner_by_reason_r2720();
CREATE FUNCTION founder_loaner_by_reason_r2720()
RETURNS TABLE(
  request_reason text,
  request_count bigint,
  ontime_count bigint,
  late_count bigint,
  avg_satisfaction numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.request_reason,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE r.outcome = 'delivered_ontime')::bigint,
         COUNT(*) FILTER (WHERE r.outcome = 'delivered_late')::bigint,
         ROUND(AVG(r.satisfaction_score)::numeric, 2)
  FROM customer_loaner_requests_r2720 r
  GROUP BY r.request_reason
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_by_reason_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_by_reason_r2720() TO authenticated;

DROP FUNCTION IF EXISTS founder_loaner_inventory_status_r2720();
CREATE FUNCTION founder_loaner_inventory_status_r2720()
RETURNS TABLE(
  asset_tag text,
  equipment_kind text,
  status text,
  total_deployments int,
  total_revenue_rupees int,
  last_serviced_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.asset_tag, i.equipment_kind, i.status, i.total_deployments,
         i.total_revenue_rupees, i.last_serviced_at
  FROM customer_loaner_inventory_r2720 i
  ORDER BY i.total_revenue_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_inventory_status_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_inventory_status_r2720() TO authenticated;

DROP FUNCTION IF EXISTS founder_loaner_outcome_breakdown_r2720();
CREATE FUNCTION founder_loaner_outcome_breakdown_r2720()
RETURNS TABLE(
  outcome text,
  count bigint,
  pct numeric,
  revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM customer_loaner_requests_r2720;
  RETURN QUERY
  SELECT r.outcome,
         COUNT(*)::bigint,
         ROUND(100.0 * COUNT(*) / NULLIF(total,0), 1),
         COALESCE(SUM(r.total_billed_rupees),0)::bigint
  FROM customer_loaner_requests_r2720 r
  GROUP BY r.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_outcome_breakdown_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_outcome_breakdown_r2720() TO authenticated;

DROP FUNCTION IF EXISTS founder_loaner_satisfaction_by_customer_r2720();
CREATE FUNCTION founder_loaner_satisfaction_by_customer_r2720()
RETURNS TABLE(
  customer_org text,
  request_count bigint,
  avg_satisfaction numeric,
  total_billed bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.customer_org,
         COUNT(*)::bigint,
         ROUND(AVG(r.satisfaction_score)::numeric, 2),
         COALESCE(SUM(r.total_billed_rupees),0)::bigint
  FROM customer_loaner_requests_r2720 r
  GROUP BY r.customer_org
  ORDER BY AVG(r.satisfaction_score) DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_satisfaction_by_customer_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_satisfaction_by_customer_r2720() TO authenticated;

DROP FUNCTION IF EXISTS founder_loaner_delivery_promise_r2720();
CREATE FUNCTION founder_loaner_delivery_promise_r2720()
RETURNS TABLE(
  request_code text,
  customer_org text,
  promised_delivery_at timestamptz,
  actual_delivered_at timestamptz,
  delay_minutes numeric,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.request_code, r.customer_org, r.promised_delivery_at, r.actual_delivered_at,
         CASE WHEN r.actual_delivered_at IS NULL THEN NULL
              ELSE ROUND(EXTRACT(EPOCH FROM (r.actual_delivered_at - r.promised_delivery_at))/60.0, 1)
         END,
         r.outcome
  FROM customer_loaner_requests_r2720 r
  WHERE r.outcome IN ('delivered_ontime','delivered_late','converted_to_sale','escalated')
  ORDER BY r.promised_delivery_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_loaner_delivery_promise_r2720() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loaner_delivery_promise_r2720() TO authenticated;

COMMIT;
