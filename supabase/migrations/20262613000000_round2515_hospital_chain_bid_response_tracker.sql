-- Round 2515: Hospital Chain Bid Response Tracker
-- Tracks our bids on hospital chain tenders, technical/commercial scoring,
-- competitor analysis, our position, and decisions.

-- ============================================================
-- TABLE 1: chain bids
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chain_bids_r2515 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id),
  tender_external_ref text NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  bid_amount_rupees bigint NOT NULL DEFAULT 0,
  technical_score numeric NOT NULL DEFAULT 0,
  commercial_score numeric NOT NULL DEFAULT 0,
  competitor_count int NOT NULL DEFAULT 0,
  our_position text NOT NULL CHECK (our_position IN ('leader','second','third','other','lost')),
  decision text NOT NULL CHECK (decision IN ('won','lost','postponed','withdrawn','pending')),
  decision_at timestamptz,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cb_r2515_chain ON public.chain_bids_r2515(chain_name);
CREATE INDEX IF NOT EXISTS idx_cb_r2515_submitted ON public.chain_bids_r2515(submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_cb_r2515_decision ON public.chain_bids_r2515(decision);
CREATE INDEX IF NOT EXISTS idx_cb_r2515_position ON public.chain_bids_r2515(our_position);

ALTER TABLE public.chain_bids_r2515 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_bids_r2515;
CREATE POLICY founder_all ON public.chain_bids_r2515
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE 2: competitor analysis per bid
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chain_bid_competitor_analysis_r2515 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bid_id uuid NOT NULL REFERENCES public.chain_bids_r2515(id) ON DELETE CASCADE,
  competitor_name text NOT NULL,
  competitor_bid_rupees bigint NOT NULL DEFAULT 0,
  competitor_position int NOT NULL DEFAULT 0,
  strengths_md text,
  weaknesses_md text,
  our_counter_strategy_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cbca_r2515_bid ON public.chain_bid_competitor_analysis_r2515(bid_id);
CREATE INDEX IF NOT EXISTS idx_cbca_r2515_competitor ON public.chain_bid_competitor_analysis_r2515(competitor_name);

ALTER TABLE public.chain_bid_competitor_analysis_r2515 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_bid_competitor_analysis_r2515;
CREATE POLICY founder_all ON public.chain_bid_competitor_analysis_r2515
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEEDS
-- ============================================================
WITH bid_a AS (
  INSERT INTO public.chain_bids_r2515
    (chain_name, hospital_user_id, tender_external_ref, submitted_at, bid_amount_rupees,
     technical_score, commercial_score, competitor_count, our_position, decision,
     decision_at, owner_email, notes)
  VALUES
    ('Apollo Hospitals', NULL, 'APL-TND-2026-0431', '2026-05-12'::timestamptz, 4800000,
     86.5, 78.2, 4, 'leader', 'won',
     '2026-06-04'::timestamptz, 'sales1@equipseva.in',
     'Won on technical strength; commercial close to L2.')
  RETURNING id
), bid_b AS (
  INSERT INTO public.chain_bids_r2515
    (chain_name, hospital_user_id, tender_external_ref, submitted_at, bid_amount_rupees,
     technical_score, commercial_score, competitor_count, our_position, decision,
     decision_at, owner_email, notes)
  VALUES
    ('Manipal Hospitals', NULL, 'MNP-RFQ-2026-117', '2026-05-22'::timestamptz, 2300000,
     74.0, 81.4, 3, 'second', 'lost',
     '2026-06-10'::timestamptz, 'sales2@equipseva.in',
     'Lost on technical sub-score 3.2 (calibration history).')
  RETURNING id
), bid_c AS (
  INSERT INTO public.chain_bids_r2515
    (chain_name, hospital_user_id, tender_external_ref, submitted_at, bid_amount_rupees,
     technical_score, commercial_score, competitor_count, our_position, decision,
     decision_at, owner_email, notes)
  VALUES
    ('Yashoda Hospitals', NULL, 'YSH-TND-2026-088', '2026-06-01'::timestamptz, 5600000,
     82.0, 76.5, 5, 'leader', 'pending',
     NULL, 'sales1@equipseva.in',
     'Awaiting purchase committee minutes.')
  RETURNING id
), bid_d AS (
  INSERT INTO public.chain_bids_r2515
    (chain_name, hospital_user_id, tender_external_ref, submitted_at, bid_amount_rupees,
     technical_score, commercial_score, competitor_count, our_position, decision,
     decision_at, owner_email, notes)
  VALUES
    ('KIMS Hospitals', NULL, 'KIMS-RFP-2026-019', '2026-06-08'::timestamptz, 3100000,
     79.5, 80.0, 2, 'second', 'postponed',
     '2026-06-19'::timestamptz, 'founder@equipseva.in',
     'Postponed by hospital to Q3 budget cycle.')
  RETURNING id
), bid_e AS (
  INSERT INTO public.chain_bids_r2515
    (chain_name, hospital_user_id, tender_external_ref, submitted_at, bid_amount_rupees,
     technical_score, commercial_score, competitor_count, our_position, decision,
     decision_at, owner_email, notes)
  VALUES
    ('Care Hospitals', NULL, 'CARE-TND-2026-205', '2026-06-15'::timestamptz, 1800000,
     69.0, 84.0, 4, 'third', 'withdrawn',
     '2026-06-18'::timestamptz, 'sales2@equipseva.in',
     'Withdrew after spec mismatch surfaced.')
  RETURNING id
)
INSERT INTO public.chain_bid_competitor_analysis_r2515
  (bid_id, competitor_name, competitor_bid_rupees, competitor_position,
   strengths_md, weaknesses_md, our_counter_strategy_md, notes)
SELECT bid_a.id, 'MedServ Solutions', 4650000, 2,
       '- Strong commercial pricing\n- National service footprint',
       '- Weak calibration audit trail\n- Slower SLA response',
       '- Lead with audit trail evidence pack\n- Quote 4-hour SLA guarantee',
       'Closest L2; lost technical by 3 points.'
FROM bid_a
UNION ALL
SELECT bid_b.id, 'MedServ Solutions', 2150000, 1,
       '- Lower bid\n- Existing rate contract',
       '- Limited spare parts depth',
       '- Highlight bonded parts pipeline\n- Show 99.2% first-visit-fix',
       'Beat us on commercial; technical gap closed in v2 proposal.'
FROM bid_b
UNION ALL
SELECT bid_c.id, 'HealthAxis Bio', 5750000, 2,
       '- Premium brand pull\n- OEM tie-ins',
       '- 14-day average SLA\n- High rate card',
       '- Position 4-hour SLA + ladder pricing',
       'Aggressive pre-bid lobbying observed.'
FROM bid_c
UNION ALL
SELECT bid_d.id, 'BioPharm Services', 2950000, 1,
       '- Local Hyderabad presence\n- Lower mobilisation cost',
       '- No NABH alignment',
       '- Lead with NABH-aligned protocol bundle',
       'Postponement could re-open; keep relationship warm.'
FROM bid_d
UNION ALL
SELECT bid_e.id, 'TechMed Equip', 1620000, 1,
       '- Aggressive list price\n- Direct sub-distributor',
       '- Poor PMS uptime history',
       '- Stay disengaged this cycle; rebid post-spec rewrite',
       'Spec mismatch killed all responsive bids.'
FROM bid_e;

-- ============================================================
-- RPCs
-- ============================================================

-- 1) list_bids_r2515
CREATE OR REPLACE FUNCTION public.list_bids_r2515()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_user_id uuid,
  tender_external_ref text,
  submitted_at timestamptz,
  bid_amount_rupees bigint,
  technical_score numeric,
  commercial_score numeric,
  competitor_count int,
  our_position text,
  decision text,
  decision_at timestamptz,
  owner_email text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.chain_name, b.hospital_user_id, b.tender_external_ref, b.submitted_at,
           b.bid_amount_rupees, b.technical_score, b.commercial_score, b.competitor_count,
           b.our_position, b.decision, b.decision_at, b.owner_email, b.notes
    FROM public.chain_bids_r2515 b
    ORDER BY b.submitted_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_bids_r2515() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bids_r2515() TO authenticated;

