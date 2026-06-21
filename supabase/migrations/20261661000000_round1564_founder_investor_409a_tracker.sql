BEGIN;

-- Round 1564: Founder 409A Valuation Tracker
-- HEAVY founder console feature: log 409A valuations over time, per-vendor (Carta etc),
-- founder review of common-stock vs preferred ratio, ESOP repricing trigger.

CREATE TABLE IF NOT EXISTS founder_409a_valuations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor text NOT NULL CHECK (vendor IN ('carta','pulley','astrella','shareworks','eqvista','custom')),
  valuation_date date NOT NULL,
  effective_date date NOT NULL,
  expires_on date,
  preferred_price_per_share_paise bigint NOT NULL CHECK (preferred_price_per_share_paise > 0),
  common_price_per_share_paise bigint NOT NULL CHECK (common_price_per_share_paise > 0),
  fully_diluted_shares bigint NOT NULL CHECK (fully_diluted_shares > 0),
  enterprise_value_paise bigint NOT NULL,
  methodology text NOT NULL CHECK (methodology IN ('opm','pwerm','hybrid','market_approach')),
  safe_harbor boolean NOT NULL DEFAULT true,
  report_url text,
  notes text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','under_review','approved','superseded','revoked')),
  approved_by uuid REFERENCES profiles(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_founder_409a_valuations_date ON founder_409a_valuations(valuation_date DESC);
CREATE INDEX IF NOT EXISTS idx_founder_409a_valuations_status ON founder_409a_valuations(status);
CREATE INDEX IF NOT EXISTS idx_founder_409a_valuations_vendor ON founder_409a_valuations(vendor);

ALTER TABLE founder_409a_valuations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_409a_valuations ON founder_409a_valuations;
CREATE POLICY founder_only_409a_valuations ON founder_409a_valuations
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_409a_esop_repricing_triggers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  valuation_id uuid NOT NULL REFERENCES founder_409a_valuations(id) ON DELETE CASCADE,
  trigger_type text NOT NULL CHECK (trigger_type IN ('underwater_grants','common_drop','dilution_event','annual_refresh')),
  affected_grants_count int NOT NULL DEFAULT 0,
  affected_options bigint NOT NULL DEFAULT 0,
  old_strike_paise bigint,
  new_strike_paise bigint,
  decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending','approved','rejected','executed')),
  decided_by uuid REFERENCES profiles(id),
  decided_at timestamptz,
  rationale text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_409a_repricing_valuation ON founder_409a_esop_repricing_triggers(valuation_id);
CREATE INDEX IF NOT EXISTS idx_founder_409a_repricing_decision ON founder_409a_esop_repricing_triggers(decision);

ALTER TABLE founder_409a_esop_repricing_triggers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_409a_repricing ON founder_409a_esop_repricing_triggers;
CREATE POLICY founder_only_409a_repricing ON founder_409a_esop_repricing_triggers
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_409a_create(p_valuation_id uuid, p_vendor text, p_common_paise bigint, p_preferred_paise bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_409a_create',
    jsonb_build_object('valuation_id', p_valuation_id, 'vendor', p_vendor, 'common_paise', p_common_paise, 'preferred_paise', p_preferred_paise));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_409a_create(uuid, text, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_409a_create(uuid, text, bigint, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_409a_approve(p_valuation_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_409a_approve',
    jsonb_build_object('valuation_id', p_valuation_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_409a_approve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_409a_approve(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_409a_reprice_trigger(p_valuation_id uuid, p_trigger_type text, p_affected_options bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_409a_reprice_trigger',
    jsonb_build_object('valuation_id', p_valuation_id, 'trigger_type', p_trigger_type, 'affected_options', p_affected_options));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_409a_reprice_trigger(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_409a_reprice_trigger(uuid, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_409a_reprice_decision(p_trigger_id uuid, p_decision text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_409a_reprice_decision',
    jsonb_build_object('trigger_id', p_trigger_id, 'decision', p_decision));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_409a_reprice_decision(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_409a_reprice_decision(uuid, text) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_409a_summary_kpis()
RETURNS TABLE(
  total_valuations bigint,
  approved_count bigint,
  draft_count bigint,
  under_review_count bigint,
  superseded_count bigint,
  current_common_paise bigint,
  current_preferred_paise bigint,
  current_ratio_pct numeric,
  current_enterprise_value_paise bigint,
  current_vendor text,
  current_methodology text,
  current_safe_harbor boolean,
  days_until_expiry int,
  pending_repricing_triggers bigint,
  affected_options_total bigint,
  total_repriced_options bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH current_val AS (
    SELECT * FROM founder_409a_valuations
    WHERE status = 'approved'
    ORDER BY effective_date DESC LIMIT 1
  )
  SELECT
    (SELECT COUNT(*) FROM founder_409a_valuations),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'approved'),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'draft'),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'under_review'),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'superseded'),
    (SELECT common_price_per_share_paise FROM current_val),
    (SELECT preferred_price_per_share_paise FROM current_val),
    COALESCE((SELECT round((common_price_per_share_paise::numeric / NULLIF(preferred_price_per_share_paise,0)) * 100, 2) FROM current_val), 0),
    (SELECT enterprise_value_paise FROM current_val),
    (SELECT vendor FROM current_val),
    (SELECT methodology FROM current_val),
    (SELECT safe_harbor FROM current_val),
    (SELECT (expires_on - CURRENT_DATE)::int FROM current_val),
    (SELECT COUNT(*) FROM founder_409a_esop_repricing_triggers WHERE decision = 'pending'),
    COALESCE((SELECT SUM(affected_options) FROM founder_409a_esop_repricing_triggers WHERE decision = 'pending'), 0),
    COALESCE((SELECT SUM(affected_options) FROM founder_409a_esop_repricing_triggers WHERE decision = 'executed'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_409a_summary_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_409a_summary_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_409a_valuation_history()
RETURNS TABLE(
  id uuid,
  valuation_date date,
  effective_date date,
  vendor text,
  methodology text,
  common_paise bigint,
  preferred_paise bigint,
  ratio_pct numeric,
  enterprise_value_paise bigint,
  status text,
  safe_harbor boolean,
  days_to_expiry int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.valuation_date, v.effective_date, v.vendor, v.methodology,
    v.common_price_per_share_paise, v.preferred_price_per_share_paise,
    round((v.common_price_per_share_paise::numeric / NULLIF(v.preferred_price_per_share_paise,0)) * 100, 2),
    v.enterprise_value_paise, v.status, v.safe_harbor,
    CASE WHEN v.expires_on IS NULL THEN NULL ELSE (v.expires_on - CURRENT_DATE)::int END
  FROM founder_409a_valuations v
  ORDER BY v.valuation_date DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_409a_valuation_history() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_409a_valuation_history() TO authenticated;

CREATE OR REPLACE FUNCTION founder_409a_per_vendor_breakdown()
RETURNS TABLE(
  vendor text,
  valuation_count bigint,
  approved_count bigint,
  avg_common_paise numeric,
  avg_preferred_paise numeric,
  avg_ratio_pct numeric,
  last_valuation_date date,
  safe_harbor_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.vendor,
    COUNT(*),
    COUNT(*) FILTER (WHERE v.status = 'approved'),
    round(AVG(v.common_price_per_share_paise), 2),
    round(AVG(v.preferred_price_per_share_paise), 2),
    round(AVG((v.common_price_per_share_paise::numeric / NULLIF(v.preferred_price_per_share_paise,0)) * 100), 2),
    MAX(v.valuation_date),
    COALESCE(round((COUNT(*) FILTER (WHERE v.safe_harbor)::numeric / NULLIF(COUNT(*),0)) * 100, 1), 0)
  FROM founder_409a_valuations v
  GROUP BY v.vendor
  ORDER BY MAX(v.valuation_date) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_409a_per_vendor_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_409a_per_vendor_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION founder_409a_ratio_review()
RETURNS TABLE(
  id uuid,
  valuation_date date,
  vendor text,
  common_paise bigint,
  preferred_paise bigint,
  ratio_pct numeric,
  status text,
  ratio_band text,
  needs_review boolean
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH r AS (
    SELECT v.id, v.valuation_date, v.vendor, v.common_price_per_share_paise AS common_paise,
      v.preferred_price_per_share_paise AS preferred_paise,
      round((v.common_price_per_share_paise::numeric / NULLIF(v.preferred_price_per_share_paise,0)) * 100, 2) AS ratio,
      v.status
    FROM founder_409a_valuations v
  )
  SELECT r.id, r.valuation_date, r.vendor, r.common_paise, r.preferred_paise, r.ratio, r.status,
    CASE WHEN r.ratio < 10 THEN 'aggressive' WHEN r.ratio < 25 THEN 'standard' WHEN r.ratio < 50 THEN 'conservative' ELSE 'flat_round_risk' END,
    (r.ratio < 10 OR r.ratio >= 50)
  FROM r
  ORDER BY r.valuation_date DESC
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_409a_ratio_review() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_409a_ratio_review() TO authenticated;

CREATE OR REPLACE FUNCTION founder_409a_repricing_queue()
RETURNS TABLE(
  id uuid,
  valuation_id uuid,
  valuation_date date,
  vendor text,
  trigger_type text,
  affected_grants_count int,
  affected_options bigint,
  old_strike_paise bigint,
  new_strike_paise bigint,
  decision text,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.valuation_id, v.valuation_date, v.vendor, t.trigger_type,
    t.affected_grants_count, t.affected_options, t.old_strike_paise, t.new_strike_paise,
    t.decision, t.created_at
  FROM founder_409a_esop_repricing_triggers t
  JOIN founder_409a_valuations v ON v.id = t.valuation_id
  ORDER BY (t.decision = 'pending') DESC, t.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_409a_repricing_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_409a_repricing_queue() TO authenticated;

CREATE OR REPLACE FUNCTION founder_409a_methodology_split()
RETURNS TABLE(
  methodology text,
  count bigint,
  avg_common_paise numeric,
  avg_ratio_pct numeric,
  safe_harbor_count bigint,
  approved_count bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.methodology, COUNT(*),
    round(AVG(v.common_price_per_share_paise), 2),
    round(AVG((v.common_price_per_share_paise::numeric / NULLIF(v.preferred_price_per_share_paise,0)) * 100), 2),
    COUNT(*) FILTER (WHERE v.safe_harbor),
    COUNT(*) FILTER (WHERE v.status = 'approved')
  FROM founder_409a_valuations v
  GROUP BY v.methodology
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_409a_methodology_split() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_409a_methodology_split() TO authenticated;

CREATE OR REPLACE FUNCTION founder_409a_expiry_radar()
RETURNS TABLE(
  id uuid,
  vendor text,
  effective_date date,
  expires_on date,
  days_remaining int,
  status text,
  urgency text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.vendor, v.effective_date, v.expires_on,
    (v.expires_on - CURRENT_DATE)::int,
    v.status,
    CASE
      WHEN v.expires_on < CURRENT_DATE THEN 'expired'
      WHEN (v.expires_on - CURRENT_DATE) < 30 THEN 'critical'
      WHEN (v.expires_on - CURRENT_DATE) < 90 THEN 'warning'
      ELSE 'ok'
    END
  FROM founder_409a_valuations v
  WHERE v.expires_on IS NOT NULL
    AND v.status IN ('approved','under_review')
  ORDER BY v.expires_on ASC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_409a_expiry_radar() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_409a_expiry_radar() TO authenticated;

COMMIT;