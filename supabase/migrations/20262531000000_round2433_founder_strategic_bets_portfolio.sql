-- Round 2433: founder-strategic-bets-portfolio
-- Bet × thesis × hypothesis × evidence × proceed/pivot/kill × confidence × revenue impact

CREATE TABLE IF NOT EXISTS public.founder_strategic_bets_r2433 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  bet_name text NOT NULL,
  bet_thesis_md text NOT NULL,
  hypothesis_md text NOT NULL,
  evidence_for_md text,
  evidence_against_md text,
  status text NOT NULL CHECK (status IN ('exploring','validating','proceeding','pivoting','killed','shipped')),
  confidence_pct int NOT NULL CHECK (confidence_pct BETWEEN 0 AND 100),
  revenue_impact_rupees bigint NOT NULL DEFAULT 0,
  time_to_evidence_days int NOT NULL DEFAULT 30,
  owner_email text NOT NULL,
  last_review_at timestamptz,
  next_review_at timestamptz,
  kill_threshold text,
  notes text
);

CREATE TABLE IF NOT EXISTS public.bet_evidence_log_r2433 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  bet_id uuid NOT NULL REFERENCES public.founder_strategic_bets_r2433(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  evidence_kind text NOT NULL CHECK (evidence_kind IN ('supporting','refuting','neutral')),
  evidence_md text NOT NULL,
  source_link text,
  confidence_delta_pct int NOT NULL DEFAULT 0 CHECK (confidence_delta_pct BETWEEN -100 AND 100),
  decision_impact text,
  notes text
);

ALTER TABLE public.founder_strategic_bets_r2433 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bet_evidence_log_r2433 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_strategic_bets_r2433;
CREATE POLICY founder_all ON public.founder_strategic_bets_r2433
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.bet_evidence_log_r2433;
CREATE POLICY founder_all ON public.bet_evidence_log_r2433
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed bets
INSERT INTO public.founder_strategic_bets_r2433
  (bet_name, bet_thesis_md, hypothesis_md, evidence_for_md, evidence_against_md, status, confidence_pct, revenue_impact_rupees, time_to_evidence_days, owner_email, last_review_at, next_review_at, kill_threshold, notes)
VALUES
  ('Hospital chain bulk AMC',
   'Multi-site hospital chains will pay 20% premium for unified AMC across all sites.',
   'If we sign 3 chains in 90 days at premium pricing, the bet is validated.',
   '2 chains in pilot. NPS 9.1. Procurement wants single invoice.',
   'Procurement cycles are slow. 1 chain delayed signing 60 days.',
   'validating', 65, 12000000, 90, 'founder@equipseva.in',
   now() - interval '7 days', now() + interval '14 days',
   'Less than 1 signed chain by day 90 = kill.',
   'Top revenue bet. Needs procurement-friendly contract template.'),
  ('Dental super-specialty vertical',
   'Dental clinics are underserved and pay faster than hospitals.',
   '50 dental clinics onboarded in 6 months at 60% gross margin.',
   '12 dental clinics signed. Payment cycle 7 days vs hospital 45.',
   'Equipment variety high. Engineer training cost up 30%.',
   'proceeding', 78, 8500000, 180, 'founder@equipseva.in',
   now() - interval '3 days', now() + interval '11 days',
   'Gross margin drops below 45% = pivot.',
   'Strongest vertical signal so far.'),
  ('AI-assisted triage for engineers',
   'AI symptom-to-diagnosis reduces engineer dispatch time by 40%.',
   'Pilot AI triage on 200 jobs. Median time-to-fix drops to under 4 hours.',
   'OpenAI fine-tune cost dropped 60%. 2 competitors shipping.',
   'Engineers resist AI. False positive rate at 18% in pilot.',
   'exploring', 35, 5000000, 60, 'founder@equipseva.in',
   now() - interval '14 days', now() + interval '7 days',
   'False positive over 20% in production = kill.',
   'Early signal. Need cleaner training data.'),
  ('International pilot Sri Lanka',
   'Sri Lanka hospitals will pay USD for AMC at 3x India ARPU.',
   'Sign 5 SL hospitals in 4 months. Cross-border payments work.',
   'SL government opened FDI in medtech. 1 LOI signed.',
   'Currency volatility. RBI cross-border compliance complex.',
   'exploring', 25, 6000000, 120, 'founder@equipseva.in',
   now() - interval '21 days', now() - interval '2 days',
   'Less than 2 LOIs by day 90 = kill.',
   'OVERDUE review. Compliance question still open.'),
  ('Engineer co-op equity ownership',
   'Engineers who own equity stay 3x longer and refer 5x more.',
   '20 top engineers offered 0.05% ESOP. Retention measured at 12 months.',
   'Pilot launched. 18 of 20 accepted. Referrals up 2x in 30 days.',
   'Cap table complexity. Investors flagged dilution concern.',
   'shipped', 88, 3000000, 365, 'founder@equipseva.in',
   now() - interval '5 days', now() + interval '25 days',
   'Retention does not improve by month 12 = pivot.',
   'Already shipped. Tracking for retention impact.');

