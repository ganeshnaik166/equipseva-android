-- Round r2898: Engineer Monthly Customer Document Handover Completeness Audit
-- HEAVY founder ops round — engineer accountability for post-service doc handover

BEGIN;

-- ============================================================
-- Table 1: monthly handover audits per engineer
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_monthly_handover_audits_r2898 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_month date not null,
  engineer_id uuid not null,
  engineer_tier text not null,
  jobs_completed int not null default 0,
  service_reports_handed int not null default 0,
  warranty_cards_handed int not null default 0,
  calibration_certs_handed int not null default 0,
  amc_renewals_handed int not null default 0,
  spare_part_invoices_handed int not null default 0,
  total_docs_expected int not null default 0,
  total_docs_handed int not null default 0,
  completeness_pct numeric(5,2) not null default 0,
  customer_signoff_count int not null default 0,
  email_dispatch_count int not null default 0,
  whatsapp_dispatch_count int not null default 0,
  missing_doc_count int not null default 0,
  rejected_doc_count int not null default 0,
  rework_count int not null default 0,
  audit_status text not null default 'pass',
  founder_flag boolean not null default false,
  penalty_rupees int not null default 0,
  bonus_rupees int not null default 0,
  notes text
);

ALTER TABLE engineer_monthly_handover_audits_r2898 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Table 2: per-document handover events flagged in audit
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_handover_doc_events_r2898 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_id uuid not null references engineer_monthly_handover_audits_r2898(id) on delete cascade,
  engineer_id uuid not null,
  job_id uuid,
  hospital_org_id uuid,
  doc_type text not null,
  doc_status text not null,
  expected_at timestamptz,
  handed_at timestamptz,
  delay_hours numeric(8,2) not null default 0,
  channel text,
  customer_acknowledged boolean not null default false,
  acknowledgement_at timestamptz,
  rejection_reason text,
  followup_attempts int not null default 0,
  resolved boolean not null default false,
  severity text not null default 'low',
  notes text
);

ALTER TABLE engineer_handover_doc_events_r2898 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Seed audits — 18 rows across 6 engineers x 3 months
-- ============================================================
INSERT INTO engineer_monthly_handover_audits_r2898
  (audit_month, engineer_id, engineer_tier, jobs_completed, service_reports_handed, warranty_cards_handed, calibration_certs_handed, amc_renewals_handed, spare_part_invoices_handed, total_docs_expected, total_docs_handed, completeness_pct, customer_signoff_count, email_dispatch_count, whatsapp_dispatch_count, missing_doc_count, rejected_doc_count, rework_count, audit_status, founder_flag, penalty_rupees, bonus_rupees, notes)
VALUES
  ('2026-04-01', gen_random_uuid(), 'platinum', 24, 24, 22, 20, 18, 21, 120, 105, 87.50, 23, 24, 22, 8, 2, 1, 'pass', false, 0, 2500, 'Strong month — minor warranty card gaps'),
  ('2026-04-01', gen_random_uuid(), 'gold', 18, 16, 14, 12, 10, 13, 90, 65, 72.22, 14, 15, 11, 18, 3, 4, 'warning', true, 1500, 0, 'Calibration certs delayed >7d'),
  ('2026-04-01', gen_random_uuid(), 'silver', 12, 8, 7, 5, 4, 6, 60, 30, 50.00, 7, 8, 5, 25, 5, 6, 'fail', true, 4000, 0, 'Repeat failure — escalate to ops'),
  ('2026-04-01', gen_random_uuid(), 'bronze', 8, 7, 6, 5, 4, 5, 40, 27, 67.50, 6, 7, 4, 11, 2, 2, 'warning', true, 1000, 0, 'New engineer ramp-up'),
  ('2026-04-01', gen_random_uuid(), 'platinum', 30, 30, 29, 28, 27, 28, 150, 142, 94.67, 29, 30, 28, 6, 1, 0, 'pass', false, 0, 5000, 'Top performer of the month'),
  ('2026-04-01', gen_random_uuid(), 'gold', 20, 19, 18, 16, 15, 17, 100, 85, 85.00, 19, 19, 17, 12, 2, 1, 'pass', false, 0, 1500, 'Steady delivery'),
  ('2026-05-01', gen_random_uuid(), 'platinum', 26, 26, 25, 24, 23, 25, 130, 123, 94.62, 26, 26, 24, 5, 1, 0, 'pass', false, 0, 4000, 'Consistent excellence'),
  ('2026-05-01', gen_random_uuid(), 'gold', 19, 17, 15, 14, 13, 15, 95, 74, 77.89, 16, 17, 13, 16, 3, 3, 'warning', true, 1200, 0, 'Slipped vs April'),
  ('2026-05-01', gen_random_uuid(), 'silver', 14, 11, 9, 8, 7, 9, 70, 44, 62.86, 10, 11, 8, 20, 4, 5, 'fail', true, 3000, 0, 'Second consecutive failure'),
  ('2026-05-01', gen_random_uuid(), 'bronze', 10, 9, 8, 7, 6, 8, 50, 38, 76.00, 9, 9, 7, 9, 2, 1, 'warning', false, 500, 0, 'Improving'),
  ('2026-05-01', gen_random_uuid(), 'platinum', 28, 28, 27, 26, 25, 27, 140, 133, 95.00, 28, 28, 26, 5, 1, 0, 'pass', false, 0, 4500, 'Bonus earned'),
  ('2026-05-01', gen_random_uuid(), 'gold', 22, 21, 20, 18, 17, 19, 110, 95, 86.36, 21, 21, 19, 11, 2, 1, 'pass', false, 0, 1800, 'Solid'),
  ('2026-06-01', gen_random_uuid(), 'platinum', 25, 25, 24, 23, 22, 24, 125, 118, 94.40, 25, 25, 23, 5, 1, 0, 'pass', false, 0, 4200, 'Maintained streak'),
  ('2026-06-01', gen_random_uuid(), 'gold', 21, 20, 18, 16, 15, 18, 105, 87, 82.86, 20, 20, 17, 13, 2, 2, 'pass', false, 0, 1600, 'Recovered from May dip'),
  ('2026-06-01', gen_random_uuid(), 'silver', 15, 13, 11, 10, 9, 12, 75, 55, 73.33, 12, 13, 10, 15, 3, 3, 'warning', true, 800, 0, 'On probation'),
  ('2026-06-01', gen_random_uuid(), 'bronze', 11, 10, 9, 8, 7, 9, 55, 43, 78.18, 10, 10, 8, 8, 2, 1, 'warning', false, 400, 0, 'Trending up'),
  ('2026-06-01', gen_random_uuid(), 'platinum', 32, 32, 31, 30, 29, 31, 160, 153, 95.63, 31, 32, 30, 5, 1, 0, 'pass', false, 0, 5500, 'Highest absolute volume'),
  ('2026-06-01', gen_random_uuid(), 'gold', 23, 21, 19, 17, 16, 19, 115, 92, 80.00, 21, 22, 19, 14, 3, 2, 'warning', true, 1000, 0, 'Watchlist next month');

