BEGIN;

-- ============================================================================
-- Round 2853 — Founder Quarterly Strategic Narrative Bench-Marking
-- narrative x peer benchmark x differentiation x tagline x resonance x verdict
-- ============================================================================

CREATE TABLE IF NOT EXISTS strategic_narratives_r2853 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  narrative_theme text NOT NULL,
  tagline text NOT NULL,
  peer_benchmark text NOT NULL,
  differentiation_score numeric(4,2) NOT NULL CHECK (differentiation_score >= 0 AND differentiation_score <= 10),
  resonance_score numeric(4,2) NOT NULL CHECK (resonance_score >= 0 AND resonance_score <= 10),
  market_clarity_score numeric(4,2) NOT NULL CHECK (market_clarity_score >= 0 AND market_clarity_score <= 10),
  verdict text NOT NULL CHECK (verdict IN ('crisp','adequate','muddled','reposition')),
  owner text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE strategic_narratives_r2853 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON strategic_narratives_r2853;
CREATE POLICY founder_all ON strategic_narratives_r2853 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS narrative_resonance_signals_r2853 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  narrative_id uuid NOT NULL REFERENCES strategic_narratives_r2853(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('investor','hospital','engineer','press','partner')),
  audience_segment text NOT NULL,
  signal_kind text NOT NULL CHECK (signal_kind IN ('positive','neutral','negative','mixed')),
  signal_strength numeric(4,2) NOT NULL CHECK (signal_strength >= 0 AND signal_strength <= 10),
  evidence_quote text NOT NULL,
  observed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE narrative_resonance_signals_r2853 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON narrative_resonance_signals_r2853;
CREATE POLICY founder_all ON narrative_resonance_signals_r2853 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seeds
-- ============================================================================

INSERT INTO strategic_narratives_r2853 (quarter, narrative_theme, tagline, peer_benchmark, differentiation_score, resonance_score, market_clarity_score, verdict, owner, recorded_at) VALUES
('Q1-2026','India tier-2 medical equipment OS','The uptime layer for Bharat hospitals','TRIMEDX-style integrated svc, India-native pricing',8.40,7.90,8.10,'crisp','Ganesh','2026-01-31'::timestamptz),
('Q2-2026','Engineer marketplace + AMC pool','One pool, every Class-A device, paid weekly','GE multi-vendor svc, but field-engineer driven',7.80,7.20,7.50,'crisp','Ganesh','2026-04-30'::timestamptz),
('Q3-2026','Founder-led ops console','Software that runs the chain, not just logs it','Asimily/Nuvolo focus on inventory not ops',6.90,6.40,7.10,'adequate','Ganesh','2026-07-31'::timestamptz),
('Q4-2026','Hospital chain bulk discount engine','Group purchasing power, without the GPO middleman','Premier Inc style but SaaS-only',7.60,7.00,6.80,'adequate','Ganesh','2026-10-31'::timestamptz),
('Q1-2027','AI triage + remote diagnostics','Resolve before truck rolls','Sodexo HTM has no AI layer',8.90,8.30,8.50,'crisp','Ganesh','2027-01-31'::timestamptz),
('Q2-2027','International pilot SL/BD/NP','Bharat playbook, exported','None — greenfield in SAARC',5.40,5.20,5.80,'muddled','Ganesh','2027-04-30'::timestamptz);