INSERT INTO public.bet_evidence_log_r2433
  (bet_id, observed_at, evidence_kind, evidence_md, source_link, confidence_delta_pct, decision_impact, notes)
SELECT id, now() - interval '5 days', 'supporting',
       'Second chain agreed to pilot pricing.', 'https://internal.equipseva.in/deals/ch-2', 8,
       'Increase sales effort on chains.', 'Signal strong.'
FROM public.founder_strategic_bets_r2433 WHERE bet_name = 'Hospital chain bulk AMC';

INSERT INTO public.bet_evidence_log_r2433
  (bet_id, observed_at, evidence_kind, evidence_md, source_link, confidence_delta_pct, decision_impact, notes)
SELECT id, now() - interval '12 days', 'refuting',
       'Chain 3 delayed signing by 60 days due to procurement freeze.', 'https://internal.equipseva.in/deals/ch-3', -10,
       'Need procurement-friendly fast-track.', 'Risk to revenue ramp.'
FROM public.founder_strategic_bets_r2433 WHERE bet_name = 'Hospital chain bulk AMC';

INSERT INTO public.bet_evidence_log_r2433
  (bet_id, observed_at, evidence_kind, evidence_md, source_link, confidence_delta_pct, decision_impact, notes)
SELECT id, now() - interval '3 days', 'supporting',
       '12 dental clinics signed. Payment cycle confirmed at 7 days.', 'https://internal.equipseva.in/dental/cohort1', 12,
       'Double down on dental sales.', 'Strongest vertical so far.'
FROM public.founder_strategic_bets_r2433 WHERE bet_name = 'Dental super-specialty vertical';

INSERT INTO public.bet_evidence_log_r2433
  (bet_id, observed_at, evidence_kind, evidence_md, source_link, confidence_delta_pct, decision_impact, notes)
SELECT id, now() - interval '8 days', 'refuting',
       'AI triage false positive rate at 18% in pilot.', 'https://internal.equipseva.in/ai/eval-2433', -7,
       'Slow rollout. Improve training data.', 'Below kill threshold of 20%.'
FROM public.founder_strategic_bets_r2433 WHERE bet_name = 'AI-assisted triage for engineers';

INSERT INTO public.bet_evidence_log_r2433
  (bet_id, observed_at, evidence_kind, evidence_md, source_link, confidence_delta_pct, decision_impact, notes)
SELECT id, now() - interval '2 days', 'supporting',
       'Engineer referrals up 2x in 30 days post-ESOP grant.', 'https://internal.equipseva.in/coop/metrics', 5,
       'Expand co-op program to 50 engineers.', 'Early retention signal positive.'
FROM public.founder_strategic_bets_r2433 WHERE bet_name = 'Engineer co-op equity ownership';

-- RPCs

