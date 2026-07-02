BEGIN;

-- Round 1588 — Founder console: investor secondary buyback offers
-- Track outbound offers to existing shareholders for secondary share buyback.
-- Per-offer price, status, response tracking, founder consolidation approval.

CREATE TABLE IF NOT EXISTS founder_investor_buyback_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_label text NOT NULL,
  target_consolidation_pct numeric(6,3) NOT NULL CHECK (target_consolidation_pct > 0 AND target_consolidation_pct <= 100),
  ceiling_price_per_share_rupees numeric(14,2) NOT NULL CHECK (ceiling_price_per_share_rupees > 0),
  budget_envelope_rupees numeric(16,2) NOT NULL CHECK (budget_envelope_rupees >= 0),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closes_at timestamptz,
  consolidation_approved_at timestamptz,
  consolidation_approved_by uuid REFERENCES auth.users(id),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','consolidating','approved','rejected','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_investor_buyback_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES founder_investor_buyback_rounds(id) ON DELETE CASCADE,
  shareholder_name text NOT NULL,
  shareholder_email text,
  shares_offered bigint NOT NULL CHECK (shares_offered > 0),
  offered_price_per_share_rupees numeric(14,2) NOT NULL CHECK (offered_price_per_share_rupees > 0),
  total_offer_rupees numeric(16,2) GENERATED ALWAYS AS (shares_offered * offered_price_per_share_rupees) STORED,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','accepted','declined','countered','expired','withdrawn','consolidated')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  counter_price_per_share_rupees numeric(14,2),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fibo_round ON founder_investor_buyback_offers(round_id);
CREATE INDEX IF NOT EXISTS idx_fibo_status ON founder_investor_buyback_offers(status);
CREATE INDEX IF NOT EXISTS idx_fibr_status ON founder_investor_buyback_rounds(status);

