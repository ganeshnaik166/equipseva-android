BEGIN;

-- ============================================================================
-- r1500 MILESTONE — Founder Executive 360 Dashboard v3
-- Aggregator over every founder console feature: 24 KPIs + 6 drill cards
-- ============================================================================

-- Morning snapshot cache (refreshed daily by pg_cron + manual refresh RPC)
CREATE TABLE IF NOT EXISTS founder_exec_360_snapshots_v3 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  domain text NOT NULL CHECK (domain IN ('engineering','revenue','capital','ops','compliance','growth')),
  kpi_key text NOT NULL,
  kpi_label text NOT NULL,
  kpi_value numeric,
  kpi_text text,
  kpi_unit text,
  delta_vs_yesterday numeric,
  delta_vs_week numeric,
  status_color text CHECK (status_color IN ('green','amber','red','neutral')) DEFAULT 'neutral',
  drill_route text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (snapshot_date, domain, kpi_key)
);

CREATE INDEX IF NOT EXISTS idx_exec_360_v3_date ON founder_exec_360_snapshots_v3 (snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_exec_360_v3_domain ON founder_exec_360_snapshots_v3 (domain, snapshot_date DESC);

ALTER TABLE founder_exec_360_snapshots_v3 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_exec_360_v3_founder_only ON founder_exec_360_snapshots_v3;
CREATE POLICY founder_exec_360_v3_founder_only ON founder_exec_360_snapshots_v3
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Pinned KPI shortcuts (founder picks which KPIs land on the home strip)
CREATE TABLE IF NOT EXISTS founder_exec_360_pins_v3 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain text NOT NULL,
  kpi_key text NOT NULL,
  display_order int NOT NULL DEFAULT 0,
  note text,
  pinned_at timestamptz NOT NULL DEFAULT now(),
  pinned_by_user_id uuid,
  UNIQUE (domain, kpi_key)
);

ALTER TABLE founder_exec_360_pins_v3 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_exec_360_pins_v3_founder_only ON founder_exec_360_pins_v3;
CREATE POLICY founder_exec_360_pins_v3_founder_only ON founder_exec_360_pins_v3
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (7 STABLE SECDEF)
-- ============================================================================

