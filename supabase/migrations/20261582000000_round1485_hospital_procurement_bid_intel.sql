BEGIN;

-- =========================================================================
-- r1485 — Hospital Procurement Bid Intel
-- Capture tender intel, our submission status, competitors, expected price,
-- and a founder review queue.
-- =========================================================================

-- ---------- Table 1: tenders ---------------------------------------------
CREATE TABLE IF NOT EXISTS hospital_procurement_tenders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES organizations(id) ON DELETE SET NULL,
  hospital_name text NOT NULL,
  city text,
  state text,
  tender_ref text,
  tender_title text NOT NULL,
  tender_category text NOT NULL DEFAULT 'amc'
    CHECK (tender_category IN ('amc','repair','installation','spares','consumables','mixed')),
  estimated_value_rupees bigint NOT NULL DEFAULT 0,
  expected_winning_price_rupees bigint,
  emd_rupees bigint NOT NULL DEFAULT 0,
  published_at timestamptz,
  due_at timestamptz NOT NULL,
  result_expected_at timestamptz,
  our_submission_status text NOT NULL DEFAULT 'evaluating'
    CHECK (our_submission_status IN ('evaluating','preparing','submitted','withdrawn','disqualified','won','lost','abandoned')),
  our_bid_rupees bigint,
  win_probability_pct int NOT NULL DEFAULT 0 CHECK (win_probability_pct BETWEEN 0 AND 100),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  source text,
  notes text,
  needs_founder_review boolean NOT NULL DEFAULT true,
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpt_due_at ON hospital_procurement_tenders(due_at);
CREATE INDEX IF NOT EXISTS idx_hpt_status ON hospital_procurement_tenders(our_submission_status);
CREATE INDEX IF NOT EXISTS idx_hpt_review ON hospital_procurement_tenders(needs_founder_review) WHERE needs_founder_review;
CREATE INDEX IF NOT EXISTS idx_hpt_hospital ON hospital_procurement_tenders(hospital_org_id);

ALTER TABLE hospital_procurement_tenders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hpt_founder_only ON hospital_procurement_tenders;
CREATE POLICY hpt_founder_only ON hospital_procurement_tenders
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Table 2: competitors per tender ------------------------------
CREATE TABLE IF NOT EXISTS hospital_procurement_bid_competitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_id uuid NOT NULL REFERENCES hospital_procurement_tenders(id) ON DELETE CASCADE,
  competitor_name text NOT NULL,
  competitor_tier text NOT NULL DEFAULT 'unknown'
    CHECK (competitor_tier IN ('oem','national_msp','regional_msp','local','unknown')),
  expected_bid_rupees bigint,
  threat_level text NOT NULL DEFAULT 'medium' CHECK (threat_level IN ('low','medium','high','critical')),
  past_wins_vs_us int NOT NULL DEFAULT 0,
  past_losses_vs_us int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpbc_tender ON hospital_procurement_bid_competitors(tender_id);
CREATE INDEX IF NOT EXISTS idx_hpbc_threat ON hospital_procurement_bid_competitors(threat_level);

ALTER TABLE hospital_procurement_bid_competitors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hpbc_founder_only ON hospital_procurement_bid_competitors;
CREATE POLICY hpbc_founder_only ON hospital_procurement_bid_competitors
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_hpbi_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_tenders', COUNT(*),
    'active_tenders', COUNT(*) FILTER (WHERE our_submission_status IN ('evaluating','preparing','submitted')),
    'needs_review', COUNT(*) FILTER (WHERE needs_founder_review),
    'submitted_count', COUNT(*) FILTER (WHERE our_submission_status='submitted'),
    'won_count', COUNT(*) FILTER (WHERE our_submission_status='won'),
    'lost_count', COUNT(*) FILTER (WHERE our_submission_status='lost'),
    'abandoned_count', COUNT(*) FILTER (WHERE our_submission_status='abandoned'),
    'due_in_7d', COUNT(*) FILTER (WHERE due_at BETWEEN now() AND now()+interval '7 days' AND our_submission_status IN ('evaluating','preparing')),
    'overdue_unsubmitted', COUNT(*) FILTER (WHERE due_at < now() AND our_submission_status IN ('evaluating','preparing')),
    'critical_priority', COUNT(*) FILTER (WHERE priority='critical'),
    'high_priority', COUNT(*) FILTER (WHERE priority='high'),
    'pipeline_value_rupees', COALESCE(SUM(estimated_value_rupees) FILTER (WHERE our_submission_status IN ('evaluating','preparing','submitted')),0),
    'submitted_bid_value_rupees', COALESCE(SUM(our_bid_rupees) FILTER (WHERE our_submission_status='submitted'),0),
    'won_value_rupees', COALESCE(SUM(our_bid_rupees) FILTER (WHERE our_submission_status='won'),0),
    'avg_win_probability', COALESCE(ROUND(AVG(win_probability_pct) FILTER (WHERE our_submission_status IN ('evaluating','preparing','submitted')))::int, 0),
    'avg_expected_winning_price_rupees', COALESCE(ROUND(AVG(expected_winning_price_rupees))::bigint, 0)
  ) INTO r FROM hospital_procurement_tenders;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hpbi_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hpbi_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_hpbi_review_queue()