-- ============================================================
-- Seed doc events — 24 rows
-- ============================================================
INSERT INTO engineer_handover_doc_events_r2898
  (audit_id, engineer_id, doc_type, doc_status, expected_at, handed_at, delay_hours, channel, customer_acknowledged, rejection_reason, followup_attempts, resolved, severity, notes)
SELECT
  a.id, a.engineer_id,
  (ARRAY['service_report','warranty_card','calibration_cert','amc_renewal','spare_part_invoice'])[1 + (n % 5)],
  (ARRAY['handed','missing','rejected','rework','pending'])[1 + (n % 5)],
  now() - ((n*3 || ' hours')::interval),
  now() - ((n || ' hours')::interval),
  (n * 4)::numeric,
  (ARRAY['email','whatsapp','in_person','portal'])[1 + (n % 4)],
  (n % 3 = 0),
  CASE WHEN n % 5 = 2 THEN 'Customer signature missing' WHEN n % 5 = 3 THEN 'Wrong template version' ELSE null END,
  (n % 4),
  (n % 2 = 0),
  (ARRAY['low','medium','high','critical'])[1 + (n % 4)],
  'Auto-seeded event #' || n
FROM engineer_monthly_handover_audits_r2898 a
CROSS JOIN LATERAL generate_series(1, 2) AS n
LIMIT 24;