DROP FUNCTION IF EXISTS exec_360_v3_engineering_kpis();
CREATE OR REPLACE FUNCTION exec_360_v3_engineering_kpis()
RETURNS TABLE (
  kpi_key text,
  kpi_label text,
  kpi_value numeric,
  kpi_text text,
  status_color text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'engineers_active'::text, 'Active engineers'::text,
    (SELECT COUNT(*)::numeric FROM engineers WHERE cached_highest_tier <> 'none'),
    NULL::text, 'green'::text
  UNION ALL SELECT 'engineers_pro', 'Pro tier engineers',
    (SELECT COUNT(*)::numeric FROM engineers WHERE cached_highest_tier = 'pro'),
    NULL, 'green'
  UNION ALL SELECT 'engineers_bgc', 'BGC-verified engineers',
    (SELECT COUNT(*)::numeric FROM engineers WHERE cached_highest_tier IN ('pro','bgc')),
    NULL, 'green'
  UNION ALL SELECT 'jobs_open', 'Open repair jobs',
    (SELECT COUNT(*)::numeric FROM repair_jobs WHERE status IN ('open','bidding','accepted','in_progress')),
    NULL, 'amber';
END;
$$;

DROP FUNCTION IF EXISTS exec_360_v3_revenue_kpis();
CREATE OR REPLACE FUNCTION exec_360_v3_revenue_kpis()
RETURNS TABLE (
  kpi_key text,
  kpi_label text,
  kpi_value numeric,
  kpi_text text,
  status_color text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'gmv_today'::text, 'GMV today (₹)'::text,
    COALESCE((SELECT SUM(contracted_amount_rupees)::numeric FROM repair_jobs
              WHERE created_at::date = (now() AT TIME ZONE 'Asia/Kolkata')::date), 0),
    NULL::text, 'green'::text
  UNION ALL SELECT 'gmv_week', 'GMV last 7 days (₹)',
    COALESCE((SELECT SUM(contracted_amount_rupees)::numeric FROM repair_jobs
              WHERE created_at >= now() - INTERVAL '7 days'), 0),
    NULL, 'green'
  UNION ALL SELECT 'jobs_completed_week', 'Jobs completed (7d)',
    (SELECT COUNT(*)::numeric FROM repair_jobs
     WHERE status = 'completed' AND completed_at >= now() - INTERVAL '7 days'),
    NULL, 'green'
  UNION ALL SELECT 'avg_ticket', 'Avg ticket (₹)',
    COALESCE((SELECT AVG(contracted_amount_rupees)::numeric FROM repair_jobs
              WHERE status = 'completed' AND completed_at >= now() - INTERVAL '30 days'), 0),
    NULL, 'neutral';
END;
$$;

DROP FUNCTION IF EXISTS exec_360_v3_capital_kpis();
CREATE OR REPLACE FUNCTION exec_360_v3_capital_kpis()
RETURNS TABLE (
  kpi_key text,
  kpi_label text,
  kpi_value numeric,
  kpi_text text,
  status_color text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'amc_pool_balance'::text, 'AMC pool balance (₹)'::text,
    COALESCE((SELECT SUM(amount_rupees)::numeric FROM amc_payment_pool), 0),
    NULL::text, 'green'::text
  UNION ALL SELECT 'amc_active_contracts', 'Active AMC contracts',
    (SELECT COUNT(*)::numeric FROM amc_contracts WHERE status = 'active'),
    NULL, 'green'
  UNION ALL SELECT 'payouts_pending', 'Pending payouts (₹)',
    COALESCE((SELECT SUM(amount_rupees)::numeric FROM engineer_payouts
              WHERE paid_at IS NULL), 0),
    NULL, 'amber'
  UNION ALL SELECT 'payouts_paid_week', 'Payouts paid (7d, ₹)',
    COALESCE((SELECT SUM(amount_rupees)::numeric FROM engineer_payouts
              WHERE paid_at >= now() - INTERVAL '7 days'), 0),
    NULL, 'green';
END;
$$;

DROP FUNCTION IF EXISTS exec_360_v3_ops_kpis();
CREATE OR REPLACE FUNCTION exec_360_v3_ops_kpis()
RETURNS TABLE (
  kpi_key text,
  kpi_label text,
  kpi_value numeric,
  kpi_text text,
  status_color text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'code_red_open'::text, 'Open Code Red requests'::text,
    (SELECT COUNT(*)::numeric FROM code_red_requests WHERE status NOT IN ('resolved','cancelled')),
    NULL::text, 'red'::text
  UNION ALL SELECT 'incidents_p0', 'Open P0/P1 incidents',
    (SELECT COUNT(*)::numeric FROM founder_incidents
     WHERE severity IN ('p0','p1') AND resolved_at IS NULL),
    NULL, 'red'
  UNION ALL SELECT 'priority_actions_open', 'Open priority actions',
    (SELECT COUNT(*)::numeric FROM founder_priority_actions WHERE action_taken IS NULL),
    NULL, 'amber'
  UNION ALL SELECT 'jobs_in_dispute', 'Jobs in dispute',
    (SELECT COUNT(*)::numeric FROM repair_job_escrow WHERE status = 'in_dispute'),
    NULL, 'red';
END;
$$;

DROP FUNCTION IF EXISTS exec_360_v3_compliance_kpis();
CREATE OR REPLACE FUNCTION exec_360_v3_compliance_kpis()
RETURNS TABLE (
  kpi_key text,
  kpi_label text,
  kpi_value numeric,
  kpi_text text,
  status_color text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'gst_invoices_month'::text, 'GST invoices (this month)'::text,
    (SELECT COUNT(*)::numeric FROM gst_invoices
     WHERE issued_at >= date_trunc('month', now())),
    NULL::text, 'green'::text
  UNION ALL SELECT 'gst_taxable_month', 'GST taxable (this month, ₹)',
    COALESCE((SELECT SUM(taxable_amount_rupees)::numeric FROM gst_invoices
              WHERE issued_at >= date_trunc('month', now())), 0),
    NULL, 'green'
  UNION ALL SELECT 'dpdp_grievances_open', 'Open DPDP grievances',
    (SELECT COUNT(*)::numeric FROM founder_priority_actions
     WHERE category = 'dpdp_grievance' AND action_taken IS NULL),
    NULL, 'amber'
  UNION ALL SELECT 'spot_audits_30d', 'Spot audits (30d)',
    (SELECT COUNT(*)::numeric FROM spot_audit_invitations
     WHERE created_at >= now() - INTERVAL '30 days'),
    NULL, 'green';
END;
$$;

DROP FUNCTION IF EXISTS exec_360_v3_growth_kpis();
CREATE OR REPLACE FUNCTION exec_360_v3_growth_kpis()
RETURNS TABLE (
  kpi_key text,
  kpi_label text,
  kpi_value numeric,
  kpi_text text,
  status_color text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'hospitals_total'::text, 'Hospitals onboarded'::text,
    (SELECT COUNT(*)::numeric FROM organizations WHERE org_type = 'hospital'),
    NULL::text, 'green'::text
  UNION ALL SELECT 'hospitals_week', 'New hospitals (7d)',
    (SELECT COUNT(*)::numeric FROM organizations
     WHERE org_type = 'hospital' AND created_at >= now() - INTERVAL '7 days'),
    NULL, 'green'
  UNION ALL SELECT 'engineers_week', 'New engineers (7d)',
    (SELECT COUNT(*)::numeric FROM engineers
     WHERE created_at >= now() - INTERVAL '7 days'),
    NULL, 'green'
  UNION ALL SELECT 'avg_rating_30d', 'Avg hospital rating (30d)',
    COALESCE((SELECT AVG(hospital_rating)::numeric FROM repair_jobs
              WHERE hospital_rating IS NOT NULL
                AND completed_at >= now() - INTERVAL '30 days'), 0),
    NULL, 'green';
END;
$$;

DROP FUNCTION IF EXISTS exec_360_v3_drill_cards();
CREATE OR REPLACE FUNCTION exec_360_v3_drill_cards()
RETURNS TABLE (
  id text,
  domain text,
  title text,
  headline_value numeric,
  headline_label text,
  drill_route text,
  status_color text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'card_engineering'::text, 'engineering'::text, 'Engineering'::text,
    (SELECT COUNT(*)::numeric FROM engineers WHERE cached_highest_tier <> 'none'),
    'active engineers'::text, '/founder-engineer-360'::text, 'green'::text
  UNION ALL SELECT 'card_revenue', 'revenue', 'Revenue',
    COALESCE((SELECT SUM(contracted_amount_rupees)::numeric FROM repair_jobs
              WHERE created_at >= now() - INTERVAL '7 days'), 0),
    'GMV last 7 days (₹)', '/founder-revenue-pulse', 'green'
  UNION ALL SELECT 'card_capital', 'capital',  'Capital',
    COALESCE((SELECT SUM(amount_rupees)::numeric FROM amc_payment_pool), 0),
    'AMC pool balance (₹)', '/founder-capital-board', 'green'
  UNION ALL SELECT 'card_ops', 'ops', 'Ops',
    (SELECT COUNT(*)::numeric FROM founder_incidents
     WHERE severity IN ('p0','p1') AND resolved_at IS NULL),
    'Open P0/P1 incidents', '/founder-ops-war-room', 'red'
  UNION ALL SELECT 'card_compliance', 'compliance', 'Compliance',
    (SELECT COUNT(*)::numeric FROM gst_invoices
     WHERE issued_at >= date_trunc('month', now())),
    'GST invoices this month', '/founder-gst-filing', 'green'
  UNION ALL SELECT 'card_growth', 'growth', 'Growth',
    (SELECT COUNT(*)::numeric FROM organizations WHERE org_type = 'hospital'),
    'Hospitals onboarded', '/founder-growth-board', 'green';
END;
$$;

-- ============================================================================
-- WRITE/LOG RPCs (VOLATILE SECDEF) + 3 log_founder_* helpers
-- ============================================================================

DROP FUNCTION IF EXISTS log_founder_exec_360_v3_view();
CREATE OR REPLACE FUNCTION log_founder_exec_360_v3_view()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'exec_360_v3_view',
          jsonb_build_object('viewed_at', now()));
END;
$$;

DROP FUNCTION IF EXISTS log_founder_exec_360_v3_pin(text, text, int, text);
CREATE OR REPLACE FUNCTION log_founder_exec_360_v3_pin(
  p_domain text,
  p_kpi_key text,
  p_display_order int,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_exec_360_pins_v3 (domain, kpi_key, display_order, note, pinned_by_user_id)
  VALUES (p_domain, p_kpi_key, COALESCE(p_display_order, 0), p_note, auth.uid())
  ON CONFLICT (domain, kpi_key) DO UPDATE
    SET display_order = EXCLUDED.display_order,
        note = EXCLUDED.note,
        pinned_at = now(),
        pinned_by_user_id = auth.uid()
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'exec_360_v3_pin',
          jsonb_build_object('domain', p_domain, 'kpi_key', p_kpi_key, 'order', p_display_order));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS log_founder_exec_360_v3_snapshot_refresh();
CREATE OR REPLACE FUNCTION log_founder_exec_360_v3_snapshot_refresh()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count int := 0;
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();

  DELETE FROM founder_exec_360_snapshots_v3 WHERE snapshot_date = v_today;

  INSERT INTO founder_exec_360_snapshots_v3
    (snapshot_date, domain, kpi_key, kpi_label, kpi_value, status_color, computed_at)
  SELECT v_today, 'engineering', kpi_key, kpi_label, kpi_value, status_color, now()
  FROM exec_360_v3_engineering_kpis();
  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO founder_exec_360_snapshots_v3
    (snapshot_date, domain, kpi_key, kpi_label, kpi_value, status_color, computed_at)
  SELECT v_today, 'revenue', kpi_key, kpi_label, kpi_value, status_color, now()
  FROM exec_360_v3_revenue_kpis();

  INSERT INTO founder_exec_360_snapshots_v3
    (snapshot_date, domain, kpi_key, kpi_label, kpi_value, status_color, computed_at)
  SELECT v_today, 'capital', kpi_key, kpi_label, kpi_value, status_color, now()
  FROM exec_360_v3_capital_kpis();

  INSERT INTO founder_exec_360_snapshots_v3
    (snapshot_date, domain, kpi_key, kpi_label, kpi_value, status_color, computed_at)
  SELECT v_today, 'ops', kpi_key, kpi_label, kpi_value, status_color, now()
  FROM exec_360_v3_ops_kpis();

  INSERT INTO founder_exec_360_snapshots_v3
    (snapshot_date, domain, kpi_key, kpi_label, kpi_value, status_color, computed_at)
  SELECT v_today, 'compliance', kpi_key, kpi_label, kpi_value, status_color, now()
  FROM exec_360_v3_compliance_kpis();

  INSERT INTO founder_exec_360_snapshots_v3
    (snapshot_date, domain, kpi_key, kpi_label, kpi_value, status_color, computed_at)
  SELECT v_today, 'growth', kpi_key, kpi_label, kpi_value, status_color, now()
  FROM exec_360_v3_growth_kpis();

  SELECT COUNT(*) INTO v_count FROM founder_exec_360_snapshots_v3 WHERE snapshot_date = v_today;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'exec_360_v3_snapshot_refresh',
          jsonb_build_object('snapshot_date', v_today, 'kpi_count', v_count));
  RETURN v_count;
END;
$$;

DROP FUNCTION IF EXISTS log_founder_exec_360_v3_unpin(text, text);
CREATE OR REPLACE FUNCTION log_founder_exec_360_v3_unpin(p_domain text, p_kpi_key text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  DELETE FROM founder_exec_360_pins_v3 WHERE domain = p_domain AND kpi_key = p_kpi_key;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'exec_360_v3_unpin',
          jsonb_build_object('domain', p_domain, 'kpi_key', p_kpi_key));
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION exec_360_v3_engineering_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION exec_360_v3_revenue_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION exec_360_v3_capital_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION exec_360_v3_ops_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION exec_360_v3_compliance_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION exec_360_v3_growth_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION exec_360_v3_drill_cards() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_exec_360_v3_view() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_exec_360_v3_pin(text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_exec_360_v3_snapshot_refresh() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_exec_360_v3_unpin(text, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION exec_360_v3_engineering_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION exec_360_v3_revenue_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION exec_360_v3_capital_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION exec_360_v3_ops_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION exec_360_v3_compliance_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION exec_360_v3_growth_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION exec_360_v3_drill_cards() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_exec_360_v3_view() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_exec_360_v3_pin(text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_exec_360_v3_snapshot_refresh() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_exec_360_v3_unpin(text, text) TO authenticated;

COMMIT;