-- 2) list_competitor_analysis_r2515
CREATE OR REPLACE FUNCTION public.list_competitor_analysis_r2515()
RETURNS TABLE (
  id uuid,
  bid_id uuid,
  chain_name text,
  tender_external_ref text,
  competitor_name text,
  competitor_bid_rupees bigint,
  competitor_position int,
  strengths_md text,
  weaknesses_md text,
  our_counter_strategy_md text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.bid_id, b.chain_name, b.tender_external_ref,
           a.competitor_name, a.competitor_bid_rupees, a.competitor_position,
           a.strengths_md, a.weaknesses_md, a.our_counter_strategy_md, a.notes
    FROM public.chain_bid_competitor_analysis_r2515 a
    JOIN public.chain_bids_r2515 b ON b.id = a.bid_id
    ORDER BY b.submitted_at DESC, a.competitor_position ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_competitor_analysis_r2515() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_competitor_analysis_r2515() TO authenticated;

-- 3) top_value_bids_r2515
CREATE OR REPLACE FUNCTION public.top_value_bids_r2515()
RETURNS TABLE (
  id uuid,
  chain_name text,
  tender_external_ref text,
  bid_amount_rupees bigint,
  our_position text,
  decision text,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.chain_name, b.tender_external_ref, b.bid_amount_rupees,
           b.our_position, b.decision, b.owner_email
    FROM public.chain_bids_r2515 b
    ORDER BY b.bid_amount_rupees DESC
    LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_value_bids_r2515() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_bids_r2515() TO authenticated;

-- 4) decision_funnel_r2515
CREATE OR REPLACE FUNCTION public.decision_funnel_r2515()
RETURNS TABLE (
  decision text,
  bid_count bigint,
  total_value_rupees bigint,
  avg_technical_score numeric,
  avg_commercial_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.decision,
           COUNT(*)::bigint AS bid_count,
           SUM(b.bid_amount_rupees)::bigint AS total_value_rupees,
           ROUND(AVG(b.technical_score)::numeric, 1) AS avg_technical_score,
           ROUND(AVG(b.commercial_score)::numeric, 1) AS avg_commercial_score
    FROM public.chain_bids_r2515 b
    GROUP BY b.decision
    ORDER BY total_value_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_funnel_r2515() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_funnel_r2515() TO authenticated;

-- 5) our_position_distribution_r2515
CREATE OR REPLACE FUNCTION public.our_position_distribution_r2515()
RETURNS TABLE (
  our_position text,
  bid_count bigint,
  total_value_rupees bigint,
  won_count bigint,
  lost_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.our_position,
           COUNT(*)::bigint AS bid_count,
           SUM(b.bid_amount_rupees)::bigint AS total_value_rupees,
           COUNT(*) FILTER (WHERE b.decision = 'won')::bigint AS won_count,
           COUNT(*) FILTER (WHERE b.decision = 'lost')::bigint AS lost_count
    FROM public.chain_bids_r2515 b
    GROUP BY b.our_position
    ORDER BY bid_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.our_position_distribution_r2515() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.our_position_distribution_r2515() TO authenticated;

-- 6) monthly_bid_trend_r2515
CREATE OR REPLACE FUNCTION public.monthly_bid_trend_r2515()
RETURNS TABLE (
  month_start date,
  bid_count bigint,
  total_value_rupees bigint,
  won_value_rupees bigint,
  lost_value_rupees bigint,
  pending_value_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', b.submitted_at)::date AS month_start,
           COUNT(*)::bigint AS bid_count,
           SUM(b.bid_amount_rupees)::bigint AS total_value_rupees,
           COALESCE(SUM(b.bid_amount_rupees) FILTER (WHERE b.decision = 'won'), 0)::bigint AS won_value_rupees,
           COALESCE(SUM(b.bid_amount_rupees) FILTER (WHERE b.decision = 'lost'), 0)::bigint AS lost_value_rupees,
           COALESCE(SUM(b.bid_amount_rupees) FILTER (WHERE b.decision = 'pending'), 0)::bigint AS pending_value_rupees
    FROM public.chain_bids_r2515 b
    GROUP BY date_trunc('month', b.submitted_at)
    ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_bid_trend_r2515() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_bid_trend_r2515() TO authenticated;

-- 7) top_competitor_threats_r2515
CREATE OR REPLACE FUNCTION public.top_competitor_threats_r2515()
RETURNS TABLE (
  competitor_name text,
  appearances bigint,
  avg_position numeric,
  total_competitor_value_rupees bigint,
  l1_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.competitor_name,
           COUNT(*)::bigint AS appearances,
           ROUND(AVG(a.competitor_position)::numeric, 2) AS avg_position,
           SUM(a.competitor_bid_rupees)::bigint AS total_competitor_value_rupees,
           COUNT(*) FILTER (WHERE a.competitor_position = 1)::bigint AS l1_count
    FROM public.chain_bid_competitor_analysis_r2515 a
    GROUP BY a.competitor_name
    ORDER BY l1_count DESC, appearances DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_competitor_threats_r2515() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_competitor_threats_r2515() TO authenticated;
