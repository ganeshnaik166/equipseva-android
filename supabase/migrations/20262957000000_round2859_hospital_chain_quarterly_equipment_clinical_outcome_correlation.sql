BEGIN;

-- Round 2859: hospital chain × quarterly equipment × clinical outcome correlation

CREATE TABLE IF NOT EXISTS hospital_chain_quarterly_equipment_clinical_correlation_r2859 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  quarter text NOT NULL,
  equipment_category text NOT NULL,
  uptime_pct numeric(5,2) NOT NULL,
  clinical_metric text NOT NULL,
  metric_baseline numeric(8,2) NOT NULL,
  metric_observed numeric(8,2) NOT NULL,
  pearson_r numeric(5,3) NOT NULL,
  p_value numeric(6,4) NOT NULL,
  confidence_level text NOT NULL CHECK (confidence_level IN ('high','medium','low')),
  story_headline text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_quarterly_equipment_clinical_correlation_r2859 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_quarterly_equipment_clinical_correlation_r2859;
CREATE POLICY founder_all ON hospital_chain_quarterly_equipment_clinical_correlation_r2859
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_quarterly_equipment_clinical_correlation_r2859
  (chain_name, quarter, equipment_category, uptime_pct, clinical_metric, metric_baseline, metric_observed, pearson_r, p_value, confidence_level, story_headline)
VALUES
  ('Apollo Hospitals','2026-Q1','Ventilators',98.40,'ICU mortality % (lower is better)',12.30,9.80,-0.842,0.0034,'high','Ventilator uptime gain cut ICU mortality by 2.5 points'),
  ('Fortis Healthcare','2026-Q1','Imaging-CT',96.10,'Door-to-CT minutes (lower is better)',38.00,28.50,-0.781,0.0091,'high','CT uptime above 96% slashed door-to-CT by 25%'),
  ('Manipal Hospitals','2026-Q1','Dialysis',94.20,'Dialysis adequacy Kt/V (higher is better)',1.20,1.42,0.713,0.0142,'medium','Dialysis uptime lifted Kt/V adequacy above 1.4 threshold'),
  ('Max Healthcare','2026-Q1','Cath-Lab',92.80,'Door-to-balloon minutes (lower is better)',92.00,74.00,-0.689,0.0218,'medium','Cath-lab uptime drove door-to-balloon below 75 minutes'),
  ('Narayana Health','2026-Q1','Anesthesia-Workstations',97.50,'OR turnover minutes (lower is better)',42.00,33.00,-0.798,0.0067,'high','Anesthesia uptime cut OR turnover by 9 minutes'),
  ('Yashoda Hospitals','2026-Q1','Defibrillators',99.10,'Code-blue survival % (higher is better)',24.00,31.00,0.821,0.0048,'high','Defib readiness above 99% boosted code-blue survival to 31%'),
  ('KIMS Hospitals','2026-Q1','Endoscopy',91.30,'Procedure cancellations % (lower is better)',8.50,5.20,-0.654,0.0294,'medium','Endoscopy uptime cut cancellations by nearly 40%');

CREATE TABLE IF NOT EXISTS hospital_chain_quarterly_correlation_signals_r2859 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  quarter text NOT NULL,
  signal_type text NOT NULL CHECK (signal_type IN ('expand','investigate','escalate','celebrate','contract')),
  equipment_category text NOT NULL,
  delta_pct numeric(6,2) NOT NULL,
  recommended_action text NOT NULL,
  est_revenue_uplift_lakhs numeric(8,2) NOT NULL,
  owner_role text NOT NULL,
  due_by date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_quarterly_correlation_signals_r2859 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_quarterly_correlation_signals_r2859;
CREATE POLICY founder_all ON hospital_chain_quarterly_correlation_signals_r2859
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_quarterly_correlation_signals_r2859
  (chain_name, quarter, signal_type, equipment_category, delta_pct, recommended_action, est_revenue_uplift_lakhs, owner_role, due_by)
VALUES
  ('Apollo Hospitals','2026-Q1','expand','Ventilators',20.30,'Pitch chain-wide ventilator AMC at premium tier', 42.50,'enterprise_lead','2026-07-15'::date),
  ('Fortis Healthcare','2026-Q1','expand','Imaging-CT',25.00,'Bundle CT uptime SLA into Q2 renewal', 58.00,'enterprise_lead','2026-07-20'::date),
  ('Manipal Hospitals','2026-Q1','investigate','Dialysis',18.30,'Audit 2 outlier sites dragging Kt/V correlation', 0.00,'clinical_ops','2026-07-10'::date),
  ('Max Healthcare','2026-Q1','escalate','Cath-Lab',-19.60,'Engage cardiology head — door-to-balloon still above target', 32.00,'founder','2026-07-05'::date),
  ('Narayana Health','2026-Q1','celebrate','Anesthesia-Workstations',21.40,'Co-author case study with COO on OR turnover win', 25.00,'marketing','2026-07-25'::date),
  ('Yashoda Hospitals','2026-Q1','expand','Defibrillators',29.20,'Upsell tier-1 defib monitoring across all 9 sites', 38.50,'enterprise_lead','2026-07-18'::date),
  ('KIMS Hospitals','2026-Q1','expand','Endoscopy',38.80,'Renew endoscopy AMC at 18% uplift on cancellations data', 22.00,'account_manager','2026-07-22'::date);