CREATE OR REPLACE FUNCTION public.list_bets_r2433()
RETURNS TABLE (
  id uuid, bet_name text, status text, confidence_pct int,
  revenue_impact_rupees bigint, time_to_evidence_days int,
  owner_email text, last_review_at timestamptz, next_review_at timestamptz,
  kill_threshold text, created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.bet_name, b.status, b.confidence_pct,
           b.revenue_impact_rupees, b.time_to_evidence_days,
           b.owner_email, b.last_review_at, b.next_review_at,
           b.kill_threshold, b.created_at
    FROM public.founder_strategic_bets_r2433 b
    ORDER BY b.revenue_impact_rupees DESC, b.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_bets_r2433() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bets_r2433() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_evidence_r2433()
RETURNS TABLE (
  id uuid, bet_name text, observed_at timestamptz, evidence_kind text,
  evidence_md text, source_link text, confidence_delta_pct int,
  decision_impact text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, b.bet_name, e.observed_at, e.evidence_kind,
           e.evidence_md, e.source_link, e.confidence_delta_pct,
           e.decision_impact
    FROM public.bet_evidence_log_r2433 e
    JOIN public.founder_strategic_bets_r2433 b ON b.id = e.bet_id
    ORDER BY e.observed_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_evidence_r2433() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_evidence_r2433() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_breakdown_r2433()
RETURNS TABLE (status text, bet_count bigint, total_revenue_rupees bigint, avg_confidence_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.status, COUNT(*)::bigint, COALESCE(SUM(b.revenue_impact_rupees),0)::bigint,
           ROUND(AVG(b.confidence_pct)::numeric, 1)
    FROM public.founder_strategic_bets_r2433 b
    GROUP BY b.status
    ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_breakdown_r2433() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_breakdown_r2433() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_revenue_bets_r2433()
RETURNS TABLE (bet_name text, status text, confidence_pct int, revenue_impact_rupees bigint, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bet_name, b.status, b.confidence_pct, b.revenue_impact_rupees, b.owner_email
    FROM public.founder_strategic_bets_r2433 b
    WHERE b.status NOT IN ('killed')
    ORDER BY b.revenue_impact_rupees DESC
    LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_revenue_bets_r2433() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_revenue_bets_r2433() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_evidence_r2433()
RETURNS TABLE (bet_name text, observed_at timestamptz, evidence_kind text, evidence_md text, confidence_delta_pct int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bet_name, e.observed_at, e.evidence_kind, e.evidence_md, e.confidence_delta_pct
    FROM public.bet_evidence_log_r2433 e
    JOIN public.founder_strategic_bets_r2433 b ON b.id = e.bet_id
    WHERE e.observed_at >= now() - interval '30 days'
    ORDER BY e.observed_at DESC
    LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_evidence_r2433() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_evidence_r2433() TO authenticated;

CREATE OR REPLACE FUNCTION public.overdue_reviews_r2433()
RETURNS TABLE (bet_name text, status text, owner_email text, next_review_at timestamptz, days_overdue int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bet_name, b.status, b.owner_email, b.next_review_at,
           GREATEST(0, EXTRACT(day FROM (now() - b.next_review_at))::int) AS days_overdue
    FROM public.founder_strategic_bets_r2433 b
    WHERE b.next_review_at IS NOT NULL
      AND b.next_review_at < now()
      AND b.status NOT IN ('killed','shipped')
    ORDER BY b.next_review_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.overdue_reviews_r2433() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_reviews_r2433() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_confidence_change_r2433()
RETURNS TABLE (bet_name text, net_delta_pct bigint, supporting_count bigint, refuting_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bet_name,
           COALESCE(SUM(e.confidence_delta_pct),0)::bigint AS net_delta_pct,
           COUNT(*) FILTER (WHERE e.evidence_kind = 'supporting')::bigint AS supporting_count,
           COUNT(*) FILTER (WHERE e.evidence_kind = 'refuting')::bigint AS refuting_count
    FROM public.founder_strategic_bets_r2433 b
    LEFT JOIN public.bet_evidence_log_r2433 e
      ON e.bet_id = b.id AND e.observed_at >= now() - interval '7 days'
    GROUP BY b.bet_name
    ORDER BY net_delta_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_confidence_change_r2433() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_confidence_change_r2433() TO authenticated;
