BEGIN;

-- Round 2290: Engineer expense-claim audit blitz
-- Random sample of expense claims for fraud check, audit findings, and recovery log

CREATE TABLE IF NOT EXISTS public.expense_audit_samples_r2290 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_ref text NOT NULL,
  engineer_user_id uuid REFERENCES public.profiles(id),
  engineer_email text,
  claim_category text NOT NULL CHECK (claim_category IN (
    'travel','fuel','meals','lodging','spare_parts','tools','toll','parking','misc'
  )),
  claim_amount_rupees numeric(12,2) NOT NULL,
  claim_submitted_at timestamptz NOT NULL DEFAULT now(),
  sample_batch text NOT NULL,
  sample_method text NOT NULL DEFAULT 'random' CHECK (sample_method IN (
    'random','risk_weighted','threshold_amount','repeat_offender','outlier'
  )),
  audit_status text NOT NULL DEFAULT 'queued' CHECK (audit_status IN (
    'queued','in_review','clean','minor_issue','fraud_suspected','rejected','recovered'
  )),
  risk_score int CHECK (risk_score BETWEEN 0 AND 100),
  selected_at timestamptz NOT NULL DEFAULT now(),
  notes text
);

CREATE TABLE IF NOT EXISTS public.expense_audit_findings_r2290 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sample_id uuid REFERENCES public.expense_audit_samples_r2290(id) ON DELETE CASCADE,
  finding_type text NOT NULL CHECK (finding_type IN (
    'duplicate_receipt','inflated_amount','missing_receipt','altered_receipt',
    'personal_use','out_of_policy','wrong_category','round_number_pattern','clean'
  )),
  severity text NOT NULL CHECK (severity IN ('clean','minor','moderate','severe','fraud')),
  flagged_amount_rupees numeric(12,2),
  recovery_amount_rupees numeric(12,2),
  recovery_status text NOT NULL DEFAULT 'pending' CHECK (recovery_status IN (
    'pending','deduction_scheduled','recovered','written_off','disputed'
  )),
  auditor_email text NOT NULL,
  finding_notes text,
  logged_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

ALTER TABLE public.expense_audit_samples_r2290 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_audit_findings_r2290 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.expense_audit_samples_r2290;
CREATE POLICY founder_all ON public.expense_audit_samples_r2290
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.expense_audit_findings_r2290;
CREATE POLICY founder_all ON public.expense_audit_findings_r2290
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed sample expense claims from existing engineer profiles
INSERT INTO public.expense_audit_samples_r2290
  (claim_ref, engineer_user_id, engineer_email, claim_category, claim_amount_rupees,
   claim_submitted_at, sample_batch, sample_method, audit_status, risk_score, notes)
SELECT
  'EXP-2026-' || lpad((row_number() OVER ())::text, 5, '0'),
  p.id,
  p.email,
  sig.cat,
  sig.amt,
  now() - (sig.days_ago || ' days')::interval,
  'BLITZ-2026-06',
  sig.method,
  sig.status,
  sig.risk,
  sig.note
FROM (
  SELECT id, email FROM public.profiles WHERE role = 'engineer' ORDER BY created_at DESC LIMIT 8
) p
CROSS JOIN LATERAL (
  VALUES
    ('travel',  4500.00, 12, 'random',         'in_review',       45, 'Cab fare 4.5k for 18km trip — verify meter slip'),
    ('fuel',    8200.00,  8, 'threshold_amount','fraud_suspected', 82, 'Fuel claim exceeds monthly cap; receipt edited'),
    ('meals',   1200.00, 15, 'random',         'clean',           18, 'Within policy, receipt clear'),
    ('lodging', 6800.00, 20, 'risk_weighted',  'minor_issue',     58, 'Hotel above per-diem; needs approval doc'),
    ('toll',     850.00,  5, 'random',         'recovered',       30, 'Duplicate toll claim recovered via payroll'),
    ('spare_parts', 12500.00, 11, 'outlier',   'in_review',       70, 'Part claimed but inventory shows none issued')
) sig(cat, amt, days_ago, method, status, risk, note)
ON CONFLICT DO NOTHING;

