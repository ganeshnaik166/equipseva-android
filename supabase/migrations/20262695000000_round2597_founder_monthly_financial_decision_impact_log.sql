-- Round 2597: founder-monthly-financial-decision-impact-log
-- Tables: founder_monthly_financial_decisions_r2597 + financial_decision_reviews_r2597
-- RPCs: 7 founder-only

BEGIN;

-- ============================================================
-- Table 1: monthly financial decisions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_monthly_financial_decisions_r2597 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  decision_kind text NOT NULL CHECK (decision_kind IN ('hire','spend','cut','investment','refund','restructure')),
  decision_summary_md text NOT NULL,
  spend_rupees bigint NOT NULL DEFAULT 0,
  roi_estimate_rupees bigint NOT NULL DEFAULT 0,
  payback_months numeric(8,2),
  kill_rate_decision boolean NOT NULL DEFAULT false,
  decision_quality_grade text NOT NULL CHECK (decision_quality_grade IN ('A','B','C','D','F')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_monthly_financial_decisions_r2597 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_monthly_financial_decisions_r2597;
CREATE POLICY founder_all ON public.founder_monthly_financial_decisions_r2597
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Table 2: reviews of decisions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.financial_decision_reviews_r2597 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_monthly_financial_decisions_r2597(id) ON DELETE CASCADE,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  review_kind text NOT NULL CHECK (review_kind IN ('monthly','quarterly','postmortem')),
  summary_md text NOT NULL,
  lesson_md text,
  owner_email text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.financial_decision_reviews_r2597 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.financial_decision_reviews_r2597;
CREATE POLICY founder_all ON public.financial_decision_reviews_r2597
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seed decisions (5 rows)
-- ============================================================
INSERT INTO public.founder_monthly_financial_decisions_r2597
  (month_label, decision_kind, decision_summary_md, spend_rupees, roi_estimate_rupees, payback_months, kill_rate_decision, decision_quality_grade, owner_email, status, notes)
VALUES
  ('2026-04','hire','Hired senior field ops lead to cover Hyderabad + Pune metros',1800000,5400000,8.00,false,'A','founder@equipseva.in','reviewed','Lead closed 12 hospital deals in first 90 days'),
  ('2026-04','spend','Spare parts inventory expansion for top-20 SKUs',2500000,7500000,6.50,false,'B','founder@equipseva.in','reviewed','Reduced average repair turnaround by 38 percent'),
  ('2026-05','cut','Killed underperforming Bengaluru micro-pilot for dental segment',-450000,0,0.00,true,'A','founder@equipseva.in','closed','Saved monthly burn of 4.5L; reallocated to Mumbai chain'),
  ('2026-05','investment','Razorpay Route + Cashfree dual-rail integration build',900000,2700000,10.00,false,'B','founder@equipseva.in','reviewed','Reduced payment failure rate from 8 percent to 1.2 percent'),
  ('2026-06','refund','Bulk AMC refund to hospital chain after 2 missed SLAs',-180000,0,0.00,false,'C','founder@equipseva.in','open','Recovery plan: weekly chain QBR for 90 days');

-- ============================================================
-- Seed reviews (3 rows)
-- ============================================================
INSERT INTO public.financial_decision_reviews_r2597
  (decision_id, review_kind, summary_md, lesson_md, owner_email, notes)
SELECT id, 'monthly', 'April hire performance review: exceeded ramp targets', 'Hiring senior ops first beats junior-heavy team', 'founder@equipseva.in', 'Repeat playbook in Q3'
FROM public.founder_monthly_financial_decisions_r2597 WHERE month_label = '2026-04' AND decision_kind = 'hire' LIMIT 1;

INSERT INTO public.financial_decision_reviews_r2597
  (decision_id, review_kind, summary_md, lesson_md, owner_email, notes)
SELECT id, 'quarterly', 'Bengaluru dental kill: 90 day savings confirmed at 13.5L', 'Kill fast when CAC payback over 18 months', 'founder@equipseva.in', 'Lesson logged to playbook'
FROM public.founder_monthly_financial_decisions_r2597 WHERE month_label = '2026-05' AND decision_kind = 'cut' LIMIT 1;

INSERT INTO public.financial_decision_reviews_r2597
  (decision_id, review_kind, summary_md, lesson_md, owner_email, notes)
SELECT id, 'postmortem', 'Refund postmortem: SLA misses traced to dispatcher gap', 'Add second-shift dispatcher before adding chain accounts', 'founder@equipseva.in', 'Action: hire dispatcher by July'
FROM public.founder_monthly_financial_decisions_r2597 WHERE decision_kind = 'refund' LIMIT 1;

-- ============================================================
-- RPC 1: list_decisions_r2597
-- ============================================================
DROP FUNCTION IF EXISTS public.list_decisions_r2597();
CREATE OR REPLACE FUNCTION public.list_decisions_r2597()
RETURNS TABLE (
  id uuid,
  month_label text,
  decision_kind text,
  decision_summary_md text,
  spend_rupees bigint,
  roi_estimate_rupees bigint,
  payback_months numeric,
  kill_rate_decision boolean,
  decision_quality_grade text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.month_label, d.decision_kind, d.decision_summary_md, d.spend_rupees,
         d.roi_estimate_rupees, d.payback_months, d.kill_rate_decision,
         d.decision_quality_grade, d.owner_email, d.status, d.notes, d.created_at
  FROM public.founder_monthly_financial_decisions_r2597 d
  ORDER BY d.month_label DESC, d.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_decisions_r2597() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decisions_r2597() TO authenticated;

-- ============================================================
-- RPC 2: list_reviews_r2597
-- ============================================================
DROP FUNCTION IF EXISTS public.list_reviews_r2597();
CREATE OR REPLACE FUNCTION public.list_reviews_r2597()
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  reviewed_at timestamptz,
  review_kind text,
  summary_md text,
  lesson_md text,
  owner_email text,
  notes text,
  month_label text,
  decision_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.decision_id, r.reviewed_at, r.review_kind, r.summary_md, r.lesson_md,
         r.owner_email, r.notes, d.month_label, d.decision_kind
  FROM public.financial_decision_reviews_r2597 r
  JOIN public.founder_monthly_financial_decisions_r2597 d ON d.id = r.decision_id
  ORDER BY r.reviewed_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r2597() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reviews_r2597() TO authenticated;

-- ============================================================
-- RPC 3: top_payback_decisions_r2597
-- ============================================================
DROP FUNCTION IF EXISTS public.top_payback_decisions_r2597();
CREATE OR REPLACE FUNCTION public.top_payback_decisions_r2597()
RETURNS TABLE (
  id uuid,
  month_label text,
  decision_kind text,
  decision_summary_md text,
  spend_rupees bigint,
  roi_estimate_rupees bigint,
  payback_months numeric,
  decision_quality_grade text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.month_label, d.decision_kind, d.decision_summary_md, d.spend_rupees,
         d.roi_estimate_rupees, d.payback_months, d.decision_quality_grade
  FROM public.founder_monthly_financial_decisions_r2597 d
  WHERE d.payback_months IS NOT NULL AND d.payback_months > 0
  ORDER BY d.payback_months ASC NULLS LAST
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_payback_decisions_r2597() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_payback_decisions_r2597() TO authenticated;

-- ============================================================
-- RPC 4: decision_kind_distribution_r2597
-- ============================================================
DROP FUNCTION IF EXISTS public.decision_kind_distribution_r2597();
CREATE OR REPLACE FUNCTION public.decision_kind_distribution_r2597()
RETURNS TABLE (
  decision_kind text,
  decision_count bigint,
  total_spend_rupees bigint,
  total_roi_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.decision_kind,
         COUNT(*)::bigint AS decision_count,
         COALESCE(SUM(d.spend_rupees),0)::bigint AS total_spend_rupees,
         COALESCE(SUM(d.roi_estimate_rupees),0)::bigint AS total_roi_rupees
  FROM public.founder_monthly_financial_decisions_r2597 d
  GROUP BY d.decision_kind
  ORDER BY decision_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_kind_distribution_r2597() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_kind_distribution_r2597() TO authenticated;

-- ============================================================
-- RPC 5: grade_summary_r2597
-- ============================================================
DROP FUNCTION IF EXISTS public.grade_summary_r2597();
CREATE OR REPLACE FUNCTION public.grade_summary_r2597()
RETURNS TABLE (
  decision_quality_grade text,
  decision_count bigint,
  avg_payback_months numeric,
  total_spend_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.decision_quality_grade,
         COUNT(*)::bigint AS decision_count,
         ROUND(AVG(d.payback_months)::numeric, 2) AS avg_payback_months,
         COALESCE(SUM(d.spend_rupees),0)::bigint AS total_spend_rupees
  FROM public.founder_monthly_financial_decisions_r2597 d
  GROUP BY d.decision_quality_grade
  ORDER BY d.decision_quality_grade ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.grade_summary_r2597() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grade_summary_r2597() TO authenticated;

-- ============================================================
-- RPC 6: monthly_decision_trend_r2597
-- ============================================================
DROP FUNCTION IF EXISTS public.monthly_decision_trend_r2597();
CREATE OR REPLACE FUNCTION public.monthly_decision_trend_r2597()
RETURNS TABLE (
  month_label text,
  decision_count bigint,
  total_spend_rupees bigint,
  total_roi_rupees bigint,
  kill_decisions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.month_label,
         COUNT(*)::bigint AS decision_count,
         COALESCE(SUM(d.spend_rupees),0)::bigint AS total_spend_rupees,
         COALESCE(SUM(d.roi_estimate_rupees),0)::bigint AS total_roi_rupees,
         COUNT(*) FILTER (WHERE d.kill_rate_decision)::bigint AS kill_decisions
  FROM public.founder_monthly_financial_decisions_r2597 d
  GROUP BY d.month_label
  ORDER BY d.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_decision_trend_r2597() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_decision_trend_r2597() TO authenticated;

-- ============================================================
-- RPC 7: founder_pulse_summary_r2597
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_pulse_summary_r2597();
CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2597()
RETURNS TABLE (
  metric_label text,
  metric_value text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total_decisions bigint;
  v_open_decisions bigint;
  v_kill_decisions bigint;
  v_total_spend bigint;
  v_total_roi bigint;
  v_avg_payback numeric;
  v_review_count bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'open'),
         COUNT(*) FILTER (WHERE kill_rate_decision),
         COALESCE(SUM(spend_rupees),0), COALESCE(SUM(roi_estimate_rupees),0),
         ROUND(AVG(payback_months)::numeric, 2)
  INTO v_total_decisions, v_open_decisions, v_kill_decisions, v_total_spend, v_total_roi, v_avg_payback
  FROM public.founder_monthly_financial_decisions_r2597;

  SELECT COUNT(*) INTO v_review_count FROM public.financial_decision_reviews_r2597;

  RETURN QUERY
  SELECT 'total_decisions'::text, COALESCE(v_total_decisions,0)::text
  UNION ALL SELECT 'open_decisions'::text, COALESCE(v_open_decisions,0)::text
  UNION ALL SELECT 'kill_decisions'::text, COALESCE(v_kill_decisions,0)::text
  UNION ALL SELECT 'total_spend_rupees'::text, COALESCE(v_total_spend,0)::text
  UNION ALL SELECT 'total_roi_rupees'::text, COALESCE(v_total_roi,0)::text
  UNION ALL SELECT 'avg_payback_months'::text, COALESCE(v_avg_payback,0)::text
  UNION ALL SELECT 'review_count'::text, COALESCE(v_review_count,0)::text;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2597() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2597() TO authenticated;