INSERT INTO narrative_resonance_signals_r2853 (narrative_id, channel, audience_segment, signal_kind, signal_strength, evidence_quote, observed_at)
SELECT id, 'investor', 'Series A India SaaS', 'positive', 8.20, 'finally a vertical SaaS with hardware moat', '2026-02-05'::timestamptz FROM strategic_narratives_r2853 WHERE quarter='Q1-2026'
UNION ALL
SELECT id, 'hospital', 'Tier-2 multi-specialty CEO', 'positive', 7.50, 'we stop calling 6 vendors, just one app', '2026-02-12'::timestamptz FROM strategic_narratives_r2853 WHERE quarter='Q1-2026'
UNION ALL
SELECT id, 'engineer', 'Field engineer 5-10 yrs', 'mixed', 6.80, 'weekly payout is great but jobs are uneven', '2026-05-08'::timestamptz FROM strategic_narratives_r2853 WHERE quarter='Q2-2026'
UNION ALL
SELECT id, 'press', 'YourStory + ET', 'neutral', 5.50, 'interesting but unproven beyond Hyderabad', '2026-08-14'::timestamptz FROM strategic_narratives_r2853 WHERE quarter='Q3-2026'
UNION ALL
SELECT id, 'partner', 'OEM India distributor', 'positive', 7.90, 'AMC pool unlocks devices we never serviced', '2026-11-02'::timestamptz FROM strategic_narratives_r2853 WHERE quarter='Q4-2026'
UNION ALL
SELECT id, 'investor', 'Healthcare-focused Series B', 'positive', 8.80, 'AI triage is the moat — show me the data', '2027-02-09'::timestamptz FROM strategic_narratives_r2853 WHERE quarter='Q1-2027'
UNION ALL
SELECT id, 'hospital', 'SAARC private chain', 'negative', 4.10, 'too India-specific, regulations differ', '2027-05-15'::timestamptz FROM strategic_narratives_r2853 WHERE quarter='Q2-2027';

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS rpc_r2853_narrative_overview();
CREATE OR REPLACE FUNCTION rpc_r2853_narrative_overview()
RETURNS TABLE (quarter text, narrative_theme text, tagline text, verdict text, differentiation_score numeric, resonance_score numeric, market_clarity_score numeric, recorded_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.quarter, n.narrative_theme, n.tagline, n.verdict, n.differentiation_score, n.resonance_score, n.market_clarity_score, n.recorded_at
  FROM strategic_narratives_r2853 n
  ORDER BY n.recorded_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_narrative_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_narrative_overview() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2853_kpi_snapshot();
CREATE OR REPLACE FUNCTION rpc_r2853_kpi_snapshot()
RETURNS TABLE (total_quarters integer, crisp_count integer, muddled_count integer, avg_differentiation numeric, avg_resonance numeric, avg_market_clarity numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE verdict='crisp')::integer,
    COUNT(*) FILTER (WHERE verdict IN ('muddled','reposition'))::integer,
    ROUND(AVG(differentiation_score)::numeric, 2),
    ROUND(AVG(resonance_score)::numeric, 2),
    ROUND(AVG(market_clarity_score)::numeric, 2)
  FROM strategic_narratives_r2853;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_kpi_snapshot() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2853_peer_benchmark_table();
CREATE OR REPLACE FUNCTION rpc_r2853_peer_benchmark_table()
RETURNS TABLE (quarter text, narrative_theme text, peer_benchmark text, differentiation_score numeric, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.quarter, n.narrative_theme, n.peer_benchmark, n.differentiation_score, n.verdict
  FROM strategic_narratives_r2853 n
  ORDER BY n.differentiation_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_peer_benchmark_table() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_peer_benchmark_table() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2853_resonance_by_channel();
CREATE OR REPLACE FUNCTION rpc_r2853_resonance_by_channel()
RETURNS TABLE (channel text, signal_count integer, avg_strength numeric, positive_count integer, negative_count integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.channel,
    COUNT(*)::integer,
    ROUND(AVG(s.signal_strength)::numeric, 2),
    COUNT(*) FILTER (WHERE s.signal_kind='positive')::integer,
    COUNT(*) FILTER (WHERE s.signal_kind='negative')::integer
  FROM narrative_resonance_signals_r2853 s
  GROUP BY s.channel
  ORDER BY AVG(s.signal_strength) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_resonance_by_channel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_resonance_by_channel() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2853_resonance_signals();
CREATE OR REPLACE FUNCTION rpc_r2853_resonance_signals()
RETURNS TABLE (quarter text, channel text, audience_segment text, signal_kind text, signal_strength numeric, evidence_quote text, observed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.quarter, s.channel, s.audience_segment, s.signal_kind, s.signal_strength, s.evidence_quote, s.observed_at
  FROM narrative_resonance_signals_r2853 s
  JOIN strategic_narratives_r2853 n ON n.id = s.narrative_id
  ORDER BY s.observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_resonance_signals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_resonance_signals() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2853_reposition_candidates();
CREATE OR REPLACE FUNCTION rpc_r2853_reposition_candidates()
RETURNS TABLE (quarter text, narrative_theme text, tagline text, resonance_score numeric, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.quarter, n.narrative_theme, n.tagline, n.resonance_score, n.verdict
  FROM strategic_narratives_r2853 n
  WHERE n.verdict IN ('muddled','reposition','adequate')
  ORDER BY n.resonance_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_reposition_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_reposition_candidates() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2853_tagline_leaderboard();
CREATE OR REPLACE FUNCTION rpc_r2853_tagline_leaderboard()
RETURNS TABLE (quarter text, tagline text, combined_score numeric, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.quarter,
    n.tagline,
    ROUND(((n.differentiation_score + n.resonance_score + n.market_clarity_score) / 3.0)::numeric, 2) AS combined_score,
    n.verdict
  FROM strategic_narratives_r2853 n
  ORDER BY (n.differentiation_score + n.resonance_score + n.market_clarity_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_tagline_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_tagline_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2853_verdict_distribution();
CREATE OR REPLACE FUNCTION rpc_r2853_verdict_distribution()
RETURNS TABLE (verdict text, narrative_count integer, avg_resonance numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.verdict, COUNT(*)::integer, ROUND(AVG(n.resonance_score)::numeric, 2)
  FROM strategic_narratives_r2853 n
  GROUP BY n.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2853_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2853_verdict_distribution() TO authenticated;

COMMIT;