-- Seed audit findings tied to flagged samples
INSERT INTO public.expense_audit_findings_r2290
  (sample_id, finding_type, severity, flagged_amount_rupees, recovery_amount_rupees,
   recovery_status, auditor_email, finding_notes)
SELECT
  s.id,
  CASE s.audit_status
    WHEN 'fraud_suspected' THEN 'altered_receipt'
    WHEN 'minor_issue'     THEN 'out_of_policy'
    WHEN 'recovered'       THEN 'duplicate_receipt'
    WHEN 'in_review'       THEN 'missing_receipt'
    ELSE 'clean'
  END,
  CASE s.audit_status
    WHEN 'fraud_suspected' THEN 'fraud'
    WHEN 'minor_issue'     THEN 'minor'
    WHEN 'recovered'       THEN 'moderate'
    WHEN 'in_review'       THEN 'moderate'
    ELSE 'clean'
  END,
  CASE WHEN s.audit_status IN ('fraud_suspected','minor_issue','recovered','in_review')
       THEN s.claim_amount_rupees ELSE 0 END,
  CASE s.audit_status
    WHEN 'recovered'       THEN s.claim_amount_rupees
    WHEN 'fraud_suspected' THEN s.claim_amount_rupees
    ELSE 0
  END,
  CASE s.audit_status
    WHEN 'recovered'       THEN 'recovered'
    WHEN 'fraud_suspected' THEN 'deduction_scheduled'
    WHEN 'minor_issue'     THEN 'pending'
    ELSE 'pending'
  END,
  'audit@equipseva.com',
  'Auto-logged from blitz batch BLITZ-2026-06'
FROM public.expense_audit_samples_r2290 s
WHERE s.sample_batch = 'BLITZ-2026-06'
ON CONFLICT DO NOTHING;

-- RPC 1: Blitz KPIs
CREATE OR REPLACE FUNCTION public.r2290_blitz_kpis()
RETURNS TABLE (
  total_samples int,
  in_review int,
  clean_claims int,
  fraud_suspected int,
  recovered_claims int,
  total_flagged_rupees numeric,
  total_recovered_rupees numeric,
  avg_risk_score numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(*))::int FROM public.expense_audit_samples_r2290),
    (SELECT (COUNT(*) FILTER (WHERE audit_status = 'in_review'))::int FROM public.expense_audit_samples_r2290),
    (SELECT (COUNT(*) FILTER (WHERE audit_status = 'clean'))::int FROM public.expense_audit_samples_r2290),
    (SELECT (COUNT(*) FILTER (WHERE audit_status = 'fraud_suspected'))::int FROM public.expense_audit_samples_r2290),
    (SELECT (COUNT(*) FILTER (WHERE audit_status = 'recovered'))::int FROM public.expense_audit_samples_r2290),
    (SELECT COALESCE(SUM(flagged_amount_rupees), 0) FROM public.expense_audit_findings_r2290),
    (SELECT COALESCE(SUM(recovery_amount_rupees), 0) FROM public.expense_audit_findings_r2290),
    (SELECT COALESCE(ROUND(AVG(risk_score)::numeric, 1), 0) FROM public.expense_audit_samples_r2290);
END $$;