RETURNS TABLE (
  id uuid, hospital_name text, tender_title text, due_at timestamptz,
  priority text, our_submission_status text, estimated_value_rupees bigint,
  win_probability_pct int, city text, state text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_name, t.tender_title, t.due_at, t.priority,
         t.our_submission_status, t.estimated_value_rupees, t.win_probability_pct,
         t.city, t.state
  FROM hospital_procurement_tenders t
  WHERE t.needs_founder_review
  ORDER BY
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    t.due_at ASC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hpbi_review_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hpbi_review_queue() TO authenticated;

CREATE OR REPLACE FUNCTION founder_hpbi_upcoming_due()
RETURNS TABLE (
  id uuid, hospital_name text, tender_title text, due_at timestamptz,
  days_to_due int, our_submission_status text, estimated_value_rupees bigint,
  our_bid_rupees bigint, priority text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_name, t.tender_title, t.due_at,
         GREATEST(0, EXTRACT(EPOCH FROM (t.due_at - now()))::int / 86400)::int AS days_to_due,
         t.our_submission_status, t.estimated_value_rupees, t.our_bid_rupees, t.priority
  FROM hospital_procurement_tenders t
  WHERE t.due_at >= now() - interval '1 day'
    AND t.our_submission_status IN ('evaluating','preparing','submitted')
  ORDER BY t.due_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hpbi_upcoming_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hpbi_upcoming_due() TO authenticated;

CREATE OR REPLACE FUNCTION founder_hpbi_competitor_threat()
RETURNS TABLE (
  competitor_name text, competitor_tier text, appearances int,
  high_threat_count int, avg_expected_bid_rupees bigint,
  wins_vs_us int, losses_vs_us int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.competitor_name,
         MAX(c.competitor_tier),
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE c.threat_level IN ('high','critical'))::int,
         COALESCE(ROUND(AVG(c.expected_bid_rupees))::bigint, 0),
         COALESCE(SUM(c.past_wins_vs_us),0)::int,
         COALESCE(SUM(c.past_losses_vs_us),0)::int
  FROM hospital_procurement_bid_competitors c
  GROUP BY c.competitor_name
  ORDER BY COUNT(*) DESC, COUNT(*) FILTER (WHERE c.threat_level IN ('high','critical')) DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hpbi_competitor_threat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hpbi_competitor_threat() TO authenticated;

CREATE OR REPLACE FUNCTION founder_hpbi_pipeline_by_status()
RETURNS TABLE (
  our_submission_status text, tender_count int,
  total_estimated_rupees bigint, total_our_bid_rupees bigint,
  avg_win_probability int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.our_submission_status,
         COUNT(*)::int,
         COALESCE(SUM(t.estimated_value_rupees),0),
         COALESCE(SUM(t.our_bid_rupees),0),
         COALESCE(ROUND(AVG(t.win_probability_pct))::int, 0)
  FROM hospital_procurement_tenders t
  GROUP BY t.our_submission_status
  ORDER BY 3 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hpbi_pipeline_by_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hpbi_pipeline_by_status() TO authenticated;

CREATE OR REPLACE FUNCTION founder_hpbi_recent_outcomes()
RETURNS TABLE (
  id uuid, hospital_name text, tender_title text,
  our_submission_status text, our_bid_rupees bigint,
  expected_winning_price_rupees bigint, reviewed_at timestamptz, due_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_name, t.tender_title, t.our_submission_status,
         t.our_bid_rupees, t.expected_winning_price_rupees, t.reviewed_at, t.due_at
  FROM hospital_procurement_tenders t
  WHERE t.our_submission_status IN ('won','lost','abandoned','disqualified','withdrawn')
  ORDER BY COALESCE(t.reviewed_at, t.updated_at) DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hpbi_recent_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hpbi_recent_outcomes() TO authenticated;

-- =========================================================================
-- WRITE RPC (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_hpbi_mark_reviewed(p_tender_id uuid, p_new_status text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status IS NOT NULL AND p_new_status NOT IN ('evaluating','preparing','submitted','withdrawn','disqualified','won','lost','abandoned') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status;
  END IF;
  UPDATE hospital_procurement_tenders
     SET needs_founder_review = false,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         our_submission_status = COALESCE(p_new_status, our_submission_status),
         updated_at = now()
   WHERE id = p_tender_id
   RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hpbi_mark_reviewed(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hpbi_mark_reviewed(uuid,text) TO authenticated;

-- =========================================================================
-- log_founder_* helpers (VOLATILE, founder-gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_hpbi_tender_seen(p_tender_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_procurement_tenders SET updated_at = now() WHERE id = p_tender_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hpbi_tender_seen(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hpbi_tender_seen(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hpbi_priority_change(p_tender_id uuid, p_priority text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_priority NOT IN ('low','medium','high','critical') THEN RAISE EXCEPTION 'invalid priority'; END IF;
  UPDATE hospital_procurement_tenders SET priority = p_priority, updated_at = now() WHERE id = p_tender_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hpbi_priority_change(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hpbi_priority_change(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hpbi_bid_recorded(p_tender_id uuid, p_our_bid_rupees bigint)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_procurement_tenders
     SET our_bid_rupees = p_our_bid_rupees,
         our_submission_status = CASE WHEN our_submission_status IN ('evaluating','preparing') THEN 'submitted' ELSE our_submission_status END,
         updated_at = now()
   WHERE id = p_tender_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hpbi_bid_recorded(uuid,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hpbi_bid_recorded(uuid,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hpbi_competitor_noted(p_tender_id uuid, p_competitor_name text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_procurement_bid_competitors (tender_id, competitor_name)
  VALUES (p_tender_id, p_competitor_name)
  ON CONFLICT DO NOTHING;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hpbi_competitor_noted(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hpbi_competitor_noted(uuid,text) TO authenticated;

COMMIT;