BEGIN;

-- ============================================================================
-- Round 2814: Engineer Monthly Customer Callback Recovery Script
-- Tracks engineer-led callback campaigns to recover churned/at-risk customers
-- using scripted talk tracks with verdicts and win-back outcomes
-- ============================================================================

-- Drop existing objects to ensure idempotency
DROP FUNCTION IF EXISTS public.r2814_callback_kpis();
DROP FUNCTION IF EXISTS public.r2814_top_engineers();
DROP FUNCTION IF EXISTS public.r2814_recent_callbacks();
DROP FUNCTION IF EXISTS public.r2814_script_effectiveness();
DROP FUNCTION IF EXISTS public.r2814_root_cause_breakdown();
DROP FUNCTION IF EXISTS public.r2814_outcome_funnel();
DROP FUNCTION IF EXISTS public.r2814_winback_revenue();
DROP FUNCTION IF EXISTS public.r2814_verdict_summary();
DROP FUNCTION IF EXISTS public.r2814_monthly_trend();

DROP TABLE IF EXISTS public.engineer_callback_records_r2814 CASCADE;
DROP TABLE IF EXISTS public.recovery_script_library_r2814 CASCADE;

-- ============================================================================
-- TABLE 1: Recovery script library
-- ============================================================================
CREATE TABLE public.recovery_script_library_r2814 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  script_code text NOT NULL UNIQUE,
  script_title text NOT NULL,
  root_cause_target text NOT NULL CHECK (root_cause_target IN ('price','service_delay','engineer_quality','part_quality','competitor','relocation','budget_cut','other')),
  script_body text NOT NULL,
  expected_winback_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  uses_count integer NOT NULL DEFAULT 0,
  wins_count integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','retired','draft')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.recovery_script_library_r2814 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.recovery_script_library_r2814
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.recovery_script_library_r2814
  (script_code, script_title, root_cause_target, script_body, expected_winback_rate_pct, uses_count, wins_count, status)
VALUES
  ('SCR-PRICE-01','Price objection - tier swap','price','Acknowledge price concern, offer Silver tier swap with extended payment terms, emphasize 24x7 coverage retention',42.50,48,21,'active'),
  ('SCR-DELAY-02','Service delay - SLA upgrade','service_delay','Apologize for delays, offer 2-hour SLA upgrade for next 3 months free, assign dedicated engineer',55.00,36,22,'active'),
  ('SCR-QUAL-03','Engineer quality - rotation','engineer_quality','Acknowledge engineer mismatch, offer rotation to senior engineer, schedule supervised first visit',61.25,28,19,'active'),
  ('SCR-PART-04','Part quality - OEM guarantee','part_quality','Confirm OEM-only parts policy, share certification, offer 90-day part warranty doubling',48.00,22,12,'active'),
  ('SCR-COMP-05','Competitor switch - match offer','competitor','Ask competitor offer details, match within 10 percent, add free preventive maintenance month',38.50,42,17,'active'),
  ('SCR-BUDGET-06','Budget cut - tier downgrade','budget_cut','Offer Bronze tier downgrade preserving core coverage, defer-renewal option for 60 days',32.00,18,6,'active'),
  ('SCR-RELOC-07','Relocation - network bridge','relocation','Confirm new location, bridge service via partner network if outside zone, transfer credits',25.00,12,3,'active');

