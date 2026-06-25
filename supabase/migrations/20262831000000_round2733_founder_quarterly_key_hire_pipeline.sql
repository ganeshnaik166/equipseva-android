BEGIN;

-- ============================================================================
-- Round 2733: Founder Quarterly Key Hire Pipeline
-- role x candidate x stage x signal x offer x accept x decision impact
-- ============================================================================

-- Table 1: candidate pipeline rows
CREATE TABLE IF NOT EXISTS founder_key_hire_pipeline_r2733 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  role_title text NOT NULL,
  role_band text NOT NULL CHECK (role_band IN ('exec','senior','mid','specialist')),
  candidate_name text NOT NULL,
  candidate_source text NOT NULL CHECK (candidate_source IN ('inbound','outbound','referral','agency')),
  stage text NOT NULL CHECK (stage IN ('sourced','screened','onsite','offer','accepted','declined','withdrawn')),
  signal_score int NOT NULL CHECK (signal_score BETWEEN 0 AND 100),
  offer_amount_rupees bigint,
  accepted boolean NOT NULL DEFAULT false,
  decision_impact text NOT NULL CHECK (decision_impact IN ('critical','high','medium','low')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_key_hire_pipeline_r2733 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_key_hire_pipeline_r2733;
CREATE POLICY founder_all ON founder_key_hire_pipeline_r2733 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: stage transition events
CREATE TABLE IF NOT EXISTS founder_key_hire_stage_events_r2733 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES founder_key_hire_pipeline_r2733(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('stage_change','signal_update','offer_extended','offer_accepted','offer_declined','withdrawn')),
  from_stage text,
  to_stage text,
  signal_delta int,
  event_at timestamptz NOT NULL DEFAULT now(),
  note text
);

ALTER TABLE founder_key_hire_stage_events_r2733 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_key_hire_stage_events_r2733;
CREATE POLICY founder_all ON founder_key_hire_stage_events_r2733 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds: pipeline
INSERT INTO founder_key_hire_pipeline_r2733 (quarter, role_title, role_band, candidate_name, candidate_source, stage, signal_score, offer_amount_rupees, accepted, decision_impact, notes, created_at) VALUES
  ('Q2-2026', 'VP Engineering', 'exec', 'Aarav Mehta', 'referral', 'accepted', 92, 9500000, true, 'critical', 'ex-Razorpay platform lead', '2026-06-05 09:00:00+05:30'::timestamptz),
  ('Q2-2026', 'Head of Hospital Sales', 'exec', 'Sneha Iyer', 'outbound', 'offer', 88, 7200000, false, 'critical', 'Apollo regional director', '2026-06-10 10:30:00+05:30'::timestamptz),
  ('Q2-2026', 'Staff SRE', 'senior', 'Karan Bhatia', 'inbound', 'onsite', 81, NULL, false, 'high', 'strong K8s + on-call track', '2026-06-12 14:00:00+05:30'::timestamptz),
  ('Q2-2026', 'Senior Field Ops Manager Bengaluru', 'senior', 'Priya Rao', 'agency', 'screened', 74, NULL, false, 'high', 'ran 60-engineer team at Urban Co', '2026-06-15 11:00:00+05:30'::timestamptz),
  ('Q2-2026', 'Compliance Lead DPDP', 'mid', 'Vikram Sundaram', 'referral', 'declined', 70, 4200000, false, 'medium', 'declined for counter-offer', '2026-06-08 16:00:00+05:30'::timestamptz),
  ('Q2-2026', 'BD AMC South', 'mid', 'Ritu Khanna', 'outbound', 'sourced', 65, NULL, false, 'medium', 'sourced via LinkedIn', '2026-06-18 13:00:00+05:30'::timestamptz),
  ('Q2-2026', 'Senior Android Engineer', 'senior', 'Mohammed Faizal', 'inbound', 'withdrawn', 78, NULL, false, 'high', 'candidate withdrew citing relocation', '2026-06-14 10:00:00+05:30'::timestamptz);

-- Seeds: events (link by candidate_name lookup)
INSERT INTO founder_key_hire_stage_events_r2733 (pipeline_id, event_type, from_stage, to_stage, signal_delta, event_at, note)
SELECT id, 'offer_accepted', 'offer', 'accepted', 4, '2026-06-20 12:00:00+05:30'::timestamptz, 'signed offer letter'
FROM founder_key_hire_pipeline_r2733 WHERE candidate_name = 'Aarav Mehta';