-- RPC 2: Sampled claims list
CREATE OR REPLACE FUNCTION public.r2290_sampled_claims()
RETURNS TABLE (
  sample_id uuid,
  claim_ref text,
  engineer_email text,
  claim_category text,
  claim_amount_rupees numeric,
  sample_method text,
  audit_status text,
  risk_score int,
  claim_submitted_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.claim_ref, s.engineer_email, s.claim_category, s.claim_amount_rupees,
         s.sample_method, s.audit_status, s.risk_score, s.claim_submitted_at
  FROM public.expense_audit_samples_r2290 s
  ORDER BY
    CASE s.audit_status
      WHEN 'fraud_suspected' THEN 1
      WHEN 'in_review' THEN 2
      WHEN 'minor_issue' THEN 3
      WHEN 'recovered' THEN 4
      ELSE 5
    END,
    s.risk_score DESC NULLS LAST
  LIMIT 30;
END $$;

-- RPC 3: Category breakdown
CREATE OR REPLACE FUNCTION public.r2290_category_breakdown()
RETURNS TABLE (
  claim_category text,
  sample_count int,
  total_amount_rupees numeric,
  fraud_count int,
  clean_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.claim_category,
    (COUNT(*))::int,
    (SUM(s.claim_amount_rupees))::numeric,
    (COUNT(*) FILTER (WHERE s.audit_status = 'fraud_suspected'))::int,
    (COUNT(*) FILTER (WHERE s.audit_status = 'clean'))::int
  FROM public.expense_audit_samples_r2290 s
  GROUP BY s.claim_category
  ORDER BY SUM(s.claim_amount_rupees) DESC;
END $$;

-- RPC 4: Findings log
CREATE OR REPLACE FUNCTION public.r2290_findings_log()
RETURNS TABLE (
  finding_id uuid,
  claim_ref text,
  engineer_email text,
  finding_type text,
  severity text,
  flagged_amount_rupees numeric,
  recovery_amount_rupees numeric,
  recovery_status text,
  auditor_email text,
  logged_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, s.claim_ref, s.engineer_email, f.finding_type, f.severity,
         f.flagged_amount_rupees, f.recovery_amount_rupees, f.recovery_status,
         f.auditor_email, f.logged_at
  FROM public.expense_audit_findings_r2290 f
  JOIN public.expense_audit_samples_r2290 s ON s.id = f.sample_id
  ORDER BY
    CASE f.severity WHEN 'fraud' THEN 1 WHEN 'severe' THEN 2 WHEN 'moderate' THEN 3 WHEN 'minor' THEN 4 ELSE 5 END,
    f.logged_at DESC
  LIMIT 30;
END $$;

-- RPC 5: Engineer-level offender ranking
CREATE OR REPLACE FUNCTION public.r2290_engineer_ranking()
RETURNS TABLE (
  engineer_email text,
  claim_count int,
  total_flagged_rupees numeric,
  fraud_count int,
  recovery_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_email,
    (COUNT(*))::int,
    (COALESCE(SUM(f.flagged_amount_rupees), 0))::numeric,
    (COUNT(*) FILTER (WHERE s.audit_status = 'fraud_suspected'))::int,
    (COALESCE(SUM(f.recovery_amount_rupees), 0))::numeric
  FROM public.expense_audit_samples_r2290 s
  LEFT JOIN public.expense_audit_findings_r2290 f ON f.sample_id = s.id
  GROUP BY s.engineer_email
  ORDER BY COALESCE(SUM(f.flagged_amount_rupees), 0) DESC
  LIMIT 15;
END $$;

-- RPC 6: Recovery pipeline
CREATE OR REPLACE FUNCTION public.r2290_recovery_pipeline()
RETURNS TABLE (
  recovery_status text,
  finding_count int,
  total_recovery_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.recovery_status,
    (COUNT(*))::int,
    (COALESCE(SUM(f.recovery_amount_rupees), 0))::numeric
  FROM public.expense_audit_findings_r2290 f
  GROUP BY f.recovery_status
  ORDER BY SUM(f.recovery_amount_rupees) DESC NULLS LAST;
END $$;

-- RPC 7: Sampling method effectiveness
CREATE OR REPLACE FUNCTION public.r2290_method_effectiveness()
RETURNS TABLE (
  sample_method text,
  samples_taken int,
  fraud_hits int,
  hit_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.sample_method,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE s.audit_status = 'fraud_suspected'))::int,
    ROUND(
      (COUNT(*) FILTER (WHERE s.audit_status = 'fraud_suspected'))::numeric * 100.0
      / NULLIF(COUNT(*), 0),
      1
    )
  FROM public.expense_audit_samples_r2290 s
  GROUP BY s.sample_method
  ORDER BY COUNT(*) FILTER (WHERE s.audit_status = 'fraud_suspected') DESC;
END $$;

REVOKE ALL ON FUNCTION public.r2290_blitz_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2290_sampled_claims() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2290_category_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2290_findings_log() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2290_engineer_ranking() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2290_recovery_pipeline() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2290_method_effectiveness() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2290_blitz_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2290_sampled_claims() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2290_category_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2290_findings_log() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2290_engineer_ranking() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2290_recovery_pipeline() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2290_method_effectiveness() TO authenticated;

COMMIT;
