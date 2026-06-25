BEGIN;

-- =========================================================
-- Round 2782 — Engineer Monthly Customer Callback Eliminations
-- Track engineer × callback root-cause × prevention plan ×
-- outcome × tier learning → drive callback reduction.
-- =========================================================

-- ---------- Table 1: callback elimination cases ----------
CREATE TABLE IF NOT EXISTS engineer_monthly_callback_cases_r2782 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key       text NOT NULL,                     -- 'YYYY-MM'
  engineer_code   text NOT NULL,
  engineer_name   text NOT NULL,
  current_tier    text NOT NULL CHECK (current_tier IN ('bronze','silver','gold','platinum')),
  callback_count  int  NOT NULL CHECK (callback_count >= 0),
  callback_rate_pct numeric(5,2) NOT NULL CHECK (callback_rate_pct >= 0),
  primary_root_cause text NOT NULL CHECK (primary_root_cause IN (
    'incomplete_diagnosis','wrong_part','poor_workmanship',
    'missed_calibration','customer_training_gap','environmental_factor'
  )),
  prevention_plan text NOT NULL,
  outcome_status  text NOT NULL CHECK (outcome_status IN (
    'eliminated','reduced','recurring','escalated','monitoring'
  )),
  tier_learning_tag text NOT NULL,
  reduce_target_pct numeric(5,2) NOT NULL CHECK (reduce_target_pct >= 0),
  reviewed_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_callback_cases_r2782 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_monthly_callback_cases_r2782;
CREATE POLICY founder_all ON engineer_monthly_callback_cases_r2782
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_callback_cases_r2782
  (month_key, engineer_code, engineer_name, current_tier, callback_count,
   callback_rate_pct, primary_root_cause, prevention_plan, outcome_status,
   tier_learning_tag, reduce_target_pct, reviewed_at)
VALUES
  ('2026-06','ENG-1041','Ravi Kumar','gold',2,4.20,'incomplete_diagnosis',
   'Add 15-min vitals re-check before close-out','reduced',
   'gold:diag-discipline',2.00,'2026-06-18 09:30:00+05:30'::timestamptz),
  ('2026-06','ENG-1052','Sneha Patel','silver',5,9.80,'wrong_part',
   'Mandatory part-number photo to supervisor','recurring',
   'silver:parts-verify',5.00,'2026-06-19 10:15:00+05:30'::timestamptz),
  ('2026-06','ENG-1067','Vikram Singh','platinum',1,1.10,'missed_calibration',
   'Calibration checklist v3 enforced','eliminated',
   'platinum:cal-mastery',1.00,'2026-06-20 11:00:00+05:30'::timestamptz),
  ('2026-06','ENG-1078','Anita Reddy','bronze',7,13.40,'customer_training_gap',
   'Bundle 10-min handover demo + signed sheet','monitoring',
   'bronze:handover-101',7.00,'2026-06-17 14:25:00+05:30'::timestamptz),
  ('2026-06','ENG-1083','Mohan Iyer','gold',3,5.60,'poor_workmanship',
   'Pair with platinum coach for 5 jobs','reduced',
   'gold:workmanship-coach',3.00,'2026-06-18 16:40:00+05:30'::timestamptz),
  ('2026-06','ENG-1094','Deepa Nair','silver',4,7.10,'environmental_factor',
   'Site-survey form pre-visit','escalated',
   'silver:site-survey',4.00,'2026-06-19 12:05:00+05:30'::timestamptz);

-- ---------- Table 2: tier learning rollups ----------
CREATE TABLE IF NOT EXISTS engineer_callback_tier_learning_r2782 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key       text NOT NULL,
  tier            text NOT NULL CHECK (tier IN ('bronze','silver','gold','platinum')),
  engineers_count int  NOT NULL CHECK (engineers_count >= 0),
  avg_callback_rate_pct numeric(5,2) NOT NULL CHECK (avg_callback_rate_pct >= 0),
  top_root_cause  text NOT NULL,
  shared_lesson   text NOT NULL,
  reduction_vs_prev_pct numeric(5,2) NOT NULL,
  playbook_url    text NOT NULL,
  recorded_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_callback_tier_learning_r2782 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_callback_tier_learning_r2782;
CREATE POLICY founder_all ON engineer_callback_tier_learning_r2782
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_callback_tier_learning_r2782
  (month_key, tier, engineers_count, avg_callback_rate_pct,
   top_root_cause, shared_lesson, reduction_vs_prev_pct, playbook_url, recorded_at)
VALUES
  ('2026-06','bronze',18,12.10,'customer_training_gap',
   'Always demo + sign handover before leaving',-1.20,
   '/playbooks/bronze-callback-r2782','2026-06-20 18:00:00+05:30'::timestamptz),
  ('2026-06','silver',24,7.80,'wrong_part',
   'Photo part number to supervisor pre-fit',2.40,
   '/playbooks/silver-callback-r2782','2026-06-20 18:00:00+05:30'::timestamptz),
  ('2026-06','gold',16,4.60,'incomplete_diagnosis',
   '15-min vitals re-check before close-out',3.10,
   '/playbooks/gold-callback-r2782','2026-06-20 18:00:00+05:30'::timestamptz),
  ('2026-06','platinum',8,1.40,'missed_calibration',
   'Calibration checklist v3 every job',0.30,
   '/playbooks/platinum-callback-r2782','2026-06-20 18:00:00+05:30'::timestamptz),
  ('2026-05','gold',15,7.70,'poor_workmanship',
   'Pair-with-coach rotation reduced rework',1.80,
   '/playbooks/gold-callback-r2782-may','2026-05-31 18:00:00+05:30'::timestamptz),
  ('2026-05','silver',22,10.20,'wrong_part',
   'Pilot of photo-verify dropped wrong-part by 3pts',3.40,
   '/playbooks/silver-callback-r2782-may','2026-05-31 18:00:00+05:30'::timestamptz);

