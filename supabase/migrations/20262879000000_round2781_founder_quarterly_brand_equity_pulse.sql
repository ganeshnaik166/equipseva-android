BEGIN;

-- Round 2781 — Founder Quarterly Brand Equity Pulse
-- Tables: segments × awareness × consideration × NPS × signal × campaign × shift

-- ============================================================
-- Table 1: brand_equity_segments_r2781
-- ============================================================
CREATE TABLE IF NOT EXISTS public.brand_equity_segments_r2781 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  segment text NOT NULL,
  region text NOT NULL,
  sample_size int NOT NULL,
  aided_awareness_pct numeric(5,2) NOT NULL,
  unaided_awareness_pct numeric(5,2) NOT NULL,
  consideration_pct numeric(5,2) NOT NULL,
  preference_pct numeric(5,2) NOT NULL,
  nps_score int NOT NULL,
  prior_nps_score int NOT NULL,
  signal_strength text NOT NULL CHECK (signal_strength IN ('weak','steady','rising','surging')),
  campaign_tag text NOT NULL,
  qoq_shift_pct numeric(5,2) NOT NULL,
  notes text,
  surveyed_at date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.brand_equity_segments_r2781 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.brand_equity_segments_r2781 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.brand_equity_segments_r2781
  (quarter, segment, region, sample_size, aided_awareness_pct, unaided_awareness_pct, consideration_pct, preference_pct, nps_score, prior_nps_score, signal_strength, campaign_tag, qoq_shift_pct, notes, surveyed_at)
VALUES
  ('Q2-2026','Tier-1 Hospitals','South',412,78.40,42.10,61.80,38.20,54,46,'surging','south-hospital-campaign-q2',8.40,'Strong NPS lift after AMC tier overhaul','2026-06-10'::date),
  ('Q2-2026','Tier-2 Clinics','West',308,64.20,28.50,48.30,24.10,41,38,'rising','clinic-roadshow-pune-q2',3.20,'Roadshow drove unaided recall','2026-06-12'::date),
  ('Q2-2026','Super-Specialty','North',186,82.10,58.40,72.40,52.80,62,54,'surging','onco-cardio-pilot-q2',7.80,'Onco + cardio pilot in Delhi NCR moved preference','2026-06-08'::date),
  ('Q2-2026','Dental Chains','East',144,52.30,18.60,32.10,16.40,28,32,'weak','dental-direct-mailer-q2',-4.10,'Direct mailer underperformed vs control','2026-06-15'::date),
  ('Q2-2026','Diagnostic Labs','South',221,71.40,38.20,55.60,30.40,48,44,'rising','lab-amc-bundle-q2',4.10,'AMC bundle pricing improved consideration','2026-06-11'::date),
  ('Q1-2026','Tier-1 Hospitals','South',398,72.10,36.40,57.20,33.10,46,40,'steady','south-hospital-baseline-q1',2.10,'Baseline pre-overhaul','2026-03-15'::date);

-- ============================================================
-- Table 2: brand_equity_campaigns_r2781
-- ============================================================
CREATE TABLE IF NOT EXISTS public.brand_equity_campaigns_r2781 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_tag text NOT NULL UNIQUE,
  campaign_name text NOT NULL,
  quarter text NOT NULL,
  channel text NOT NULL,
  spend_rupees bigint NOT NULL,
  impressions_count bigint NOT NULL,
  reach_count bigint NOT NULL,
  awareness_lift_pct numeric(5,2) NOT NULL,
  consideration_lift_pct numeric(5,2) NOT NULL,
  nps_delta int NOT NULL,
  signal_label text NOT NULL CHECK (signal_label IN ('underperform','par','overperform','breakout')),
  shift_verdict text NOT NULL CHECK (shift_verdict IN ('cut','hold','scale','double-down')),
  started_at date NOT NULL,
  ended_at date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.brand_equity_campaigns_r2781 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.brand_equity_campaigns_r2781 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.brand_equity_campaigns_r2781
  (campaign_tag, campaign_name, quarter, channel, spend_rupees, impressions_count, reach_count, awareness_lift_pct, consideration_lift_pct, nps_delta, signal_label, shift_verdict, started_at, ended_at)