-- ============================================================
-- RPC 1: month-over-month rollup
-- ============================================================
CREATE OR REPLACE FUNCTION fn_r2898_monthly_rollup()
RETURNS TABLE (
  audit_month date,
  engineers_audited int,
  avg_completeness numeric,
  total_jobs int,
  total_docs_handed int,
  total_missing int,
  fail_count int,
  warning_count int,
  pass_count int,
  total_penalty int,
  total_bonus int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.audit_month,
    count(*)::int,
    round(avg(a.completeness_pct), 2),
    sum(a.jobs_completed)::int,
    sum(a.total_docs_handed)::int,
    sum(a.missing_doc_count)::int,
    sum((a.audit_status='fail')::int)::int,
    sum((a.audit_status='warning')::int)::int,
    sum((a.audit_status='pass')::int)::int,
    sum(a.penalty_rupees)::int,
    sum(a.bonus_rupees)::int
  FROM engineer_monthly_handover_audits_r2898 a
  GROUP BY a.audit_month
  ORDER BY a.audit_month DESC;
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2898_monthly_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2898_monthly_rollup() TO authenticated;

-- ============================================================
-- RPC 2: tier breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION fn_r2898_tier_breakdown()
RETURNS TABLE (
  engineer_tier text,
  audits int,
  avg_completeness numeric,
  avg_missing numeric,
  total_penalty int,
  total_bonus int,
  fail_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.engineer_tier,
    count(*)::int,
    round(avg(a.completeness_pct), 2),
    round(avg(a.missing_doc_count), 2),
    sum(a.penalty_rupees)::int,
    sum(a.bonus_rupees)::int,
    round(100.0 * sum((a.audit_status='fail')::int) / nullif(count(*),0), 2)
  FROM engineer_monthly_handover_audits_r2898 a
  GROUP BY a.engineer_tier
  ORDER BY avg_completeness DESC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2898_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2898_tier_breakdown() TO authenticated;

-- ============================================================
-- RPC 3: failing engineers (flagged for founder)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_r2898_failing_engineers()
RETURNS TABLE (
  audit_id uuid,
  audit_month date,
  engineer_id uuid,
  engineer_tier text,
  completeness_pct numeric,
  missing_doc_count int,
  rejected_doc_count int,
  penalty_rupees int,
  audit_status text,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.audit_month, a.engineer_id, a.engineer_tier,
         a.completeness_pct, a.missing_doc_count, a.rejected_doc_count,
         a.penalty_rupees, a.audit_status, a.notes
  FROM engineer_monthly_handover_audits_r2898 a
  WHERE a.founder_flag = true OR a.audit_status IN ('fail','warning')
  ORDER BY a.audit_month DESC, a.completeness_pct ASC;
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2898_failing_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2898_failing_engineers() TO authenticated;

-- ============================================================
-- RPC 4: top performers (bonus earners)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_r2898_top_performers()
RETURNS TABLE (
  audit_id uuid,
  audit_month date,
  engineer_id uuid,
  engineer_tier text,
  completeness_pct numeric,
  jobs_completed int,
  bonus_rupees int,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.audit_month, a.engineer_id, a.engineer_tier,
         a.completeness_pct, a.jobs_completed, a.bonus_rupees, a.notes
  FROM engineer_monthly_handover_audits_r2898 a
  WHERE a.bonus_rupees > 0
  ORDER BY a.bonus_rupees DESC, a.completeness_pct DESC
  LIMIT 20;
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2898_top_performers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2898_top_performers() TO authenticated;

-- ============================================================
-- RPC 5: doc-type missing heatmap
-- ============================================================
CREATE OR REPLACE FUNCTION fn_r2898_doc_type_heatmap()
RETURNS TABLE (
  doc_type text,
  total_events int,
  missing_count int,
  rejected_count int,
  rework_count int,
  avg_delay_hours numeric,
  critical_count int,
  resolved_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.doc_type,
    count(*)::int,
    sum((e.doc_status='missing')::int)::int,
    sum((e.doc_status='rejected')::int)::int,
    sum((e.doc_status='rework')::int)::int,
    round(avg(e.delay_hours), 2),
    sum((e.severity='critical')::int)::int,
    sum((e.resolved)::int)::int
  FROM engineer_handover_doc_events_r2898 e
  GROUP BY e.doc_type
  ORDER BY missing_count DESC;
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2898_doc_type_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2898_doc_type_heatmap() TO authenticated;

-- ============================================================
-- RPC 6: channel dispatch mix
-- ============================================================
CREATE OR REPLACE FUNCTION fn_r2898_channel_mix()
RETURNS TABLE (
  channel text,
  events int,
  ack_rate_pct numeric,
  avg_delay_hours numeric,
  resolved_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    coalesce(e.channel,'unknown'),
    count(*)::int,
    round(100.0 * sum((e.customer_acknowledged)::int) / nullif(count(*),0), 2),
    round(avg(e.delay_hours), 2),
    round(100.0 * sum((e.resolved)::int) / nullif(count(*),0), 2)
  FROM engineer_handover_doc_events_r2898 e
  GROUP BY coalesce(e.channel,'unknown')
  ORDER BY events DESC;
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2898_channel_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2898_channel_mix() TO authenticated;

-- ============================================================
-- RPC 7: founder kpi summary
-- ============================================================
CREATE OR REPLACE FUNCTION fn_r2898_founder_kpis()
RETURNS TABLE (
  total_audits int,
  avg_completeness numeric,
  engineers_flagged int,
  total_penalty_rupees int,
  total_bonus_rupees int,
  total_missing_docs int,
  critical_events int,
  unresolved_events int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM engineer_monthly_handover_audits_r2898),
    (SELECT round(avg(completeness_pct),2) FROM engineer_monthly_handover_audits_r2898),
    (SELECT count(*)::int FROM engineer_monthly_handover_audits_r2898 WHERE founder_flag),
    (SELECT sum(penalty_rupees)::int FROM engineer_monthly_handover_audits_r2898),
    (SELECT sum(bonus_rupees)::int FROM engineer_monthly_handover_audits_r2898),
    (SELECT sum(missing_doc_count)::int FROM engineer_monthly_handover_audits_r2898),
    (SELECT count(*)::int FROM engineer_handover_doc_events_r2898 WHERE severity='critical'),
    (SELECT count(*)::int FROM engineer_handover_doc_events_r2898 WHERE resolved=false);
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2898_founder_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2898_founder_kpis() TO authenticated;

COMMIT;