-- ============================================================================
-- TABLE 2: Engineer callback records
-- ============================================================================
CREATE TABLE public.engineer_callback_records_r2814 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  callback_date date NOT NULL,
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  customer_org text NOT NULL,
  customer_segment text NOT NULL CHECK (customer_segment IN ('hospital','clinic','diagnostic','dental','veterinary')),
  churn_risk_score integer NOT NULL CHECK (churn_risk_score BETWEEN 0 AND 100),
  root_cause text NOT NULL CHECK (root_cause IN ('price','service_delay','engineer_quality','part_quality','competitor','relocation','budget_cut','other')),
  script_code_used text NOT NULL,
  call_duration_minutes integer NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('renewed','partial_renewal','escalated','postponed','lost','no_answer')),
  winback_value_rupees numeric(12,2) NOT NULL DEFAULT 0,
  verdict text NOT NULL CHECK (verdict IN ('excellent','good','average','poor','script_failure')),
  founder_review_flag boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_callback_records_r2814 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.engineer_callback_records_r2814
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.engineer_callback_records_r2814
  (callback_date, engineer_name, engineer_code, customer_org, customer_segment, churn_risk_score, root_cause, script_code_used, call_duration_minutes, outcome, winback_value_rupees, verdict, founder_review_flag, notes)
VALUES
  ('2026-06-02'::date,'Ramesh Iyer','ENG-1042','Apollo Diagnostics Vizag','diagnostic',82,'price','SCR-PRICE-01',24,'renewed',148000,'excellent',false,'Customer accepted Silver tier swap, signed 12mo'),
  ('2026-06-03'::date,'Anjali Reddy','ENG-1108','Care Hospital Banjara','hospital',76,'service_delay','SCR-DELAY-02',31,'renewed',285000,'excellent',false,'Dedicated engineer assigned, 2hr SLA confirmed'),
  ('2026-06-05'::date,'Vikram Singh','ENG-1175','Smile Dental Jubilee','dental',68,'engineer_quality','SCR-QUAL-03',18,'partial_renewal',62000,'good',false,'Rotated to senior, signed 6mo trial'),
  ('2026-06-07'::date,'Priya Nair','ENG-1063','Vasan Eye Care','clinic',71,'part_quality','SCR-PART-04',22,'renewed',95000,'good',false,'OEM certification shared, warranty doubled'),
  ('2026-06-09'::date,'Sandeep Kumar','ENG-1201','MedScan Imaging','diagnostic',88,'competitor','SCR-COMP-05',35,'lost',0,'script_failure',true,'Competitor offered 30 percent lower, beyond match band'),
  ('2026-06-11'::date,'Ramesh Iyer','ENG-1042','City Animal Hospital','veterinary',58,'budget_cut','SCR-BUDGET-06',16,'partial_renewal',24000,'average',false,'Downgraded to Bronze tier'),
  ('2026-06-12'::date,'Meera Joshi','ENG-1144','Sunrise Hospital Hitec','hospital',79,'relocation','SCR-RELOC-07',28,'postponed',0,'poor',true,'New location outside service zone, no partner'),
  ('2026-06-14'::date,'Anjali Reddy','ENG-1108','Bright Smile Dental','dental',65,'price','SCR-PRICE-01',20,'renewed',58000,'excellent',false,'Extended payment terms accepted'),
  ('2026-06-15'::date,'Vikram Singh','ENG-1175','Pearl Diagnostics','diagnostic',73,'service_delay','SCR-DELAY-02',26,'escalated',0,'poor',true,'Customer demanded founder call, escalated up'),
  ('2026-06-17'::date,'Sandeep Kumar','ENG-1201','LifeLine Hospital','hospital',81,'engineer_quality','SCR-QUAL-03',33,'renewed',312000,'excellent',false,'Senior engineer + supervised visit closed deal'),
  ('2026-06-18'::date,'Priya Nair','ENG-1063','Vet Plus Madhapur','veterinary',62,'competitor','SCR-COMP-05',19,'no_answer',0,'average',false,'Three attempts, voicemail only'),
  ('2026-06-19'::date,'Meera Joshi','ENG-1144','Krishna Clinic','clinic',69,'price','SCR-PRICE-01',23,'renewed',42000,'good',false,'Tier swap accepted on call');

