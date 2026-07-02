-- Round 2888 — Customer Monthly Repair-Job Re-Visit Pattern & Loyalty Bond
-- Founder ops: track which hospitals (customers) keep coming back month after month,
-- detect re-visit cadence, surface loyalty-bond candidates, flag churn-at-risk accounts.

BEGIN;

-- ============================================================
-- TABLE 1: customer_monthly_revisit_pattern_r2888
-- One row per (hospital, month) snapshot of repair-job behavior.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customer_monthly_revisit_pattern_r2888 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_org_id uuid,
  hospital_name text not null,
  city text not null,
  snapshot_month date not null,
  repair_jobs_count int not null default 0,
  unique_devices_serviced int not null default 0,
  repeat_device_visits int not null default 0,
  avg_days_between_visits numeric(6,2) not null default 0,
  total_billed_rupees bigint not null default 0,
  satisfaction_avg numeric(3,2) not null default 0,
  on_time_completion_pct numeric(5,2) not null default 0,
  escalation_count int not null default 0,
  loyalty_score numeric(5,2) not null default 0,
  revisit_pattern text not null default 'steady',
  churn_risk text not null default 'low',
  notes text
);

ALTER TABLE public.customer_monthly_revisit_pattern_r2888 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- TABLE 2: customer_loyalty_bond_offer_r2888
-- Loyalty-bond offers tied to hospital repeat behavior.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customer_loyalty_bond_offer_r2888 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_org_id uuid,
  hospital_name text not null,
  city text not null,
  bond_tier text not null,
  bond_term_months int not null,
  discount_pct numeric(5,2) not null,
  min_monthly_jobs int not null default 1,
  monthly_commit_rupees bigint not null default 0,
  total_bond_value_rupees bigint not null default 0,
  offered_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  offer_status text not null default 'pending',
  signed_at timestamptz,
  declined_reason text,
  projected_ltv_uplift_rupees bigint not null default 0
);

ALTER TABLE public.customer_loyalty_bond_offer_r2888 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.customer_monthly_revisit_pattern_r2888
  (hospital_name, city, snapshot_month, repair_jobs_count, unique_devices_serviced,
   repeat_device_visits, avg_days_between_visits, total_billed_rupees,
   satisfaction_avg, on_time_completion_pct, escalation_count,
   loyalty_score, revisit_pattern, churn_risk, notes)
VALUES
  ('Apollo Jubilee Hills','Hyderabad','2026-06-01',14,9,5,18.5,485000,4.7,96.4,0,92.1,'compounding','low','Bond candidate — 4th consecutive month uptick'),
  ('Apollo Jubilee Hills','Hyderabad','2026-05-01',12,8,4,21.0,402000,4.6,94.1,1,88.4,'steady','low','Steady tier-1 anchor'),
  ('Apollo Jubilee Hills','Hyderabad','2026-04-01',10,7,3,24.5,338000,4.5,92.0,1,84.0,'steady','low','Q2 ramp begins'),
  ('Yashoda Secunderabad','Hyderabad','2026-06-01',9,6,4,22.0,312000,4.4,91.0,2,79.5,'steady','low','Bond offered last week'),
  ('KIMS Kondapur','Hyderabad','2026-06-01',7,5,3,28.0,241000,4.2,87.5,2,72.0,'steady','medium','MRI re-visit twice — investigate'),
  ('Continental Gachibowli','Hyderabad','2026-06-01',5,4,1,42.0,168000,3.9,82.0,3,58.5,'fading','high','Drop from 11 to 5 jobs — churn watch'),
  ('Continental Gachibowli','Hyderabad','2026-05-01',8,6,2,30.0,265000,4.1,86.0,2,71.0,'steady','medium','Cooling off'),
  ('Continental Gachibowli','Hyderabad','2026-04-01',11,8,3,24.0,371000,4.3,89.0,1,78.5,'steady','low','Was healthy'),
  ('Care Banjara','Hyderabad','2026-06-01',6,5,2,32.0,198000,4.0,84.5,2,68.0,'steady','medium','Switching some jobs to in-house'),
  ('Sunshine Paradise','Hyderabad','2026-06-01',8,6,3,25.0,278000,4.3,90.0,1,80.5,'steady','low','Anchored on ventilator AMC'),
  ('AIG Gachibowli','Hyderabad','2026-06-01',11,7,5,20.0,398000,4.6,95.0,0,89.0,'compounding','low','Endoscopy fleet re-visit cluster'),
  ('AIG Gachibowli','Hyderabad','2026-05-01',9,6,4,22.5,332000,4.5,93.0,1,85.5,'steady','low','Pre-ramp'),
  ('Rainbow Banjara','Hyderabad','2026-06-01',6,5,2,30.0,212000,4.2,88.0,1,73.5,'steady','medium','Pediatric — seasonal'),
  ('Star Hospitals','Hyderabad','2026-06-01',10,7,4,21.5,365000,4.5,93.5,1,86.0,'steady','low','Cath-lab cluster'),
  ('Asian Institute','Hyderabad','2026-06-01',4,3,1,45.0,138000,3.7,78.0,3,52.0,'fading','high','3rd month of decline — bond rescue'),
  ('Olive Hospitals','Hyderabad','2026-06-01',5,4,2,33.0,176000,4.0,83.0,2,65.5,'steady','medium','Mid-tier — bond opportunity'),
  ('Citizens Specialty','Hyderabad','2026-06-01',7,5,3,26.0,242000,4.3,89.5,1,76.0,'steady','low','New onboard month 4'),
  ('Renova Soujanya','Hyderabad','2026-06-01',3,3,0,52.0,102000,3.6,75.0,4,42.0,'fading','high','Critical churn — escalate to founder'),
  ('Krishna Institute','Vijayawada','2026-06-01',8,6,3,24.0,289000,4.4,90.5,1,81.0,'steady','low','Andhra anchor'),
  ('Manipal Vijayawada','Vijayawada','2026-06-01',6,5,2,29.0,215000,4.2,87.0,2,72.5,'steady','medium','Manipal chain pilot');