-- ============================================================
-- RPCs (all SECURITY DEFINER, founder-gated)
-- ============================================================

-- 1) Overview KPIs
DROP FUNCTION IF EXISTS founder_r2782_callback_overview();
CREATE OR REPLACE FUNCTION founder_r2782_callback_overview()
RETURNS TABLE (
  total_cases int,
  eliminated int,
  recurring int,
  avg_rate numeric,
  total_callbacks int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE outcome_status = 'eliminated')::int,
    COUNT(*) FILTER (WHERE outcome_status = 'recurring')::int,
    COALESCE(ROUND(AVG(callback_rate_pct)::numeric, 2), 0)::numeric,
    COALESCE(SUM(callback_count), 0)::int
  FROM engineer_monthly_callback_cases_r2782;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_callback_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_callback_overview() TO authenticated;

-- 2) List cases
DROP FUNCTION IF EXISTS founder_r2782_list_cases();
CREATE OR REPLACE FUNCTION founder_r2782_list_cases()
RETURNS SETOF engineer_monthly_callback_cases_r2782
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM engineer_monthly_callback_cases_r2782
  ORDER BY callback_rate_pct DESC, reviewed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_list_cases() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_list_cases() TO authenticated;

-- 3) Root cause breakdown
DROP FUNCTION IF EXISTS founder_r2782_root_cause_breakdown();
CREATE OR REPLACE FUNCTION founder_r2782_root_cause_breakdown()
RETURNS TABLE (
  root_cause text,
  cases int,
  callbacks int,
  avg_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    primary_root_cause,
    COUNT(*)::int,
    COALESCE(SUM(callback_count), 0)::int,
    COALESCE(ROUND(AVG(callback_rate_pct)::numeric, 2), 0)::numeric
  FROM engineer_monthly_callback_cases_r2782
  GROUP BY primary_root_cause
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_root_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_root_cause_breakdown() TO authenticated;

-- 4) Outcome breakdown
DROP FUNCTION IF EXISTS founder_r2782_outcome_breakdown();
CREATE OR REPLACE FUNCTION founder_r2782_outcome_breakdown()
RETURNS TABLE (
  outcome text,
  cases int,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total int;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*) INTO total FROM engineer_monthly_callback_cases_r2782;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT
    outcome_status,
    COUNT(*)::int,
    ROUND((COUNT(*)::numeric * 100) / total, 2)::numeric
  FROM engineer_monthly_callback_cases_r2782
  GROUP BY outcome_status
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_outcome_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_outcome_breakdown() TO authenticated;

-- 5) Tier learning current month
DROP FUNCTION IF EXISTS founder_r2782_tier_learning_current();
CREATE OR REPLACE FUNCTION founder_r2782_tier_learning_current()
RETURNS SETOF engineer_callback_tier_learning_r2782
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM engineer_callback_tier_learning_r2782
  WHERE month_key = '2026-06'
  ORDER BY
    CASE tier
      WHEN 'platinum' THEN 1
      WHEN 'gold' THEN 2
      WHEN 'silver' THEN 3
      WHEN 'bronze' THEN 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_tier_learning_current() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_tier_learning_current() TO authenticated;

-- 6) Top recurring engineers
DROP FUNCTION IF EXISTS founder_r2782_top_recurring_engineers();
CREATE OR REPLACE FUNCTION founder_r2782_top_recurring_engineers()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  tier text,
  callback_count int,
  callback_rate_pct numeric,
  root_cause text,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.engineer_code,
    c.engineer_name,
    c.current_tier,
    c.callback_count,
    c.callback_rate_pct,
    c.primary_root_cause,
    c.outcome_status
  FROM engineer_monthly_callback_cases_r2782 c
  WHERE c.outcome_status IN ('recurring','escalated','monitoring')
  ORDER BY c.callback_rate_pct DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_top_recurring_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_top_recurring_engineers() TO authenticated;

-- 7) Tier reduction trend (vs prior month)
DROP FUNCTION IF EXISTS founder_r2782_tier_reduction_trend();
CREATE OR REPLACE FUNCTION founder_r2782_tier_reduction_trend()
RETURNS TABLE (
  tier text,
  month_key text,
  avg_rate numeric,
  reduction_vs_prev_pct numeric,
  shared_lesson text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    t.tier,
    t.month_key,
    t.avg_callback_rate_pct,
    t.reduction_vs_prev_pct,
    t.shared_lesson
  FROM engineer_callback_tier_learning_r2782 t
  ORDER BY t.month_key DESC,
    CASE t.tier
      WHEN 'platinum' THEN 1
      WHEN 'gold' THEN 2
      WHEN 'silver' THEN 3
      WHEN 'bronze' THEN 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_tier_reduction_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_tier_reduction_trend() TO authenticated;

-- 8) Prevention plan inventory
DROP FUNCTION IF EXISTS founder_r2782_prevention_inventory();
CREATE OR REPLACE FUNCTION founder_r2782_prevention_inventory()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  tier text,
  prevention_plan text,
  tier_learning_tag text,
  reduce_target_pct numeric,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.engineer_code,
    c.engineer_name,
    c.current_tier,
    c.prevention_plan,
    c.tier_learning_tag,
    c.reduce_target_pct,
    c.outcome_status
  FROM engineer_monthly_callback_cases_r2782 c
  ORDER BY c.reduce_target_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2782_prevention_inventory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2782_prevention_inventory() TO authenticated;

COMMIT;