VALUES
  ('south-hospital-campaign-q2','South Hospital Showcase','Q2-2026','field+digital',1840000,4200000,860000,6.30,4.60,8,'breakout','double-down','2026-04-15'::date,'2026-06-15'::date),
  ('clinic-roadshow-pune-q2','Pune Clinic Roadshow','Q2-2026','field',640000,180000,42000,5.70,3.20,3,'overperform','scale','2026-05-01'::date,'2026-06-10'::date),
  ('onco-cardio-pilot-q2','Onco-Cardio Pilot Delhi NCR','Q2-2026','field+content',2100000,860000,120000,9.70,8.40,8,'breakout','double-down','2026-04-20'::date,'2026-06-20'::date),
  ('dental-direct-mailer-q2','Dental Direct Mailer','Q2-2026','direct-mail',380000,42000,42000,1.20,0.40,-4,'underperform','cut','2026-04-10'::date,'2026-05-30'::date),
  ('lab-amc-bundle-q2','Lab AMC Bundle Push','Q2-2026','inside-sales',520000,68000,18000,4.40,3.80,4,'overperform','scale','2026-04-25'::date,'2026-06-18'::date),
  ('south-hospital-baseline-q1','South Hospital Baseline','Q1-2026','field',1620000,3800000,780000,3.10,2.20,2,'par','hold','2026-01-15'::date,'2026-03-15'::date);