INSERT INTO public.customer_loyalty_bond_offer_r2888
  (hospital_name, city, bond_tier, bond_term_months, discount_pct,
   min_monthly_jobs, monthly_commit_rupees, total_bond_value_rupees,
   offer_status, signed_at, declined_reason, projected_ltv_uplift_rupees)
VALUES
  ('Apollo Jubilee Hills','Hyderabad','platinum',12,12.5,10,400000,4800000,'signed',now() - interval '6 days',NULL,1850000),
  ('AIG Gachibowli','Hyderabad','platinum',12,12.5,9,360000,4320000,'signed',now() - interval '3 days',NULL,1610000),
  ('Yashoda Secunderabad','Hyderabad','gold',9,10.0,8,300000,2700000,'signed',now() - interval '11 days',NULL,980000),
  ('Star Hospitals','Hyderabad','gold',9,10.0,8,320000,2880000,'pending',NULL,NULL,1020000),
  ('Sunshine Paradise','Hyderabad','gold',9,10.0,7,260000,2340000,'pending',NULL,NULL,840000),
  ('Krishna Institute','Vijayawada','gold',9,10.0,7,265000,2385000,'signed',now() - interval '2 days',NULL,810000),
  ('KIMS Kondapur','Hyderabad','silver',6,7.5,5,220000,1320000,'pending',NULL,NULL,475000),
  ('Citizens Specialty','Hyderabad','silver',6,7.5,5,225000,1350000,'signed',now() - interval '1 days',NULL,490000),
  ('Care Banjara','Hyderabad','silver',6,7.5,5,200000,1200000,'declined',NULL,'Reviewing in-house team option',0),
  ('Continental Gachibowli','Hyderabad','rescue',3,15.0,4,150000,450000,'pending',NULL,NULL,360000),
  ('Asian Institute','Hyderabad','rescue',3,15.0,4,140000,420000,'pending',NULL,NULL,335000),
  ('Renova Soujanya','Hyderabad','rescue',3,18.0,3,100000,300000,'pending',NULL,NULL,275000),
  ('Olive Hospitals','Hyderabad','silver',6,7.5,4,170000,1020000,'pending',NULL,NULL,380000),
  ('Rainbow Banjara','Hyderabad','silver',6,7.5,5,195000,1170000,'expired',NULL,'No response in 14 days',0),
  ('Manipal Vijayawada','Vijayawada','silver',6,7.5,5,210000,1260000,'pending',NULL,NULL,455000);

-- ============================================================
-- HELPER: is_founder gate (assumed present in earlier rounds)
-- ============================================================