ALTER TABLE founder_investor_buyback_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_buyback_offers  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fibr_founder_only ON founder_investor_buyback_rounds;
CREATE POLICY fibr_founder_only ON founder_investor_buyback_rounds
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS fibo_founder_only ON founder_investor_buyback_offers;
CREATE POLICY fibo_founder_only ON founder_investor_buyback_offers
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_buyback_round_opened(p_round_id uuid, p_label text, p_target_pct numeric, p_ceiling numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'buyback_round_opened',
    jsonb_build_object('round_id', p_round_id, 'label', p_label, 'target_pct', p_target_pct, 'ceiling', p_ceiling));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_buyback_round_opened(uuid, text, numeric, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_buyback_round_opened(uuid, text, numeric, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_buyback_offer_sent(p_offer_id uuid, p_round_id uuid, p_shareholder text, p_total numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'buyback_offer_sent',
    jsonb_build_object('offer_id', p_offer_id, 'round_id', p_round_id, 'shareholder', p_shareholder, 'total', p_total));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_buyback_offer_sent(uuid, uuid, text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_buyback_offer_sent(uuid, uuid, text, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_buyback_offer_response(p_offer_id uuid, p_status text, p_counter numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'buyback_offer_response',
    jsonb_build_object('offer_id', p_offer_id, 'status', p_status, 'counter', p_counter));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_buyback_offer_response(uuid, text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_buyback_offer_response(uuid, text, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_buyback_consolidation_approved(p_round_id uuid, p_accepted_offers int, p_total_rupees numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'buyback_consolidation_approved',
    jsonb_build_object('round_id', p_round_id, 'accepted_offers', p_accepted_offers, 'total_rupees', p_total_rupees));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_buyback_consolidation_approved(uuid, int, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_buyback_consolidation_approved(uuid, int, numeric) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_buyback_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'rounds_total',         (SELECT count(*) FROM founder_investor_buyback_rounds),
    'rounds_open',          (SELECT count(*) FROM founder_investor_buyback_rounds WHERE status = 'open'),
    'rounds_consolidating', (SELECT count(*) FROM founder_investor_buyback_rounds WHERE status = 'consolidating'),
    'rounds_approved',      (SELECT count(*) FROM founder_investor_buyback_rounds WHERE status = 'approved'),
    'rounds_closed',        (SELECT count(*) FROM founder_investor_buyback_rounds WHERE status IN ('closed','rejected')),
    'offers_total',         (SELECT count(*) FROM founder_investor_buyback_offers),
    'offers_sent',          (SELECT count(*) FROM founder_investor_buyback_offers WHERE status = 'sent'),
    'offers_accepted',      (SELECT count(*) FROM founder_investor_buyback_offers WHERE status = 'accepted'),
    'offers_declined',      (SELECT count(*) FROM founder_investor_buyback_offers WHERE status = 'declined'),
    'offers_countered',     (SELECT count(*) FROM founder_investor_buyback_offers WHERE status = 'countered'),
    'offers_expired',       (SELECT count(*) FROM founder_investor_buyback_offers WHERE status = 'expired'),
    'offers_consolidated',  (SELECT count(*) FROM founder_investor_buyback_offers WHERE status = 'consolidated'),
    'shares_accepted',      (SELECT coalesce(sum(shares_offered),0) FROM founder_investor_buyback_offers WHERE status IN ('accepted','consolidated')),
    'rupees_committed',     (SELECT coalesce(sum(total_offer_rupees),0) FROM founder_investor_buyback_offers WHERE status IN ('accepted','consolidated')),
    'avg_offer_price',      (SELECT coalesce(round(avg(offered_price_per_share_rupees),2),0) FROM founder_investor_buyback_offers WHERE status IN ('sent','accepted','countered','consolidated')),
    'budget_total',         (SELECT coalesce(sum(budget_envelope_rupees),0) FROM founder_investor_buyback_rounds WHERE status IN ('open','consolidating'))
  ) INTO v;
  RETURN v;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_buyback_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_buyback_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_buyback_rounds_list()
RETURNS TABLE (
  id uuid, round_label text, status text, target_consolidation_pct numeric,
  ceiling_price_per_share_rupees numeric, budget_envelope_rupees numeric,
  opened_at timestamptz, closes_at timestamptz, consolidation_approved_at timestamptz,
  offers_count bigint, accepted_count bigint, committed_rupees numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.round_label, r.status, r.target_consolidation_pct,
         r.ceiling_price_per_share_rupees, r.budget_envelope_rupees,
         r.opened_at, r.closes_at, r.consolidation_approved_at,
         (SELECT count(*) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id),
         (SELECT count(*) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status IN ('accepted','consolidated')),
         (SELECT coalesce(sum(o.total_offer_rupees),0) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status IN ('accepted','consolidated'))
  FROM founder_investor_buyback_rounds r
  ORDER BY r.opened_at DESC
  LIMIT 100;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_buyback_rounds_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_buyback_rounds_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_buyback_offers_recent()
RETURNS TABLE (
  id uuid, round_label text, shareholder_name text, shareholder_email text,
  shares_offered bigint, offered_price_per_share_rupees numeric, total_offer_rupees numeric,
  status text, sent_at timestamptz, responded_at timestamptz, counter_price_per_share_rupees numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, r.round_label, o.shareholder_name, o.shareholder_email,
         o.shares_offered, o.offered_price_per_share_rupees, o.total_offer_rupees,
         o.status, o.sent_at, o.responded_at, o.counter_price_per_share_rupees
  FROM founder_investor_buyback_offers o
  JOIN founder_investor_buyback_rounds r ON r.id = o.round_id
  ORDER BY o.sent_at DESC
  LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_buyback_offers_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_buyback_offers_recent() TO authenticated;

CREATE OR REPLACE FUNCTION founder_buyback_pending_responses()
RETURNS TABLE (
  id uuid, round_label text, shareholder_name text, shareholder_email text,
  shares_offered bigint, offered_price_per_share_rupees numeric, total_offer_rupees numeric,
  sent_at timestamptz, days_outstanding numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, r.round_label, o.shareholder_name, o.shareholder_email,
         o.shares_offered, o.offered_price_per_share_rupees, o.total_offer_rupees,
         o.sent_at,
         round(EXTRACT(EPOCH FROM (now() - o.sent_at))/86400.0, 2) AS days_outstanding
  FROM founder_investor_buyback_offers o
  JOIN founder_investor_buyback_rounds r ON r.id = o.round_id
  WHERE o.status = 'sent'
  ORDER BY o.sent_at ASC
  LIMIT 100;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_buyback_pending_responses() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_buyback_pending_responses() TO authenticated;

CREATE OR REPLACE FUNCTION founder_buyback_round_breakdown()
RETURNS TABLE (
  round_label text, status text,
  sent_count bigint, accepted_count bigint, declined_count bigint, countered_count bigint,
  total_committed_rupees numeric, budget_envelope_rupees numeric, headroom_rupees numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.round_label, r.status,
         (SELECT count(*) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status = 'sent'),
         (SELECT count(*) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status IN ('accepted','consolidated')),
         (SELECT count(*) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status = 'declined'),
         (SELECT count(*) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status = 'countered'),
         (SELECT coalesce(sum(o.total_offer_rupees),0) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status IN ('accepted','consolidated')),
         r.budget_envelope_rupees,
         r.budget_envelope_rupees - (SELECT coalesce(sum(o.total_offer_rupees),0) FROM founder_investor_buyback_offers o WHERE o.round_id = r.id AND o.status IN ('accepted','consolidated'))
  FROM founder_investor_buyback_rounds r
  ORDER BY r.opened_at DESC
  LIMIT 50;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_buyback_round_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_buyback_round_breakdown() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_buyback_round_open(
  p_label text, p_target_pct numeric, p_ceiling numeric, p_budget numeric, p_closes_at timestamptz
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_buyback_rounds(round_label, target_consolidation_pct, ceiling_price_per_share_rupees, budget_envelope_rupees, closes_at)
  VALUES (p_label, p_target_pct, p_ceiling, p_budget, p_closes_at)
  RETURNING id INTO new_id;
  PERFORM log_founder_buyback_round_opened(new_id, p_label, p_target_pct, p_ceiling);
  RETURN new_id;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_buyback_round_open(text, numeric, numeric, numeric, timestamptz) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_buyback_round_open(text, numeric, numeric, numeric, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION founder_buyback_consolidation_approve(p_round_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_accepted int;
  v_total numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*), coalesce(sum(total_offer_rupees),0)
    INTO v_accepted, v_total
    FROM founder_investor_buyback_offers
    WHERE round_id = p_round_id AND status = 'accepted';
  UPDATE founder_investor_buyback_offers
    SET status = 'consolidated'
    WHERE round_id = p_round_id AND status = 'accepted';
  UPDATE founder_investor_buyback_rounds
    SET status = 'approved',
        consolidation_approved_at = now(),
        consolidation_approved_by = auth.uid()
    WHERE id = p_round_id;
  PERFORM log_founder_buyback_consolidation_approved(p_round_id, v_accepted, v_total);
END;$$;
REVOKE EXECUTE ON FUNCTION founder_buyback_consolidation_approve(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_buyback_consolidation_approve(uuid) TO authenticated;

COMMIT;