DROP FUNCTION IF EXISTS r2859_overview();
CREATE FUNCTION r2859_overview()
RETURNS TABLE (
  total_correlations int,
  high_confidence int,
  strong_positive int,
  strong_negative int,
  avg_abs_pearson_r numeric,
  total_uplift_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::int FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859),
      (SELECT count(*)::int FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 WHERE confidence_level = 'high'),
      (SELECT count(*)::int FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 WHERE pearson_r >= 0.7),
      (SELECT count(*)::int FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 WHERE pearson_r <= -0.7),
      (SELECT round(avg(abs(pearson_r))::numeric, 3) FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859),
      (SELECT coalesce(sum(est_revenue_uplift_lakhs),0)::numeric FROM hospital_chain_quarterly_correlation_signals_r2859);
END;
$$;
REVOKE EXECUTE ON FUNCTION r2859_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2859_overview() TO authenticated;

DROP FUNCTION IF EXISTS r2859_list_correlations();
CREATE FUNCTION r2859_list_correlations()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter text,
  equipment_category text,
  uptime_pct numeric,
  clinical_metric text,
  metric_baseline numeric,
  metric_observed numeric,
  pearson_r numeric,
  p_value numeric,
  confidence_level text,
  story_headline text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.chain_name, c.quarter, c.equipment_category, c.uptime_pct, c.clinical_metric,
           c.metric_baseline, c.metric_observed, c.pearson_r, c.p_value, c.confidence_level, c.story_headline
    FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 c
    ORDER BY abs(c.pearson_r) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2859_list_correlations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2859_list_correlations() TO authenticated;

DROP FUNCTION IF EXISTS r2859_by_chain();
CREATE FUNCTION r2859_by_chain()
RETURNS TABLE (
  chain_name text,
  correlations int,
  high_conf int,
  avg_r numeric,
  uplift_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_name,
           count(*)::int,
           sum(CASE WHEN c.confidence_level='high' THEN 1 ELSE 0 END)::int,
           round(avg(abs(c.pearson_r))::numeric, 3),
           coalesce((SELECT sum(s.est_revenue_uplift_lakhs) FROM hospital_chain_quarterly_correlation_signals_r2859 s WHERE s.chain_name = c.chain_name), 0)::numeric
    FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 c
    GROUP BY c.chain_name
    ORDER BY uplift_lakhs DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2859_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2859_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS r2859_by_equipment();
CREATE FUNCTION r2859_by_equipment()
RETURNS TABLE (
  equipment_category text,
  correlations int,
  avg_uptime numeric,
  avg_abs_r numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.equipment_category,
           count(*)::int,
           round(avg(c.uptime_pct)::numeric, 2),
           round(avg(abs(c.pearson_r))::numeric, 3)
    FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 c
    GROUP BY c.equipment_category
    ORDER BY avg_abs_r DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2859_by_equipment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2859_by_equipment() TO authenticated;

DROP FUNCTION IF EXISTS r2859_list_signals();
CREATE FUNCTION r2859_list_signals()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter text,
  signal_type text,
  equipment_category text,
  delta_pct numeric,
  recommended_action text,
  est_revenue_uplift_lakhs numeric,
  owner_role text,
  due_by date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.quarter, s.signal_type, s.equipment_category, s.delta_pct,
           s.recommended_action, s.est_revenue_uplift_lakhs, s.owner_role, s.due_by
    FROM hospital_chain_quarterly_correlation_signals_r2859 s
    ORDER BY s.est_revenue_uplift_lakhs DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2859_list_signals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2859_list_signals() TO authenticated;

DROP FUNCTION IF EXISTS r2859_signal_mix();
CREATE FUNCTION r2859_signal_mix()
RETURNS TABLE (
  signal_type text,
  count_signals int,
  uplift_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.signal_type, count(*)::int, sum(s.est_revenue_uplift_lakhs)::numeric
    FROM hospital_chain_quarterly_correlation_signals_r2859 s
    GROUP BY s.signal_type
    ORDER BY uplift_lakhs DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2859_signal_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2859_signal_mix() TO authenticated;

DROP FUNCTION IF EXISTS r2859_top_stories();
CREATE FUNCTION r2859_top_stories()
RETURNS TABLE (
  chain_name text,
  equipment_category text,
  pearson_r numeric,
  confidence_level text,
  story_headline text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_name, c.equipment_category, c.pearson_r, c.confidence_level, c.story_headline
    FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 c
    WHERE c.confidence_level = 'high'
    ORDER BY abs(c.pearson_r) DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2859_top_stories() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2859_top_stories() TO authenticated;

COMMIT;