-- ============================================================================
-- RPC 1: Overall KPIs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_callback_kpis()
RETURNS TABLE (
  total_callbacks bigint,
  total_winback_rupees numeric,
  renewed_count bigint,
  lost_count bigint,
  winback_rate_pct numeric,
  avg_call_duration numeric,
  flagged_for_review bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    coalesce(sum(winback_value_rupees),0)::numeric,
    count(*) FILTER (WHERE outcome = 'renewed')::bigint,
    count(*) FILTER (WHERE outcome = 'lost')::bigint,
    CASE WHEN count(*) = 0 THEN 0
      ELSE round(100.0 * count(*) FILTER (WHERE outcome IN ('renewed','partial_renewal'))::numeric / count(*)::numeric, 2)
    END,
    round(avg(call_duration_minutes)::numeric, 1),
    count(*) FILTER (WHERE founder_review_flag)::bigint
  FROM public.engineer_callback_records_r2814;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_callback_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_callback_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: Top engineers by winback
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_top_engineers()
RETURNS TABLE (
  engineer_name text,
  engineer_code text,
  callback_count bigint,
  total_winback numeric,
  win_rate_pct numeric,
  avg_verdict_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.engineer_name,
    r.engineer_code,
    count(*)::bigint,
    coalesce(sum(r.winback_value_rupees),0)::numeric,
    round(100.0 * count(*) FILTER (WHERE r.outcome IN ('renewed','partial_renewal'))::numeric / NULLIF(count(*),0)::numeric, 2),
    round(avg(CASE r.verdict
      WHEN 'excellent' THEN 5
      WHEN 'good' THEN 4
      WHEN 'average' THEN 3
      WHEN 'poor' THEN 2
      WHEN 'script_failure' THEN 1
      ELSE 0 END)::numeric, 2)
  FROM public.engineer_callback_records_r2814 r
  GROUP BY r.engineer_name, r.engineer_code
  ORDER BY sum(r.winback_value_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_top_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_top_engineers() TO authenticated;

-- ============================================================================
-- RPC 3: Recent callbacks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_recent_callbacks()
RETURNS TABLE (
  callback_date date,
  engineer_name text,
  customer_org text,
  customer_segment text,
  root_cause text,
  script_code_used text,
  outcome text,
  winback_value_rupees numeric,
  verdict text,
  founder_review_flag boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.callback_date, r.engineer_name, r.customer_org, r.customer_segment,
    r.root_cause, r.script_code_used, r.outcome, r.winback_value_rupees,
    r.verdict, r.founder_review_flag
  FROM public.engineer_callback_records_r2814 r
  ORDER BY r.callback_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_recent_callbacks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_recent_callbacks() TO authenticated;

-- ============================================================================
-- RPC 4: Script effectiveness
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_script_effectiveness()
RETURNS TABLE (
  script_code text,
  script_title text,
  root_cause_target text,
  expected_rate_pct numeric,
  actual_uses bigint,
  actual_wins bigint,
  actual_winback numeric,
  actual_rate_pct numeric,
  delta_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    s.script_code,
    s.script_title,
    s.root_cause_target,
    s.expected_winback_rate_pct,
    count(r.id)::bigint,
    count(r.id) FILTER (WHERE r.outcome IN ('renewed','partial_renewal'))::bigint,
    coalesce(sum(r.winback_value_rupees),0)::numeric,
    CASE WHEN count(r.id) = 0 THEN 0
      ELSE round(100.0 * count(r.id) FILTER (WHERE r.outcome IN ('renewed','partial_renewal'))::numeric / count(r.id)::numeric, 2)
    END,
    CASE WHEN count(r.id) = 0 THEN 0
      ELSE round(100.0 * count(r.id) FILTER (WHERE r.outcome IN ('renewed','partial_renewal'))::numeric / count(r.id)::numeric - s.expected_winback_rate_pct, 2)
    END
  FROM public.recovery_script_library_r2814 s
  LEFT JOIN public.engineer_callback_records_r2814 r ON r.script_code_used = s.script_code
  GROUP BY s.script_code, s.script_title, s.root_cause_target, s.expected_winback_rate_pct
  ORDER BY s.script_code;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_script_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_script_effectiveness() TO authenticated;

-- ============================================================================
-- RPC 5: Root cause breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_root_cause_breakdown()
RETURNS TABLE (
  root_cause text,
  callback_count bigint,
  win_count bigint,
  loss_count bigint,
  total_winback numeric,
  recovery_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.root_cause,
    count(*)::bigint,
    count(*) FILTER (WHERE r.outcome IN ('renewed','partial_renewal'))::bigint,
    count(*) FILTER (WHERE r.outcome = 'lost')::bigint,
    coalesce(sum(r.winback_value_rupees),0)::numeric,
    round(100.0 * count(*) FILTER (WHERE r.outcome IN ('renewed','partial_renewal'))::numeric / NULLIF(count(*),0)::numeric, 2)
  FROM public.engineer_callback_records_r2814 r
  GROUP BY r.root_cause
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_root_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_root_cause_breakdown() TO authenticated;

-- ============================================================================
-- RPC 6: Outcome funnel
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_outcome_funnel()
RETURNS TABLE (
  outcome text,
  count_value bigint,
  total_value numeric,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT count(*) INTO v_total FROM public.engineer_callback_records_r2814;
  RETURN QUERY
  SELECT
    r.outcome,
    count(*)::bigint,
    coalesce(sum(r.winback_value_rupees),0)::numeric,
    round(100.0 * count(*)::numeric / NULLIF(v_total,0)::numeric, 2)
  FROM public.engineer_callback_records_r2814 r
  GROUP BY r.outcome
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_outcome_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_outcome_funnel() TO authenticated;

-- ============================================================================
-- RPC 7: Winback revenue by segment
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_winback_revenue()
RETURNS TABLE (
  customer_segment text,
  callback_count bigint,
  total_winback numeric,
  avg_winback numeric,
  best_engineer text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.customer_segment,
    count(*)::bigint,
    coalesce(sum(r.winback_value_rupees),0)::numeric,
    round(avg(r.winback_value_rupees)::numeric, 2),
    (SELECT r2.engineer_name FROM public.engineer_callback_records_r2814 r2
       WHERE r2.customer_segment = r.customer_segment
       ORDER BY r2.winback_value_rupees DESC LIMIT 1)
  FROM public.engineer_callback_records_r2814 r
  GROUP BY r.customer_segment
  ORDER BY sum(r.winback_value_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_winback_revenue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_winback_revenue() TO authenticated;

-- ============================================================================
-- RPC 8: Verdict summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_verdict_summary()
RETURNS TABLE (
  verdict text,
  count_value bigint,
  total_winback numeric,
  flagged_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.verdict,
    count(*)::bigint,
    coalesce(sum(r.winback_value_rupees),0)::numeric,
    count(*) FILTER (WHERE r.founder_review_flag)::bigint
  FROM public.engineer_callback_records_r2814 r
  GROUP BY r.verdict
  ORDER BY
    CASE r.verdict
      WHEN 'excellent' THEN 1
      WHEN 'good' THEN 2
      WHEN 'average' THEN 3
      WHEN 'poor' THEN 4
      WHEN 'script_failure' THEN 5
      ELSE 6 END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_verdict_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_verdict_summary() TO authenticated;

-- ============================================================================
-- RPC 9: Monthly trend (week buckets)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2814_monthly_trend()
RETURNS TABLE (
  week_start date,
  callback_count bigint,
  winback_value numeric,
  flagged_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', r.callback_date)::date,
    count(*)::bigint,
    coalesce(sum(r.winback_value_rupees),0)::numeric,
    count(*) FILTER (WHERE r.founder_review_flag)::bigint
  FROM public.engineer_callback_records_r2814 r
  GROUP BY date_trunc('week', r.callback_date)
  ORDER BY date_trunc('week', r.callback_date);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2814_monthly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2814_monthly_trend() TO authenticated;

COMMIT;