INSERT INTO founder_key_hire_stage_events_r2733 (pipeline_id, event_type, from_stage, to_stage, signal_delta, event_at, note)
SELECT id, 'offer_extended', 'onsite', 'offer', 2, '2026-06-19 15:00:00+05:30'::timestamptz, 'offer sent, 7-day window'
FROM founder_key_hire_pipeline_r2733 WHERE candidate_name = 'Sneha Iyer';

INSERT INTO founder_key_hire_stage_events_r2733 (pipeline_id, event_type, from_stage, to_stage, signal_delta, event_at, note)
SELECT id, 'stage_change', 'screened', 'onsite', 5, '2026-06-17 11:00:00+05:30'::timestamptz, 'system-design round cleared'
FROM founder_key_hire_pipeline_r2733 WHERE candidate_name = 'Karan Bhatia';

INSERT INTO founder_key_hire_stage_events_r2733 (pipeline_id, event_type, from_stage, to_stage, signal_delta, event_at, note)
SELECT id, 'signal_update', 'screened', 'screened', 3, '2026-06-16 10:00:00+05:30'::timestamptz, 'reference call strong positive'
FROM founder_key_hire_pipeline_r2733 WHERE candidate_name = 'Priya Rao';

INSERT INTO founder_key_hire_stage_events_r2733 (pipeline_id, event_type, from_stage, to_stage, signal_delta, event_at, note)
SELECT id, 'offer_declined', 'offer', 'declined', -10, '2026-06-13 18:00:00+05:30'::timestamptz, 'counter-offer from current employer'
FROM founder_key_hire_pipeline_r2733 WHERE candidate_name = 'Vikram Sundaram';

INSERT INTO founder_key_hire_stage_events_r2733 (pipeline_id, event_type, from_stage, to_stage, signal_delta, event_at, note)
SELECT id, 'withdrawn', 'onsite', 'withdrawn', -5, '2026-06-14 17:00:00+05:30'::timestamptz, 'relocation friction'
FROM founder_key_hire_pipeline_r2733 WHERE candidate_name = 'Mohammed Faizal';

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2733_kpis();
CREATE OR REPLACE FUNCTION founder_r2733_kpis()
RETURNS TABLE (
  total_candidates int,
  in_flight int,
  offers_extended int,
  offers_accepted int,
  offers_declined int,
  avg_signal numeric,
  critical_roles_open int,
  total_offer_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE stage IN ('sourced','screened','onsite','offer'))::int,
    COUNT(*) FILTER (WHERE stage = 'offer' OR accepted = true OR stage = 'declined')::int,
    COUNT(*) FILTER (WHERE accepted = true)::int,
    COUNT(*) FILTER (WHERE stage = 'declined')::int,
    ROUND(AVG(signal_score)::numeric, 1),
    COUNT(*) FILTER (WHERE decision_impact = 'critical' AND stage NOT IN ('accepted','declined','withdrawn'))::int,
    COALESCE(SUM(offer_amount_rupees), 0)::bigint
  FROM founder_key_hire_pipeline_r2733;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2733_pipeline();
