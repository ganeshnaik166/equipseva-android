BEGIN;

-- ============================================================
-- r1474: Investor Referral Program Tracker
-- Track investors who refer other investors; bounty + ladder
-- ============================================================

-- Table 1: investor_referrals — one row per referred investor
CREATE TABLE IF NOT EXISTS investor_referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_name text NOT NULL,
  referrer_email text,
  referrer_fund text,
  referee_name text NOT NULL,
  referee_email text,
  referee_fund text,
  stage text NOT NULL DEFAULT 'intro' CHECK (stage IN ('intro','meeting','diligence','check','dead')),
  check_amount_rupees bigint DEFAULT 0,
  bounty_rupees bigint NOT NULL DEFAULT 0,
  intro_at timestamptz NOT NULL DEFAULT now(),
  meeting_at timestamptz,
  diligence_at timestamptz,
  check_at timestamptz,
  dead_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_ref_stage ON investor_referrals(stage);
CREATE INDEX IF NOT EXISTS idx_inv_ref_referrer ON investor_referrals(referrer_email);
CREATE INDEX IF NOT EXISTS idx_inv_ref_intro_at ON investor_referrals(intro_at DESC);

ALTER TABLE investor_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inv_ref_founder_all ON investor_referrals;
CREATE POLICY inv_ref_founder_all ON investor_referrals
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: investor_referral_payouts — bounty payouts to referrers
CREATE TABLE IF NOT EXISTS investor_referral_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id uuid NOT NULL REFERENCES investor_referrals(id) ON DELETE CASCADE,
  referrer_name text NOT NULL,
  referrer_email text,
  amount_rupees bigint NOT NULL,
  paid_at timestamptz,
  payout_method text DEFAULT 'bank_transfer',
  payout_ref text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_ref_payouts_referral ON investor_referral_payouts(referral_id);
CREATE INDEX IF NOT EXISTS idx_inv_ref_payouts_paid ON investor_referral_payouts(paid_at DESC);

