BEGIN;

CREATE TABLE IF NOT EXISTS quarterly_narrative_drafts_r2709 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  narrative_arc text NOT NULL CHECK (narrative_arc IN ('momentum','pivot','consolidation','expansion','recovery','breakthrough')),
  headline text NOT NULL,
  audience text NOT NULL CHECK (audience IN ('investors','board','employees','customers','press','partners')),
  delivery_channel text NOT NULL CHECK (delivery_channel IN ('letter','deck','townhall','interview','email','video')),
  resonance_score numeric(4,2) NOT NULL CHECK (resonance_score BETWEEN 0 AND 10),
  refine_iteration int NOT NULL DEFAULT 1 CHECK (refine_iteration BETWEEN 1 AND 12),
  signal_action text NOT NULL CHECK (signal_action IN ('publish_now','one_more_pass','escalate_to_legal','workshop_with_board','ship_after_q_close','scrap_and_restart')),
  status text NOT NULL DEFAULT 'drafting' CHECK (status IN ('drafting','reviewing','approved','published','retired')),
  draft_word_count int NOT NULL CHECK (draft_word_count BETWEEN 0 AND 12000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quarterly_narrative_resonance_signals_r2709 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES quarterly_narrative_drafts_r2709(id) ON DELETE CASCADE,
  signal_source text NOT NULL CHECK (signal_source IN ('reader_panel','board_chair','lead_investor','employee_pulse','press_proxy','customer_advisory')),
  resonance_delta numeric(4,2) NOT NULL CHECK (resonance_delta BETWEEN -5 AND 5),
  refine_suggestion text NOT NULL,
  action_recommended text NOT NULL CHECK (action_recommended IN ('soften_tone','sharpen_thesis','add_proof','cut_jargon','reorder_arc','add_humility','expand_vision')),
  captured_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE quarterly_narrative_drafts_r2709 ENABLE ROW LEVEL SECURITY;
ALTER TABLE quarterly_narrative_resonance_signals_r2709 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON quarterly_narrative_drafts_r2709;
CREATE POLICY founder_all ON quarterly_narrative_drafts_r2709 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON quarterly_narrative_resonance_signals_r2709;
CREATE POLICY founder_all ON quarterly_narrative_resonance_signals_r2709 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO quarterly_narrative_drafts_r2709 (quarter, narrative_arc, headline, audience, delivery_channel, resonance_score, refine_iteration, signal_action, status, draft_word_count) VALUES
('Q2-2026','momentum','From pilot to platform: 878 ships in 100 days','investors','letter',8.40,3,'publish_now','approved',2400),
('Q2-2026','breakthrough','Why hospital chains chose us over OEMs','board','deck',9.10,5,'workshop_with_board','reviewing',1800),
('Q2-2026','consolidation','One engineer network, three verticals','employees','townhall',7.60,2,'one_more_pass','drafting',1200),
('Q2-2026','expansion','South India is just the warm-up','press','interview',6.80,4,'escalate_to_legal','reviewing',900),
('Q2-2026','pivot','Why we paused franchise and doubled down on AMC','partners','email',7.20,6,'ship_after_q_close','drafting',1500),
('Q2-2026','recovery','The Cashfree freeze and what it taught us','investors','letter',8.90,7,'publish_now','published',3200);

INSERT INTO quarterly_narrative_resonance_signals_r2709 (draft_id, signal_source, resonance_delta, refine_suggestion, action_recommended) 
SELECT id, 'lead_investor', 1.20, 'Cut the OEM bashing — let the numbers speak', 'soften_tone' FROM quarterly_narrative_drafts_r2709 WHERE headline LIKE 'Why hospital chains%' LIMIT 1;

INSERT INTO quarterly_narrative_resonance_signals_r2709 (draft_id, signal_source, resonance_delta, refine_suggestion, action_recommended) 
SELECT id, 'board_chair', 0.80, 'Add a concrete unit-economics chart on page 3', 'add_proof' FROM quarterly_narrative_drafts_r2709 WHERE headline LIKE 'From pilot to platform%' LIMIT 1;

INSERT INTO quarterly_narrative_resonance_signals_r2709 (draft_id, signal_source, resonance_delta, refine_suggestion, action_recommended) 
SELECT id, 'employee_pulse', -0.40, 'Engineers feel "platform" is corporate-speak', 'cut_jargon' FROM quarterly_narrative_drafts_r2709 WHERE headline LIKE 'One engineer network%' LIMIT 1;

INSERT INTO quarterly_narrative_resonance_signals_r2709 (draft_id, signal_source, resonance_delta, refine_suggestion, action_recommended) 
SELECT id, 'press_proxy', -1.10, 'Headline is too triumphalist for a press piece', 'add_humility' FROM quarterly_narrative_drafts_r2709 WHERE headline LIKE 'South India%' LIMIT 1;

INSERT INTO quarterly_narrative_resonance_signals_r2709 (draft_id, signal_source, resonance_delta, refine_suggestion, action_recommended) 
SELECT id, 'customer_advisory', 1.80, 'The Cashfree honesty section is your strongest', 'sharpen_thesis' FROM quarterly_narrative_drafts_r2709 WHERE headline LIKE 'The Cashfree freeze%' LIMIT 1;

INSERT INTO quarterly_narrative_resonance_signals_r2709 (draft_id, signal_source, resonance_delta, refine_suggestion, action_recommended) 
SELECT id, 'reader_panel', 0.50, 'Move the franchise pause story to opening', 'reorder_arc' FROM quarterly_narrative_drafts_r2709 WHERE headline LIKE 'Why we paused franchise%' LIMIT 1;

DROP FUNCTION IF EXISTS founder_qnu_overview_r2709();
CREATE OR REPLACE FUNCTION founder_qnu_overview_r2709()
RETURNS TABLE(total_drafts int, approved_drafts int, avg_resonance numeric, total_words int, publish_now_count int, refine_iterations_avg numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT 
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status IN ('approved','published'))::int,
    ROUND(AVG(resonance_score),2),
    SUM(draft_word_count)::int,
    COUNT(*) FILTER (WHERE signal_action = 'publish_now')::int,
    ROUND(AVG(refine_iteration),1)
  FROM quarterly_narrative_drafts_r2709;
END $$;
REVOKE EXECUTE ON FUNCTION founder_qnu_overview_r2709() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qnu_overview_r2709() TO authenticated;

DROP FUNCTION IF EXISTS founder_qnu_by_arc_r2709();
CREATE OR REPLACE FUNCTION founder_qnu_by_arc_r2709()
RETURNS TABLE(narrative_arc text, draft_count int, avg_resonance numeric, total_words int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.narrative_arc, COUNT(*)::int, ROUND(AVG(d.resonance_score),2), SUM(d.draft_word_count)::int
  FROM quarterly_narrative_drafts_r2709 d GROUP BY d.narrative_arc ORDER BY AVG(d.resonance_score) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_qnu_by_arc_r2709() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qnu_by_arc_r2709() TO authenticated;

DROP FUNCTION IF EXISTS founder_qnu_by_audience_r2709();
CREATE OR REPLACE FUNCTION founder_qnu_by_audience_r2709()
RETURNS TABLE(audience text, draft_count int, avg_resonance numeric, top_channel text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.audience, COUNT(*)::int, ROUND(AVG(d.resonance_score),2), MODE() WITHIN GROUP (ORDER BY d.delivery_channel)
  FROM quarterly_narrative_drafts_r2709 d GROUP BY d.audience ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_qnu_by_audience_r2709() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qnu_by_audience_r2709() TO authenticated;

DROP FUNCTION IF EXISTS founder_qnu_drafts_r2709();
CREATE OR REPLACE FUNCTION founder_qnu_drafts_r2709()
RETURNS TABLE(id uuid, quarter text, narrative_arc text, headline text, audience text, delivery_channel text, resonance_score numeric, refine_iteration int, signal_action text, status text, draft_word_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.id, d.quarter, d.narrative_arc, d.headline, d.audience, d.delivery_channel, d.resonance_score, d.refine_iteration, d.signal_action, d.status, d.draft_word_count
  FROM quarterly_narrative_drafts_r2709 d ORDER BY d.resonance_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_qnu_drafts_r2709() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qnu_drafts_r2709() TO authenticated;

DROP FUNCTION IF EXISTS founder_qnu_signals_r2709();
CREATE OR REPLACE FUNCTION founder_qnu_signals_r2709()
RETURNS TABLE(id uuid, headline text, signal_source text, resonance_delta numeric, refine_suggestion text, action_recommended text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, d.headline, s.signal_source, s.resonance_delta, s.refine_suggestion, s.action_recommended
  FROM quarterly_narrative_resonance_signals_r2709 s JOIN quarterly_narrative_drafts_r2709 d ON d.id = s.draft_id
  ORDER BY ABS(s.resonance_delta) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_qnu_signals_r2709() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qnu_signals_r2709() TO authenticated;

DROP FUNCTION IF EXISTS founder_qnu_signal_actions_r2709();
CREATE OR REPLACE FUNCTION founder_qnu_signal_actions_r2709()
RETURNS TABLE(signal_action text, draft_count int, avg_words numeric, avg_iteration numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.signal_action, COUNT(*)::int, ROUND(AVG(d.draft_word_count),0), ROUND(AVG(d.refine_iteration),1)
  FROM quarterly_narrative_drafts_r2709 d GROUP BY d.signal_action ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_qnu_signal_actions_r2709() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qnu_signal_actions_r2709() TO authenticated;

DROP FUNCTION IF EXISTS founder_qnu_action_breakdown_r2709();
CREATE OR REPLACE FUNCTION founder_qnu_action_breakdown_r2709()
RETURNS TABLE(action_recommended text, signal_count int, avg_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.action_recommended, COUNT(*)::int, ROUND(AVG(s.resonance_delta),2)
  FROM quarterly_narrative_resonance_signals_r2709 s GROUP BY s.action_recommended ORDER BY AVG(s.resonance_delta) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_qnu_action_breakdown_r2709() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qnu_action_breakdown_r2709() TO authenticated;

COMMIT;