-- ============================================================
-- RPC 1: list_segments
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_list_segments_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_list_segments_r2781()
RETURNS TABLE (
  id uuid,
  quarter text,
  segment text,
  region text,
  sample_size int,
  aided_awareness_pct numeric,
  unaided_awareness_pct numeric,
  consideration_pct numeric,
  preference_pct numeric,
  nps_score int,
  prior_nps_score int,
  nps_delta int,
  signal_strength text,
  campaign_tag text,
  qoq_shift_pct numeric,
  surveyed_at date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.quarter, s.segment, s.region, s.sample_size,
           s.aided_awareness_pct, s.unaided_awareness_pct,
           s.consideration_pct, s.preference_pct,
           s.nps_score, s.prior_nps_score,
           (s.nps_score - s.prior_nps_score)::int AS nps_delta,
           s.signal_strength, s.campaign_tag, s.qoq_shift_pct, s.surveyed_at
    FROM public.brand_equity_segments_r2781 s
    ORDER BY s.surveyed_at DESC, s.segment ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_list_segments_r2781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_list_segments_r2781() TO authenticated;

-- ============================================================
-- RPC 2: list_campaigns
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_list_campaigns_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_list_campaigns_r2781()
RETURNS TABLE (
  id uuid,
  campaign_tag text,
  campaign_name text,
  quarter text,
  channel text,
  spend_rupees bigint,
  impressions_count bigint,
  reach_count bigint,
  awareness_lift_pct numeric,
  consideration_lift_pct numeric,
  nps_delta int,
  signal_label text,
  shift_verdict text,
  cost_per_reach numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.campaign_tag, c.campaign_name, c.quarter, c.channel,
           c.spend_rupees, c.impressions_count, c.reach_count,
           c.awareness_lift_pct, c.consideration_lift_pct, c.nps_delta,
           c.signal_label, c.shift_verdict,
           CASE WHEN c.reach_count > 0
                THEN ROUND((c.spend_rupees::numeric / c.reach_count::numeric), 2)
                ELSE 0::numeric END AS cost_per_reach
    FROM public.brand_equity_campaigns_r2781 c
    ORDER BY c.spend_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_list_campaigns_r2781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_list_campaigns_r2781() TO authenticated;

-- ============================================================
-- RPC 3: pulse_kpis
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_pulse_kpis_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_pulse_kpis_r2781()
RETURNS TABLE (
  segment_count bigint,
  campaign_count bigint,
  avg_aided_awareness numeric,
  avg_unaided_awareness numeric,
  avg_consideration numeric,
  avg_preference numeric,
  avg_nps numeric,
  avg_nps_delta numeric,
  total_spend_rupees bigint,
  avg_qoq_shift numeric,
  surging_segments bigint,
  weak_segments bigint
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
      (SELECT count(*) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT count(*) FROM public.brand_equity_campaigns_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(aided_awareness_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(unaided_awareness_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(consideration_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(preference_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(nps_score),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(nps_score - prior_nps_score),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(SUM(spend_rupees),0) FROM public.brand_equity_campaigns_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(qoq_shift_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT count(*) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026' AND signal_strength = 'surging'),
      (SELECT count(*) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026' AND signal_strength = 'weak');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_pulse_kpis_r2781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_pulse_kpis_r2781() TO authenticated;

-- ============================================================
-- RPC 4: signal_mix
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_signal_mix_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_signal_mix_r2781()
RETURNS TABLE (
  signal_strength text,
  segment_count bigint,
  avg_nps numeric,
  avg_shift numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.signal_strength,
           count(*)::bigint,
           ROUND(AVG(s.nps_score),2),
           ROUND(AVG(s.qoq_shift_pct),2)
    FROM public.brand_equity_segments_r2781 s
    WHERE s.quarter = 'Q2-2026'
    GROUP BY s.signal_strength
    ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_signal_mix_r2781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_signal_mix_r2781() TO authenticated;

-- ============================================================
-- RPC 5: shift_verdicts
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_shift_verdicts_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_shift_verdicts_r2781()
RETURNS TABLE (
  shift_verdict text,
  campaign_count bigint,
  total_spend bigint,
  avg_awareness_lift numeric,
  avg_nps_delta numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.shift_verdict,
           count(*)::bigint,
           SUM(c.spend_rupees)::bigint,
           ROUND(AVG(c.awareness_lift_pct),2),
           ROUND(AVG(c.nps_delta),2)
    FROM public.brand_equity_campaigns_r2781 c
    GROUP BY c.shift_verdict
    ORDER BY SUM(c.spend_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_shift_verdicts_r2781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_shift_verdicts_r2781() TO authenticated;

-- ============================================================
-- RPC 6: nps_movers
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_nps_movers_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_nps_movers_r2781()
RETURNS TABLE (
  segment text,
  region text,
  nps_score int,
  prior_nps_score int,
  nps_delta int,
  qoq_shift_pct numeric,
  signal_strength text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.segment, s.region, s.nps_score, s.prior_nps_score,
           (s.nps_score - s.prior_nps_score)::int AS nps_delta,
           s.qoq_shift_pct, s.signal_strength
    FROM public.brand_equity_segments_r2781 s
    WHERE s.quarter = 'Q2-2026'
    ORDER BY (s.nps_score - s.prior_nps_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_nps_movers_r2781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_nps_movers_r2781() TO authenticated;

-- ============================================================
-- RPC 7: efficiency_leaderboard
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_efficiency_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_efficiency_r2781()
RETURNS TABLE (
  campaign_name text,
  channel text,
  spend_rupees bigint,
  awareness_lift_pct numeric,
  cost_per_awareness_point numeric,
  nps_delta int,
  shift_verdict text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.campaign_name, c.channel, c.spend_rupees, c.awareness_lift_pct,
           CASE WHEN c.awareness_lift_pct > 0
                THEN ROUND(c.spend_rupees::numeric / c.awareness_lift_pct, 2)
                ELSE NULL::numeric END AS cost_per_awareness_point,
           c.nps_delta, c.shift_verdict
    FROM public.brand_equity_campaigns_r2781 c
    WHERE c.quarter = 'Q2-2026'
    ORDER BY (CASE WHEN c.awareness_lift_pct > 0 THEN c.spend_rupees::numeric / c.awareness_lift_pct ELSE 999999999 END) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_efficiency_r2781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_efficiency_r2781() TO authenticated;

-- ============================================================
-- RPC 8: log_shift_decision
-- ============================================================
DROP FUNCTION IF EXISTS public.brand_equity_log_shift_r2781(text, text);
CREATE OR REPLACE FUNCTION public.brand_equity_log_shift_r2781(p_campaign_tag text, p_new_verdict text)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_verdict NOT IN ('cut','hold','scale','double-down') THEN
    RAISE EXCEPTION 'invalid_verdict';
  END IF;
  UPDATE public.brand_equity_campaigns_r2781
     SET shift_verdict = p_new_verdict
   WHERE campaign_tag = p_campaign_tag
   RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'campaign_not_found'; END IF;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.brand_equity_log_shift_r2781(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.brand_equity_log_shift_r2781(text, text) TO authenticated;

COMMIT;