CREATE OR REPLACE FUNCTION founder_r2733_pipeline()
RETURNS TABLE (
  id uuid,
  quarter text,
  role_title text,
  role_band text,
  candidate_name text,
  candidate_source text,
  stage text,
  signal_score int,
  offer_amount_rupees bigint,
  accepted boolean,
  decision_impact text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.quarter, p.role_title, p.role_band, p.candidate_name, p.candidate_source,
         p.stage, p.signal_score, p.offer_amount_rupees, p.accepted, p.decision_impact, p.notes
  FROM founder_key_hire_pipeline_r2733 p
  ORDER BY
    CASE p.decision_impact WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    p.signal_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_pipeline() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2733_stage_funnel();
CREATE OR REPLACE FUNCTION founder_r2733_stage_funnel()
RETURNS TABLE (
  stage text,
  candidate_count int,
  avg_signal numeric,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM founder_key_hire_pipeline_r2733;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT p.stage,
         COUNT(*)::int,
         ROUND(AVG(p.signal_score)::numeric, 1),
         ROUND((COUNT(*)::numeric / v_total) * 100, 1)
  FROM founder_key_hire_pipeline_r2733 p
  GROUP BY p.stage
  ORDER BY
    CASE p.stage
      WHEN 'sourced' THEN 1
      WHEN 'screened' THEN 2
      WHEN 'onsite' THEN 3
      WHEN 'offer' THEN 4
      WHEN 'accepted' THEN 5
      WHEN 'declined' THEN 6
      WHEN 'withdrawn' THEN 7
    END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_stage_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_stage_funnel() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2733_source_mix();
CREATE OR REPLACE FUNCTION founder_r2733_source_mix()
RETURNS TABLE (
  candidate_source text,
  candidates int,
  accepted_count int,
  acceptance_rate numeric,
  avg_signal numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.candidate_source,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.accepted)::int,
         ROUND((COUNT(*) FILTER (WHERE p.accepted)::numeric / NULLIF(COUNT(*),0)) * 100, 1),
         ROUND(AVG(p.signal_score)::numeric, 1)
  FROM founder_key_hire_pipeline_r2733 p
  GROUP BY p.candidate_source
  ORDER BY candidates DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_source_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_source_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2733_impact_breakdown();
CREATE OR REPLACE FUNCTION founder_r2733_impact_breakdown()
RETURNS TABLE (
  decision_impact text,
  candidates int,
  in_flight int,
  closed_won int,
  closed_lost int,
  total_offer_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.decision_impact,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.stage IN ('sourced','screened','onsite','offer'))::int,
         COUNT(*) FILTER (WHERE p.accepted)::int,
         COUNT(*) FILTER (WHERE p.stage IN ('declined','withdrawn'))::int,
         COALESCE(SUM(p.offer_amount_rupees), 0)::bigint
  FROM founder_key_hire_pipeline_r2733 p
  GROUP BY p.decision_impact
  ORDER BY
    CASE p.decision_impact WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_impact_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_impact_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2733_recent_events();
CREATE OR REPLACE FUNCTION founder_r2733_recent_events()
RETURNS TABLE (
  candidate_name text,
  role_title text,
  event_type text,
  from_stage text,
  to_stage text,
  signal_delta int,
  event_at timestamptz,
  note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.candidate_name, p.role_title, e.event_type, e.from_stage, e.to_stage,
         e.signal_delta, e.event_at, e.note
  FROM founder_key_hire_stage_events_r2733 e
  JOIN founder_key_hire_pipeline_r2733 p ON p.id = e.pipeline_id
  ORDER BY e.event_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_recent_events() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2733_critical_open();
CREATE OR REPLACE FUNCTION founder_r2733_critical_open()
RETURNS TABLE (
  role_title text,
  candidate_name text,
  stage text,
  signal_score int,
  days_in_pipeline int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.role_title, p.candidate_name, p.stage, p.signal_score,
         EXTRACT(day FROM (now() - p.created_at))::int
  FROM founder_key_hire_pipeline_r2733 p
  WHERE p.decision_impact = 'critical'
    AND p.stage NOT IN ('accepted','declined','withdrawn')
  ORDER BY p.signal_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_critical_open() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_critical_open() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2733_advance_stage(uuid, text, int, text);
CREATE OR REPLACE FUNCTION founder_r2733_advance_stage(p_id uuid, p_to_stage text, p_signal_delta int, p_note text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_from text;
  v_event_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_to_stage NOT IN ('sourced','screened','onsite','offer','accepted','declined','withdrawn') THEN
    RAISE EXCEPTION 'invalid stage %', p_to_stage;
  END IF;
  SELECT stage INTO v_from FROM founder_key_hire_pipeline_r2733 WHERE id = p_id;
  IF v_from IS NULL THEN RAISE EXCEPTION 'candidate not found'; END IF;
  UPDATE founder_key_hire_pipeline_r2733
  SET stage = p_to_stage,
      signal_score = GREATEST(0, LEAST(100, signal_score + COALESCE(p_signal_delta, 0))),
      accepted = (p_to_stage = 'accepted')
  WHERE id = p_id;
  INSERT INTO founder_key_hire_stage_events_r2733 (pipeline_id, event_type, from_stage, to_stage, signal_delta, note)
  VALUES (p_id, 'stage_change', v_from, p_to_stage, COALESCE(p_signal_delta, 0), p_note)
  RETURNING id INTO v_event_id;
  RETURN v_event_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2733_advance_stage(uuid, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2733_advance_stage(uuid, text, int, text) TO authenticated;

COMMIT;