-- ============================================================
-- RPC 1: revisit pattern rows for a snapshot month
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_revisit_pattern_list(p_month date DEFAULT NULL)
RETURNS TABLE (
  id uuid, hospital_name text, city text, snapshot_month date,
  repair_jobs_count int, unique_devices_serviced int, repeat_device_visits int,
  avg_days_between_visits numeric, total_billed_rupees bigint,
  satisfaction_avg numeric, on_time_completion_pct numeric,
  escalation_count int, loyalty_score numeric,
  revisit_pattern text, churn_risk text, notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
    SELECT t.id, t.hospital_name, t.city, t.snapshot_month,
           t.repair_jobs_count, t.unique_devices_serviced, t.repeat_device_visits,
           t.avg_days_between_visits, t.total_billed_rupees,
           t.satisfaction_avg, t.on_time_completion_pct,
           t.escalation_count, t.loyalty_score,
           t.revisit_pattern, t.churn_risk, t.notes
    FROM public.customer_monthly_revisit_pattern_r2888 t
    WHERE p_month IS NULL OR t.snapshot_month = p_month
    ORDER BY t.snapshot_month DESC, t.loyalty_score DESC;
END;
$$;

-- ============================================================
-- RPC 2: KPI summary
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_kpi_summary()
RETURNS TABLE (
  hospitals_tracked int,
  total_jobs_this_month int,
  total_billed_this_month bigint,
  avg_loyalty_score numeric,
  high_risk_hospitals int,
  compounding_hospitals int,
  signed_bonds int,
  pending_bonds int,
  total_bond_value_rupees bigint,
  projected_ltv_uplift_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_month date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  SELECT MAX(snapshot_month) INTO v_month FROM public.customer_monthly_revisit_pattern_r2888;

  RETURN QUERY
    SELECT
      (SELECT COUNT(DISTINCT hospital_name)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COALESCE(SUM(repair_jobs_count),0)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COALESCE(SUM(total_billed_rupees),0)::bigint FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COALESCE(ROUND(AVG(loyalty_score),2),0) FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COUNT(*)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month AND churn_risk = 'high'),
      (SELECT COUNT(*)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month AND revisit_pattern = 'compounding'),
      (SELECT COUNT(*)::int FROM public.customer_loyalty_bond_offer_r2888 WHERE offer_status = 'signed'),
      (SELECT COUNT(*)::int FROM public.customer_loyalty_bond_offer_r2888 WHERE offer_status = 'pending'),
      (SELECT COALESCE(SUM(total_bond_value_rupees),0)::bigint FROM public.customer_loyalty_bond_offer_r2888 WHERE offer_status = 'signed'),
      (SELECT COALESCE(SUM(projected_ltv_uplift_rupees),0)::bigint FROM public.customer_loyalty_bond_offer_r2888 WHERE offer_status IN ('signed','pending'));
END;
$$;

-- ============================================================
-- RPC 3: churn watch (high-risk hospitals)
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_churn_watch()
RETURNS TABLE (
  id uuid, hospital_name text, city text, snapshot_month date,
  repair_jobs_count int, loyalty_score numeric,
  revisit_pattern text, churn_risk text, notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
    SELECT t.id, t.hospital_name, t.city, t.snapshot_month,
           t.repair_jobs_count, t.loyalty_score,
           t.revisit_pattern, t.churn_risk, t.notes
    FROM public.customer_monthly_revisit_pattern_r2888 t
    WHERE t.churn_risk IN ('high','medium')
      AND t.snapshot_month = (SELECT MAX(snapshot_month) FROM public.customer_monthly_revisit_pattern_r2888)
    ORDER BY
      CASE t.churn_risk WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END,
      t.loyalty_score ASC;
END;
$$;

-- ============================================================
-- RPC 4: bond offers list
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_bond_offers_list()
RETURNS TABLE (
  id uuid, hospital_name text, city text, bond_tier text,
  bond_term_months int, discount_pct numeric, min_monthly_jobs int,
  monthly_commit_rupees bigint, total_bond_value_rupees bigint,
  offer_status text, signed_at timestamptz, declined_reason text,
  projected_ltv_uplift_rupees bigint, expires_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
    SELECT b.id, b.hospital_name, b.city, b.bond_tier,
           b.bond_term_months, b.discount_pct, b.min_monthly_jobs,
           b.monthly_commit_rupees, b.total_bond_value_rupees,
           b.offer_status, b.signed_at, b.declined_reason,
           b.projected_ltv_uplift_rupees, b.expires_at
    FROM public.customer_loyalty_bond_offer_r2888 b
    ORDER BY
      CASE b.offer_status
        WHEN 'signed' THEN 0
        WHEN 'pending' THEN 1
        WHEN 'declined' THEN 2
        WHEN 'expired' THEN 3
        ELSE 4
      END,
      b.total_bond_value_rupees DESC;
END;
$$;

-- ============================================================
-- RPC 5: revisit cadence histogram (avg days between visits buckets)
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_revisit_cadence_buckets()
RETURNS TABLE (
  bucket text,
  hospital_count int,
  avg_loyalty numeric,
  total_billed_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
    WITH latest AS (
      SELECT *, CASE
        WHEN avg_days_between_visits < 21 THEN 'tight (lt 21d)'
        WHEN avg_days_between_visits < 30 THEN 'healthy (21-30d)'
        WHEN avg_days_between_visits < 40 THEN 'cooling (30-40d)'
        ELSE 'fading (40d+)' END AS b
      FROM public.customer_monthly_revisit_pattern_r2888
      WHERE snapshot_month = (SELECT MAX(snapshot_month) FROM public.customer_monthly_revisit_pattern_r2888)
    )
    SELECT b AS bucket,
           COUNT(*)::int AS hospital_count,
           ROUND(AVG(loyalty_score),2) AS avg_loyalty,
           SUM(total_billed_rupees)::bigint AS total_billed_rupees
    FROM latest
    GROUP BY b
    ORDER BY MIN(avg_days_between_visits);
END;
$$;

-- ============================================================
-- RPC 6: monthly trend per hospital (3-month series for top accounts)
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_top_account_trend()
RETURNS TABLE (
  hospital_name text,
  snapshot_month date,
  repair_jobs_count int,
  total_billed_rupees bigint,
  loyalty_score numeric,
  revisit_pattern text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
    SELECT t.hospital_name, t.snapshot_month, t.repair_jobs_count,
           t.total_billed_rupees, t.loyalty_score, t.revisit_pattern
    FROM public.customer_monthly_revisit_pattern_r2888 t
    WHERE t.hospital_name IN (
      SELECT hospital_name
      FROM public.customer_monthly_revisit_pattern_r2888
      WHERE snapshot_month = (SELECT MAX(snapshot_month) FROM public.customer_monthly_revisit_pattern_r2888)
      ORDER BY total_billed_rupees DESC
      LIMIT 6
    )
    ORDER BY t.hospital_name, t.snapshot_month DESC;
END;
$$;

-- ============================================================
-- RPC 7: bond tier rollup
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_bond_tier_rollup()
RETURNS TABLE (
  bond_tier text,
  offers_count int,
  signed_count int,
  pending_count int,
  total_value_rupees bigint,
  projected_uplift_rupees bigint,
  avg_discount_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
    SELECT b.bond_tier,
           COUNT(*)::int AS offers_count,
           COUNT(*) FILTER (WHERE b.offer_status='signed')::int AS signed_count,
           COUNT(*) FILTER (WHERE b.offer_status='pending')::int AS pending_count,
           SUM(b.total_bond_value_rupees)::bigint AS total_value_rupees,
           SUM(b.projected_ltv_uplift_rupees)::bigint AS projected_uplift_rupees,
           ROUND(AVG(b.discount_pct),2) AS avg_discount_pct
    FROM public.customer_loyalty_bond_offer_r2888 b
    GROUP BY b.bond_tier
    ORDER BY total_value_rupees DESC;
END;
$$;

-- ============================================================
-- RPC 8: founder action list (synthesized from both tables)
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_r2888_founder_action_list()
RETURNS TABLE (
  priority int,
  hospital_name text,
  action text,
  rationale text,
  est_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
    SELECT 1 AS priority,
           p.hospital_name,
           'Founder personal call — churn rescue' AS action,
           ('Pattern '||p.revisit_pattern||' · loyalty '||p.loyalty_score||' · '||COALESCE(p.notes,''))::text AS rationale,
           p.total_billed_rupees * 6 AS est_value_rupees
    FROM public.customer_monthly_revisit_pattern_r2888 p
    WHERE p.churn_risk = 'high'
      AND p.snapshot_month = (SELECT MAX(snapshot_month) FROM public.customer_monthly_revisit_pattern_r2888)
    UNION ALL
    SELECT 2,
           b.hospital_name,
           'Close pending bond ('||b.bond_tier||')',
           ('Expires '||to_char(b.expires_at,'YYYY-MM-DD')||' · uplift Rs '||b.projected_ltv_uplift_rupees)::text,
           b.projected_ltv_uplift_rupees
    FROM public.customer_loyalty_bond_offer_r2888 b
    WHERE b.offer_status = 'pending'
    UNION ALL
    SELECT 3,
           p.hospital_name,
           'Send compounding-tier thank-you + upsell platinum',
           ('Compounding pattern · loyalty '||p.loyalty_score)::text,
           p.total_billed_rupees * 3
    FROM public.customer_monthly_revisit_pattern_r2888 p
    WHERE p.revisit_pattern = 'compounding'
      AND p.snapshot_month = (SELECT MAX(snapshot_month) FROM public.customer_monthly_revisit_pattern_r2888)
    ORDER BY 1, 5 DESC;
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_revisit_pattern_list(date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_kpi_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_churn_watch() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_bond_offers_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_revisit_cadence_buckets() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_top_account_trend() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_bond_tier_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_r2888_founder_action_list() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.rpc_r2888_revisit_pattern_list(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2888_kpi_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2888_churn_watch() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2888_bond_offers_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2888_revisit_cadence_buckets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2888_top_account_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2888_bond_tier_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_r2888_founder_action_list() TO authenticated;

COMMIT;
