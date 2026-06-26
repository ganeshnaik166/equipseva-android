BEGIN;

CREATE TABLE IF NOT EXISTS hospital_chain_imaging_center_uptime_r2819 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  center_name text NOT NULL,
  city text NOT NULL,
  modality text NOT NULL CHECK (modality IN ('mri','ct','xray','ultrasound','mammography','pet_ct','cath_lab')),
  quarter text NOT NULL,
  uptime_pct numeric(5,2) NOT NULL CHECK (uptime_pct >= 0 AND uptime_pct <= 100),
  scheduled_uptime_pct numeric(5,2) NOT NULL CHECK (scheduled_uptime_pct >= 0 AND scheduled_uptime_pct <= 100),
  downtime_hours numeric(8,2) NOT NULL CHECK (downtime_hours >= 0),
  unplanned_outages int NOT NULL CHECK (unplanned_outages >= 0),
  scans_per_day_target int NOT NULL CHECK (scans_per_day_target >= 0),
  scans_per_day_actual int NOT NULL CHECK (scans_per_day_actual >= 0),
  revenue_per_scan_rupees int NOT NULL CHECK (revenue_per_scan_rupees >= 0),
  revenue_loss_rupees bigint NOT NULL CHECK (revenue_loss_rupees >= 0),
  mttr_hours numeric(6,2) NOT NULL CHECK (mttr_hours >= 0),
  status text NOT NULL CHECK (status IN ('healthy','watch','degraded','critical')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_imaging_center_uptime_r2819 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_imaging_center_uptime_r2819;
CREATE POLICY founder_all ON hospital_chain_imaging_center_uptime_r2819 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_imaging_center_uptime_r2819 (chain_name, center_name, city, modality, quarter, uptime_pct, scheduled_uptime_pct, downtime_hours, unplanned_outages, scans_per_day_target, scans_per_day_actual, revenue_per_scan_rupees, revenue_loss_rupees, mttr_hours, status) VALUES
('Apollo Imaging Network','Apollo Jubilee Hills','Hyderabad','mri','Q2-2026',97.40,99.00,56.20,3,28,26,8500,2660000,4.50,'watch'),
('Apollo Imaging Network','Apollo Banjara Hills','Hyderabad','ct','Q2-2026',98.80,99.50,26.00,1,45,44,4200,840000,3.20,'healthy'),
('Manipal Diagnostics','Manipal Old Airport','Bengaluru','mri','Q2-2026',92.10,99.00,172.80,7,30,22,9000,7200000,9.80,'critical'),
('Manipal Diagnostics','Manipal Whitefield','Bengaluru','pet_ct','Q2-2026',95.20,98.50,105.10,4,12,10,28000,5040000,7.60,'degraded'),
('Fortis Healthcare','Fortis Bannerghatta','Bengaluru','cath_lab','Q2-2026',96.30,99.00,80.10,3,18,16,42000,6048000,5.40,'degraded'),
('Max Healthcare','Max Saket','Delhi','mammography','Q2-2026',99.30,99.50,15.20,1,22,22,3800,0,2.10,'healthy'),
('Yashoda Hospitals','Yashoda Secunderabad','Hyderabad','ultrasound','Q2-2026',99.10,99.50,19.80,2,55,54,1800,162000,1.80,'healthy');

CREATE TABLE IF NOT EXISTS hospital_chain_imaging_interventions_r2819 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uptime_id uuid REFERENCES hospital_chain_imaging_center_uptime_r2819(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  center_name text NOT NULL,
  modality text NOT NULL,
  intervention_type text NOT NULL CHECK (intervention_type IN ('amc_upgrade','spare_stock','engineer_assign','vendor_escalate','replacement_quote','training','remote_monitor')),
  recommendation text NOT NULL,
  owner text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('proposed','in_progress','completed','blocked')),
  projected_uptime_gain_pct numeric(5,2) NOT NULL CHECK (projected_uptime_gain_pct >= 0),
  projected_revenue_recovery_rupees bigint NOT NULL CHECK (projected_revenue_recovery_rupees >= 0),
  cost_rupees bigint NOT NULL CHECK (cost_rupees >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_imaging_interventions_r2819 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_imaging_interventions_r2819;
CREATE POLICY founder_all ON hospital_chain_imaging_interventions_r2819 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_imaging_interventions_r2819 (chain_name, center_name, modality, intervention_type, recommendation, owner, due_date, status, projected_uptime_gain_pct, projected_revenue_recovery_rupees, cost_rupees) VALUES
('Manipal Diagnostics','Manipal Old Airport','mri','vendor_escalate','Escalate GE Healthcare AMC for chronic coil failure; demand SLA refund','Ganesh','2026-07-10'::date,'in_progress',5.50,4200000,0),
('Manipal Diagnostics','Manipal Whitefield','pet_ct','spare_stock','Pre-stock cyclotron target replacement kit at Bengaluru hub','Ops Lead','2026-07-15'::date,'proposed',3.20,2400000,1800000),
('Fortis Healthcare','Fortis Bannerghatta','cath_lab','engineer_assign','Assign dedicated Tier-1 engineer for cath lab quarterly PM','Field Ops','2026-07-05'::date,'in_progress',2.40,3600000,400000),
('Apollo Imaging Network','Apollo Jubilee Hills','mri','remote_monitor','Deploy remote monitoring agent on MRI helium boil-off sensor','Engineering','2026-07-20'::date,'proposed',1.20,1800000,250000),
('Apollo Imaging Network','Apollo Banjara Hills','ct','amc_upgrade','Upgrade CT AMC from comprehensive-bronze to platinum','Sales','2026-08-01'::date,'proposed',0.50,600000,950000),
('Yashoda Hospitals','Yashoda Secunderabad','ultrasound','training','Sonographer probe-handling refresh; cuts probe replacements','Training','2026-07-12'::date,'completed',0.30,80000,40000);

DROP FUNCTION IF EXISTS founder_r2819_kpis();
CREATE OR REPLACE FUNCTION founder_r2819_kpis()
RETURNS TABLE (
  total_centers int,
  avg_uptime_pct numeric,
  critical_centers int,
  total_revenue_loss_rupees bigint,
  total_downtime_hours numeric,
  open_interventions int,
  projected_recovery_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT round(avg(uptime_pct),2) FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT count(*)::int FROM hospital_chain_imaging_center_uptime_r2819 WHERE status='critical'),
    (SELECT coalesce(sum(revenue_loss_rupees),0) FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT coalesce(sum(downtime_hours),0) FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT count(*)::int FROM hospital_chain_imaging_interventions_r2819 WHERE status IN ('proposed','in_progress')),
    (SELECT coalesce(sum(projected_revenue_recovery_rupees),0) FROM hospital_chain_imaging_interventions_r2819 WHERE status IN ('proposed','in_progress'));
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2819_uptime_rows();
CREATE OR REPLACE FUNCTION founder_r2819_uptime_rows()
RETURNS SETOF hospital_chain_imaging_center_uptime_r2819
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM hospital_chain_imaging_center_uptime_r2819 ORDER BY uptime_pct ASC, revenue_loss_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_uptime_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_uptime_rows() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2819_chain_rollup();
CREATE OR REPLACE FUNCTION founder_r2819_chain_rollup()
RETURNS TABLE (
  chain_name text,
  centers int,
  avg_uptime_pct numeric,
  total_downtime_hours numeric,
  total_revenue_loss_rupees bigint,
  critical_centers int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.chain_name,
    count(*)::int,
    round(avg(u.uptime_pct),2),
    sum(u.downtime_hours),
    sum(u.revenue_loss_rupees)::bigint,
    count(*) FILTER (WHERE u.status='critical')::int
  FROM hospital_chain_imaging_center_uptime_r2819 u
  GROUP BY u.chain_name
  ORDER BY sum(u.revenue_loss_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_chain_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2819_modality_rollup();
CREATE OR REPLACE FUNCTION founder_r2819_modality_rollup()
RETURNS TABLE (
  modality text,
  centers int,
  avg_uptime_pct numeric,
  total_revenue_loss_rupees bigint,
  avg_mttr_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.modality,
    count(*)::int,
    round(avg(u.uptime_pct),2),
    sum(u.revenue_loss_rupees)::bigint,
    round(avg(u.mttr_hours),2)
  FROM hospital_chain_imaging_center_uptime_r2819 u
  GROUP BY u.modality
  ORDER BY sum(u.revenue_loss_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_modality_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_modality_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2819_critical_centers();
CREATE OR REPLACE FUNCTION founder_r2819_critical_centers()
RETURNS TABLE (
  chain_name text,
  center_name text,
  modality text,
  uptime_pct numeric,
  revenue_loss_rupees bigint,
  mttr_hours numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.chain_name, u.center_name, u.modality, u.uptime_pct, u.revenue_loss_rupees, u.mttr_hours, u.status
  FROM hospital_chain_imaging_center_uptime_r2819 u
  WHERE u.status IN ('critical','degraded')
  ORDER BY u.revenue_loss_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_critical_centers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_critical_centers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2819_interventions();
CREATE OR REPLACE FUNCTION founder_r2819_interventions()
RETURNS SETOF hospital_chain_imaging_interventions_r2819
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM hospital_chain_imaging_interventions_r2819 ORDER BY due_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_interventions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_interventions() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2819_intervention_roi();
CREATE OR REPLACE FUNCTION founder_r2819_intervention_roi()
RETURNS TABLE (
  intervention_type text,
  count int,
  total_cost_rupees bigint,
  total_projected_recovery_rupees bigint,
  roi_multiple numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.intervention_type,
    count(*)::int,
    sum(i.cost_rupees)::bigint,
    sum(i.projected_revenue_recovery_rupees)::bigint,
    CASE WHEN sum(i.cost_rupees) = 0 THEN NULL ELSE round(sum(i.projected_revenue_recovery_rupees)::numeric / sum(i.cost_rupees)::numeric, 2) END
  FROM hospital_chain_imaging_interventions_r2819 i
  GROUP BY i.intervention_type
  ORDER BY sum(i.projected_revenue_recovery_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_intervention_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_intervention_roi() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2819_mark_intervention_status(uuid, text);
CREATE OR REPLACE FUNCTION founder_r2819_mark_intervention_status(p_id uuid, p_status text)
RETURNS hospital_chain_imaging_interventions_r2819
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE r hospital_chain_imaging_interventions_r2819;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('proposed','in_progress','completed','blocked') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE hospital_chain_imaging_interventions_r2819 SET status = p_status WHERE id = p_id RETURNING * INTO r;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2819_mark_intervention_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2819_mark_intervention_status(uuid, text) TO authenticated;

COMMIT;