ALTER TABLE investor_referral_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inv_ref_payouts_founder_all ON investor_referral_payouts;
CREATE POLICY inv_ref_payouts_founder_all ON investor_referral_payouts
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_investor_referral_overview()
RETURNS TABLE (
  total_referrals bigint,
  total_referrers bigint,
  intro_count bigint,
  meeting_count bigint,
  diligence_count bigint,
  check_count bigint,
  dead_count bigint,
  total_check_rupees bigint,
  total_bounty_rupees bigint,
  paid_bounty_rupees bigint,
  pending_bounty_rupees bigint,
  conversion_rate_pct numeric,
  avg_check_rupees bigint,
  intro_to_check_days numeric,
  active_pipeline_count bigint,
  this_month_intros bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(DISTINCT referrer_email)::bigint,
    COUNT(*) FILTER (WHERE stage='intro')::bigint,
    COUNT(*) FILTER (WHERE stage='meeting')::bigint,
    COUNT(*) FILTER (WHERE stage='diligence')::bigint,
    COUNT(*) FILTER (WHERE stage='check')::bigint,
    COUNT(*) FILTER (WHERE stage='dead')::bigint,
    COALESCE(SUM(check_amount_rupees) FILTER (WHERE stage='check'),0)::bigint,
    COALESCE(SUM(bounty_rupees),0)::bigint,
    COALESCE((SELECT SUM(amount_rupees) FROM investor_referral_payouts WHERE paid_at IS NOT NULL),0)::bigint,
    COALESCE((SELECT SUM(amount_rupees) FROM investor_referral_payouts WHERE paid_at IS NULL),0)::bigint,
    CASE WHEN COUNT(*) > 0 THEN ROUND(100.0 * COUNT(*) FILTER (WHERE stage='check') / COUNT(*), 2) ELSE 0 END,
    COALESCE(AVG(check_amount_rupees) FILTER (WHERE stage='check'),0)::bigint,
    COALESCE(AVG(EXTRACT(EPOCH FROM (check_at - intro_at))/86400) FILTER (WHERE check_at IS NOT NULL),0)::numeric,
    COUNT(*) FILTER (WHERE stage IN ('intro','meeting','diligence'))::bigint,
    COUNT(*) FILTER (WHERE intro_at >= date_trunc('month', now()))::bigint
  FROM investor_referrals;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_referral_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_referral_overview() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_investor_referral_ladder()
RETURNS TABLE (
  stage text,
  count bigint,
  total_check_rupees bigint,
  conversion_from_intro_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  total_intros bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_intros FROM investor_referrals;
  RETURN QUERY
  SELECT
    s.stage,
    COUNT(ir.id)::bigint,
    COALESCE(SUM(ir.check_amount_rupees),0)::bigint,
    CASE WHEN total_intros > 0 THEN ROUND(100.0 * COUNT(ir.id) / total_intros, 2) ELSE 0 END
  FROM (VALUES ('intro'),('meeting'),('diligence'),('check'),('dead')) AS s(stage)
  LEFT JOIN investor_referrals ir ON ir.stage = s.stage
  GROUP BY s.stage
  ORDER BY CASE s.stage WHEN 'intro' THEN 1 WHEN 'meeting' THEN 2 WHEN 'diligence' THEN 3 WHEN 'check' THEN 4 WHEN 'dead' THEN 5 END;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_referral_ladder() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_referral_ladder() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_investor_referral_top_referrers()
RETURNS TABLE (
  referrer_name text,
  referrer_email text,
  referrer_fund text,
  referrals_count bigint,
  checks_count bigint,
  total_check_rupees bigint,
  total_bounty_rupees bigint,
  paid_bounty_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    ir.referrer_name,
    ir.referrer_email,
    MAX(ir.referrer_fund),
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE ir.stage='check')::bigint,
    COALESCE(SUM(ir.check_amount_rupees) FILTER (WHERE ir.stage='check'),0)::bigint,
    COALESCE(SUM(ir.bounty_rupees),0)::bigint,
    COALESCE((SELECT SUM(p.amount_rupees) FROM investor_referral_payouts p WHERE p.referrer_email = ir.referrer_email AND p.paid_at IS NOT NULL),0)::bigint
  FROM investor_referrals ir
  GROUP BY ir.referrer_name, ir.referrer_email
  ORDER BY COUNT(*) FILTER (WHERE ir.stage='check') DESC, COUNT(*) DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_referral_top_referrers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_referral_top_referrers() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_investor_referral_pipeline()
RETURNS TABLE (
  id uuid,
  referrer_name text,
  referee_name text,
  referee_fund text,
  stage text,
  check_amount_rupees bigint,
  bounty_rupees bigint,
  intro_at timestamptz,
  days_in_pipeline numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    ir.id,
    ir.referrer_name,
    ir.referee_name,
    ir.referee_fund,
    ir.stage,
    ir.check_amount_rupees,
    ir.bounty_rupees,
    ir.intro_at,
    ROUND(EXTRACT(EPOCH FROM (now() - ir.intro_at))/86400, 1)::numeric
  FROM investor_referrals ir
  WHERE ir.stage IN ('intro','meeting','diligence')
  ORDER BY ir.intro_at DESC
  LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_referral_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_referral_pipeline() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_investor_referral_payouts_due()
RETURNS TABLE (
  id uuid,
  referral_id uuid,
  referrer_name text,
  referrer_email text,
  amount_rupees bigint,
  created_at timestamptz,
  days_outstanding numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.referral_id,
    p.referrer_name,
    p.referrer_email,
    p.amount_rupees,
    p.created_at,
    ROUND(EXTRACT(EPOCH FROM (now() - p.created_at))/86400, 1)::numeric
  FROM investor_referral_payouts p
  WHERE p.paid_at IS NULL
  ORDER BY p.created_at ASC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_referral_payouts_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_referral_payouts_due() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_investor_referral_recent_wins()
RETURNS TABLE (
  id uuid,
  referrer_name text,
  referee_name text,
  referee_fund text,
  check_amount_rupees bigint,
  bounty_rupees bigint,
  check_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ir.id, ir.referrer_name, ir.referee_name, ir.referee_fund,
         ir.check_amount_rupees, ir.bounty_rupees, ir.check_at
  FROM investor_referrals ir
  WHERE ir.stage = 'check'
  ORDER BY ir.check_at DESC NULLS LAST
  LIMIT 25;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_referral_recent_wins() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_referral_recent_wins() TO authenticated;


-- ============================================================
-- WRITE RPC (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_investor_referral_advance_stage(p_id uuid, p_new_stage text, p_check_rupees bigint DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_stage NOT IN ('intro','meeting','diligence','check','dead') THEN
    RAISE EXCEPTION 'invalid stage';
  END IF;

  UPDATE investor_referrals SET
    stage = p_new_stage,
    meeting_at = CASE WHEN p_new_stage='meeting' AND meeting_at IS NULL THEN now() ELSE meeting_at END,
    diligence_at = CASE WHEN p_new_stage='diligence' AND diligence_at IS NULL THEN now() ELSE diligence_at END,
    check_at = CASE WHEN p_new_stage='check' AND check_at IS NULL THEN now() ELSE check_at END,
    dead_at = CASE WHEN p_new_stage='dead' AND dead_at IS NULL THEN now() ELSE dead_at END,
    check_amount_rupees = COALESCE(p_check_rupees, check_amount_rupees),
    updated_at = now()
  WHERE id = p_id;

  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'investor_referral_advance', jsonb_build_object('id', p_id, 'stage', p_new_stage, 'check_rupees', p_check_rupees));

  RETURN p_id;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_referral_advance_stage(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_referral_advance_stage(uuid, text, bigint) TO authenticated;


-- ============================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_investor_referral_logged(p_referrer text, p_referee text, p_fund text, p_bounty_rupees bigint)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_referrals(referrer_name, referee_name, referee_fund, bounty_rupees)
  VALUES (p_referrer, p_referee, p_fund, COALESCE(p_bounty_rupees, 0))
  RETURNING id INTO v_id;

  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'investor_referral_logged', jsonb_build_object('id', v_id, 'referrer', p_referrer, 'referee', p_referee));
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_investor_referral_logged(text, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_referral_logged(text, text, text, bigint) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_investor_referral_bounty_queued(p_referral_id uuid, p_amount_rupees bigint)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
  v_ref_name text;
  v_ref_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT referrer_name, referrer_email INTO v_ref_name, v_ref_email FROM investor_referrals WHERE id = p_referral_id;

  INSERT INTO investor_referral_payouts(referral_id, referrer_name, referrer_email, amount_rupees)
  VALUES (p_referral_id, v_ref_name, v_ref_email, p_amount_rupees)
  RETURNING id INTO v_id;

  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'investor_referral_bounty_queued', jsonb_build_object('payout_id', v_id, 'referral_id', p_referral_id, 'amount_rupees', p_amount_rupees));
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_investor_referral_bounty_queued(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_referral_bounty_queued(uuid, bigint) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_investor_referral_bounty_paid(p_payout_id uuid, p_payout_ref text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_referral_payouts SET paid_at = now(), payout_ref = p_payout_ref WHERE id = p_payout_id;

  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'investor_referral_bounty_paid', jsonb_build_object('payout_id', p_payout_id, 'payout_ref', p_payout_ref));
  RETURN p_payout_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_investor_referral_bounty_paid(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_referral_bounty_paid(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_investor_referral_killed(p_referral_id uuid, p_reason text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_referrals SET stage='dead', dead_at = now(), notes = COALESCE(notes,'') || E'\nKILLED: ' || p_reason, updated_at = now()
  WHERE id = p_referral_id;

  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'investor_referral_killed', jsonb_build_object('referral_id', p_referral_id, 'reason', p_reason));
  RETURN p_referral_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_investor_referral_killed(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_referral_killed(uuid, text) TO authenticated;

COMMIT;