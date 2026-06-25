BEGIN;

-- ============================================================
-- Round 2672 - Customer Monthly Spare Parts Burn Rate Watch
-- ============================================================

-- ------------------------------------------------------------
-- Table 1: equipment burn snapshots
-- ------------------------------------------------------------
DROP TABLE IF EXISTS customer_spare_parts_burn_snapshots_r2672 CASCADE;

CREATE TABLE customer_spare_parts_burn_snapshots_r2672 (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_month date NOT NULL,
    customer_org_name text NOT NULL,
    equipment_label text NOT NULL,
    equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','dental','lab','surgical','monitoring','sterilizer','icu')),
    parts_consumed_count integer NOT NULL DEFAULT 0,
    parts_burn_rupees bigint NOT NULL DEFAULT 0,
    monthly_budget_rupees bigint NOT NULL DEFAULT 0,
    variance_rupees bigint NOT NULL DEFAULT 0,
    variance_pct numeric(6,2) NOT NULL DEFAULT 0,
    burn_status text NOT NULL CHECK (burn_status IN ('under','on_track','watch','over','critical')),
    top_part_name text,
    root_cause_code text NOT NULL CHECK (root_cause_code IN ('wear_tear','operator_error','env_humidity','env_voltage','overuse','aging','batch_defect','unknown')),
    corrective_action text,
    owner_engineer_email text,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_spare_parts_burn_snapshots_r2672 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_spare_parts_burn_snapshots_r2672;
CREATE POLICY founder_all ON customer_spare_parts_burn_snapshots_r2672
    FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_spare_parts_burn_snapshots_r2672
    (snapshot_month, customer_org_name, equipment_label, equipment_category, parts_consumed_count, parts_burn_rupees, monthly_budget_rupees, variance_rupees, variance_pct, burn_status, top_part_name, root_cause_code, corrective_action, owner_engineer_email)
VALUES
    ('2026-06-01','Apollo Jubilee','CT Scanner GE Optima 660','imaging',12,184500,150000,34500,23.00,'over','X-ray tube bearing','wear_tear','Schedule preventive bearing swap Q3','ravi.engineer@equipseva.com'),
    ('2026-06-01','KIMS Secunderabad','Dental Chair Sirona C2','dental',6,42000,60000,-18000,-30.00,'under','Suction valve','wear_tear','Continue current cadence','sneha.engineer@equipseva.com'),
    ('2026-06-01','Yashoda Somajiguda','Anesthesia Workstation Drager Fabius','surgical',9,128000,110000,18000,16.36,'watch','Vaporizer O-ring kit','env_humidity','Add humidity logger; review HVAC SOP','arjun.engineer@equipseva.com'),
    ('2026-06-01','Continental Gachibowli','Patient Monitor Philips IntelliVue','monitoring',4,18500,25000,-6500,-26.00,'under','SpO2 finger probe','operator_error','Operator retrain scheduled 2026-07-02','priya.engineer@equipseva.com'),
    ('2026-06-01','Care Banjara','Autoclave Tuttnauer 5075EHS','sterilizer',7,96000,70000,26000,37.14,'critical','Door gasket','aging','Replace gasket + recalibrate door switch','karthik.engineer@equipseva.com'),
    ('2026-06-01','Sunshine Paradise','Defib Philips HeartStart','icu',2,8500,12000,-3500,-29.17,'under','Pad cable','wear_tear','No action','sneha.engineer@equipseva.com'),
    ('2026-06-01','Rainbow Banjara','Phototherapy Unit Atom','icu',5,34000,30000,4000,13.33,'on_track','LED panel','overuse','Rotate units across NICU rooms','arjun.engineer@equipseva.com');

-- ------------------------------------------------------------
-- Table 2: corrective action tracker
-- ------------------------------------------------------------
DROP TABLE IF EXISTS customer_spare_parts_corrective_actions_r2672 CASCADE;

CREATE TABLE customer_spare_parts_corrective_actions_r2672 (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id uuid REFERENCES customer_spare_parts_burn_snapshots_r2672(id) ON DELETE CASCADE,
    customer_org_name text NOT NULL,
    equipment_label text NOT NULL,
    action_title text NOT NULL,
    action_owner_email text NOT NULL,
    target_savings_rupees bigint NOT NULL DEFAULT 0,
    realised_savings_rupees bigint NOT NULL DEFAULT 0,
    status text NOT NULL CHECK (status IN ('queued','in_progress','blocked','completed','cancelled')),
    due_at date NOT NULL,
    closed_at date,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_spare_parts_corrective_actions_r2672 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_spare_parts_corrective_actions_r2672;
CREATE POLICY founder_all ON customer_spare_parts_corrective_actions_r2672
    FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_spare_parts_corrective_actions_r2672
    (customer_org_name, equipment_label, action_title, action_owner_email, target_savings_rupees, realised_savings_rupees, status, due_at, closed_at)
VALUES
    ('Apollo Jubilee','CT Scanner GE Optima 660','Q3 bearing swap + lubrication SOP','ravi.engineer@equipseva.com',28000,0,'in_progress','2026-07-15',NULL),
    ('Yashoda Somajiguda','Anesthesia Workstation Drager Fabius','HVAC humidity logger install','arjun.engineer@equipseva.com',12000,4000,'in_progress','2026-07-05',NULL),
    ('Care Banjara','Autoclave Tuttnauer 5075EHS','Door gasket + switch calibration','karthik.engineer@equipseva.com',22000,22000,'completed','2026-06-20','2026-06-19'),
    ('Continental Gachibowli','Patient Monitor Philips IntelliVue','Operator retraining SpO2 probes','priya.engineer@equipseva.com',5000,0,'queued','2026-07-02',NULL),
    ('Rainbow Banjara','Phototherapy Unit Atom','NICU room rotation policy','arjun.engineer@equipseva.com',3500,0,'blocked','2026-07-10',NULL),
    ('KIMS Secunderabad','Dental Chair Sirona C2','Quarterly suction valve cleaning SOP','sneha.engineer@equipseva.com',1500,1500,'completed','2026-06-15','2026-06-12');

-- ------------------------------------------------------------
-- RPC 1: list_burn_snapshots
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS list_burn_snapshots_r2672();
CREATE OR REPLACE FUNCTION list_burn_snapshots_r2672()
RETURNS TABLE (
    id uuid,
    snapshot_month date,
    customer_org_name text,
    equipment_label text,
    equipment_category text,
    parts_consumed_count integer,
    parts_burn_rupees bigint,
    monthly_budget_rupees bigint,
    variance_rupees bigint,
    variance_pct numeric,
    burn_status text,
    top_part_name text,
    root_cause_code text,
    corrective_action text,
    owner_engineer_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.id, s.snapshot_month, s.customer_org_name, s.equipment_label, s.equipment_category,
           s.parts_consumed_count, s.parts_burn_rupees, s.monthly_budget_rupees, s.variance_rupees,
           s.variance_pct, s.burn_status, s.top_part_name, s.root_cause_code, s.corrective_action,
           s.owner_engineer_email
    FROM customer_spare_parts_burn_snapshots_r2672 s
    ORDER BY s.variance_pct DESC NULLS LAST, s.snapshot_month DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_burn_snapshots_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_burn_snapshots_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 2: top_burn_focus
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS top_burn_focus_r2672();
CREATE OR REPLACE FUNCTION top_burn_focus_r2672()
RETURNS TABLE (
    customer_org_name text,
    equipment_label text,
    parts_burn_rupees bigint,
    variance_rupees bigint,
    variance_pct numeric,
    burn_status text,
    root_cause_code text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.customer_org_name, s.equipment_label, s.parts_burn_rupees, s.variance_rupees,
           s.variance_pct, s.burn_status, s.root_cause_code
    FROM customer_spare_parts_burn_snapshots_r2672 s
    WHERE s.burn_status IN ('over','critical','watch')
    ORDER BY s.variance_rupees DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION top_burn_focus_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION top_burn_focus_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 3: burn_status_funnel
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS burn_status_funnel_r2672();
CREATE OR REPLACE FUNCTION burn_status_funnel_r2672()
RETURNS TABLE (
    burn_status text,
    equipment_count bigint,
    total_burn_rupees bigint,
    total_variance_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.burn_status,
           count(*)::bigint,
           coalesce(sum(s.parts_burn_rupees),0)::bigint,
           coalesce(sum(s.variance_rupees),0)::bigint
    FROM customer_spare_parts_burn_snapshots_r2672 s
    GROUP BY s.burn_status
    ORDER BY CASE s.burn_status
        WHEN 'critical' THEN 1 WHEN 'over' THEN 2 WHEN 'watch' THEN 3
        WHEN 'on_track' THEN 4 WHEN 'under' THEN 5 ELSE 9 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION burn_status_funnel_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION burn_status_funnel_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 4: monthly_burn_trend
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS monthly_burn_trend_r2672();
CREATE OR REPLACE FUNCTION monthly_burn_trend_r2672()
RETURNS TABLE (
    snapshot_month date,
    equipment_count bigint,
    total_burn_rupees bigint,
    total_budget_rupees bigint,
    total_variance_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.snapshot_month,
           count(*)::bigint,
           coalesce(sum(s.parts_burn_rupees),0)::bigint,
           coalesce(sum(s.monthly_budget_rupees),0)::bigint,
           coalesce(sum(s.variance_rupees),0)::bigint
    FROM customer_spare_parts_burn_snapshots_r2672 s
    GROUP BY s.snapshot_month
    ORDER BY s.snapshot_month DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION monthly_burn_trend_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION monthly_burn_trend_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 5: quarterly_burn_trend
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS quarterly_burn_trend_r2672();
CREATE OR REPLACE FUNCTION quarterly_burn_trend_r2672()
RETURNS TABLE (
    quarter_start date,
    equipment_count bigint,
    total_burn_rupees bigint,
    total_variance_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT date_trunc('quarter', s.snapshot_month)::date,
           count(*)::bigint,
           coalesce(sum(s.parts_burn_rupees),0)::bigint,
           coalesce(sum(s.variance_rupees),0)::bigint
    FROM customer_spare_parts_burn_snapshots_r2672 s
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION quarterly_burn_trend_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION quarterly_burn_trend_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 6: burn_summary
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS burn_summary_r2672();
CREATE OR REPLACE FUNCTION burn_summary_r2672()
RETURNS TABLE (
    total_equipment bigint,
    total_burn_rupees bigint,
    total_budget_rupees bigint,
    total_variance_rupees bigint,
    over_or_critical bigint,
    open_actions bigint,
    completed_actions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        (SELECT count(*) FROM customer_spare_parts_burn_snapshots_r2672)::bigint,
        (SELECT coalesce(sum(parts_burn_rupees),0) FROM customer_spare_parts_burn_snapshots_r2672)::bigint,
        (SELECT coalesce(sum(monthly_budget_rupees),0) FROM customer_spare_parts_burn_snapshots_r2672)::bigint,
        (SELECT coalesce(sum(variance_rupees),0) FROM customer_spare_parts_burn_snapshots_r2672)::bigint,
        (SELECT count(*) FROM customer_spare_parts_burn_snapshots_r2672 WHERE burn_status IN ('over','critical'))::bigint,
        (SELECT count(*) FROM customer_spare_parts_corrective_actions_r2672 WHERE status IN ('queued','in_progress','blocked'))::bigint,
        (SELECT count(*) FROM customer_spare_parts_corrective_actions_r2672 WHERE status = 'completed')::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION burn_summary_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION burn_summary_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 7: owner_load
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS owner_load_r2672();
CREATE OR REPLACE FUNCTION owner_load_r2672()
RETURNS TABLE (
    owner_engineer_email text,
    equipment_count bigint,
    total_variance_rupees bigint,
    open_actions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.owner_engineer_email,
           count(*)::bigint,
           coalesce(sum(s.variance_rupees),0)::bigint,
           (SELECT count(*)::bigint FROM customer_spare_parts_corrective_actions_r2672 a
            WHERE a.action_owner_email = s.owner_engineer_email
            AND a.status IN ('queued','in_progress','blocked'))
    FROM customer_spare_parts_burn_snapshots_r2672 s
    WHERE s.owner_engineer_email IS NOT NULL
    GROUP BY s.owner_engineer_email
    ORDER BY total_variance_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION owner_load_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION owner_load_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 8: root_cause_breakdown
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS root_cause_breakdown_r2672();
CREATE OR REPLACE FUNCTION root_cause_breakdown_r2672()
RETURNS TABLE (
    root_cause_code text,
    equipment_count bigint,
    total_variance_rupees bigint,
    avg_variance_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.root_cause_code,
           count(*)::bigint,
           coalesce(sum(s.variance_rupees),0)::bigint,
           coalesce(round(avg(s.variance_pct),2),0)::numeric
    FROM customer_spare_parts_burn_snapshots_r2672 s
    GROUP BY s.root_cause_code
    ORDER BY total_variance_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION root_cause_breakdown_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION root_cause_breakdown_r2672() TO authenticated;

-- ------------------------------------------------------------
-- RPC 9: list_corrective_actions
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS list_corrective_actions_r2672();
CREATE OR REPLACE FUNCTION list_corrective_actions_r2672()
RETURNS TABLE (
    id uuid,
    customer_org_name text,
    equipment_label text,
    action_title text,
    action_owner_email text,
    target_savings_rupees bigint,
    realised_savings_rupees bigint,
    status text,
    due_at date,
    closed_at date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT a.id, a.customer_org_name, a.equipment_label, a.action_title, a.action_owner_email,
           a.target_savings_rupees, a.realised_savings_rupees, a.status, a.due_at, a.closed_at
    FROM customer_spare_parts_corrective_actions_r2672 a
    ORDER BY CASE a.status
        WHEN 'blocked' THEN 1 WHEN 'in_progress' THEN 2 WHEN 'queued' THEN 3
        WHEN 'completed' THEN 4 WHEN 'cancelled' THEN 5 ELSE 9 END,
        a.due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_corrective_actions_r2672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_corrective_actions_r2672() TO authenticated;

COMMIT;
