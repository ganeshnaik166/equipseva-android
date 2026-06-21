BEGIN;

-- =============================================================================
-- r1595 — Founder Hospital Sales Referral Tracker
-- Hospitals refer other hospitals; per-referrer + referee status + bounty queue
-- =============================================================================

-- Referral records: referrer hospital -> referee hospital with funnel status
CREATE TABLE IF NOT EXISTS public.hospital_sales_referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  referee_org_name text NOT NULL,
  referee_contact_name text,
  referee_contact_phone text,
  referee_contact_email text,
  referee_city text,
  referee_state text,
  referee_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted','contacted','met','negotiating','closed','lost')),
  expected_amc_tier text
    CHECK (expected_amc_tier IS NULL OR expected_amc_tier IN ('bronze','silver','gold','platinum')),
  expected_monthly_fee_rupees integer,
  notes text,
  contacted_at timestamptz,
  met_at timestamptz,
  closed_at timestamptz,
  lost_reason text,
  bounty_rupees integer NOT NULL DEFAULT 0,
  bounty_status text NOT NULL DEFAULT 'pending'
    CHECK (bounty_status IN ('pending','approved','queued','paid','rejected')),
  bounty_approved_at timestamptz,
  bounty_paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsr_referrer ON public.hospital_sales_referrals(referrer_org_id);
CREATE INDEX IF NOT EXISTS idx_hsr_status ON public.hospital_sales_referrals(status);
CREATE INDEX IF NOT EXISTS idx_hsr_bounty_status ON public.hospital_sales_referrals(bounty_status);
CREATE INDEX IF NOT EXISTS idx_hsr_created_at ON public.hospital_sales_referrals(created_at DESC);

ALTER TABLE public.hospital_sales_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsr_founder_all ON public.hospital_sales_referrals;
CREATE POLICY hsr_founder_all ON public.hospital_sales_referrals
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Bounty payout queue ledger
CREATE TABLE IF NOT EXISTS public.hospital_referral_bounty_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id uuid NOT NULL REFERENCES public.hospital_sales_referrals(id) ON DELETE CASCADE,
  referrer_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  amount_rupees integer NOT NULL CHECK (amount_rupees >= 0),
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','processing','paid','failed','cancelled')),
  payout_method text,
  payout_reference text,
  queued_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  failure_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrbp_referral ON public.hospital_referral_bounty_payouts(referral_id);
CREATE INDEX IF NOT EXISTS idx_hrbp_status ON public.hospital_referral_bounty_payouts(status);
CREATE INDEX IF NOT EXISTS idx_hrbp_queued_at ON public.hospital_referral_bounty_payouts(queued_at DESC);

ALTER TABLE public.hospital_referral_bounty_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hrbp_founder_all ON public.hospital_referral_bounty_payouts;
CREATE POLICY hrbp_founder_all ON public.hospital_referral_bounty_payouts
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.log_founder_referral_status_change(
  p_referral_id uuid, p_old_status text, p_new_status text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'referral_status_change',
    jsonb_build_object('referral_id', p_referral_id, 'old_status', p_old_status, 'new_status', p_new_status));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_referral_bounty_approve(
  p_referral_id uuid, p_amount_rupees integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'referral_bounty_approve',
    jsonb_build_object('referral_id', p_referral_id, 'amount_rupees', p_amount_rupees));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_referral_bounty_queue(
  p_referral_id uuid, p_payout_id uuid
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'referral_bounty_queue',
    jsonb_build_object('referral_id', p_referral_id, 'payout_id', p_payout_id));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_referral_bounty_paid(
  p_payout_id uuid, p_reference text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'referral_bounty_paid',
    jsonb_build_object('payout_id', p_payout_id, 'reference', p_reference));
END $$;

REVOKE EXECUTE ON FUNCTION public.log_founder_referral_status_change(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_referral_bounty_approve(uuid, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_referral_bounty_queue(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_referral_bounty_paid(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_referral_status_change(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_referral_bounty_approve(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_referral_bounty_queue(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_referral_bounty_paid(uuid, text) TO authenticated;

-- =============================================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- =============================================================================

-- 1. Funnel summary KPIs
CREATE OR REPLACE FUNCTION public.founder_referral_funnel_summary()
RETURNS TABLE (
  total_referrals bigint,
  submitted bigint,
  contacted bigint,
  met bigint,
  negotiating bigint,
  closed_won bigint,
  lost bigint,
  total_bounty_pending_rupees bigint,
  total_bounty_paid_rupees bigint,
  conversion_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='submitted')::bigint,
    COUNT(*) FILTER (WHERE status='contacted')::bigint,
    COUNT(*) FILTER (WHERE status='met')::bigint,
    COUNT(*) FILTER (WHERE status='negotiating')::bigint,
    COUNT(*) FILTER (WHERE status='closed')::bigint,
    COUNT(*) FILTER (WHERE status='lost')::bigint,
    COALESCE(SUM(bounty_rupees) FILTER (WHERE bounty_status IN ('pending','approved','queued')),0)::bigint,
    COALESCE(SUM(bounty_rupees) FILTER (WHERE bounty_status='paid'),0)::bigint,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE status='closed')::numeric / COUNT(*)::numeric, 2)
      ELSE 0 END
  FROM public.hospital_sales_referrals;
END $$;

-- 2. Top referrer leaderboard
CREATE OR REPLACE FUNCTION public.founder_referral_top_referrers()
RETURNS TABLE (
  id uuid,
  referrer_org_id uuid,
  referrer_org_name text,
  referrer_city text,
  total_referrals bigint,
  closed_referrals bigint,
  bounty_earned_rupees bigint,
  bounty_paid_rupees bigint,
  last_referral_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.id AS referrer_org_id,
    o.name,
    o.city,
    COUNT(r.id)::bigint,
    COUNT(r.id) FILTER (WHERE r.status='closed')::bigint,
    COALESCE(SUM(r.bounty_rupees) FILTER (WHERE r.bounty_status IN ('approved','queued','paid')),0)::bigint,
    COALESCE(SUM(r.bounty_rupees) FILTER (WHERE r.bounty_status='paid'),0)::bigint,
    MAX(r.created_at)
  FROM public.hospital_sales_referrals r
  JOIN public.organizations o ON o.id = r.referrer_org_id
  GROUP BY o.id, o.name, o.city
  ORDER BY COUNT(r.id) DESC
  LIMIT 50;
END $$;

-- 3. Referral pipeline (active funnel)
CREATE OR REPLACE FUNCTION public.founder_referral_pipeline()
RETURNS TABLE (
  id uuid,
  referrer_org_name text,
  referee_org_name text,
  referee_city text,
  referee_state text,
  status text,
  expected_amc_tier text,
  expected_monthly_fee_rupees integer,
  days_in_funnel numeric,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    o.name,
    r.referee_org_name,
    r.referee_city,
    r.referee_state,
    r.status,
    r.expected_amc_tier,
    r.expected_monthly_fee_rupees,
    ROUND(EXTRACT(EPOCH FROM (now() - r.created_at))/86400.0, 1),
    r.created_at
  FROM public.hospital_sales_referrals r
  JOIN public.organizations o ON o.id = r.referrer_org_id
  WHERE r.status IN ('submitted','contacted','met','negotiating')
  ORDER BY r.created_at DESC
  LIMIT 200;
END $$;

-- 4. Stalled referrals (no movement >7 days)
CREATE OR REPLACE FUNCTION public.founder_referral_stalled()
RETURNS TABLE (
  id uuid,
  referrer_org_name text,
  referee_org_name text,
  status text,
  days_stalled numeric,
  last_touch_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    o.name,
    r.referee_org_name,
    r.status,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(r.met_at, r.contacted_at, r.created_at)))/86400.0, 1),
    COALESCE(r.met_at, r.contacted_at, r.created_at)
  FROM public.hospital_sales_referrals r
  JOIN public.organizations o ON o.id = r.referrer_org_id
  WHERE r.status IN ('submitted','contacted','met','negotiating')
    AND COALESCE(r.met_at, r.contacted_at, r.created_at) < now() - interval '7 days'
  ORDER BY COALESCE(r.met_at, r.contacted_at, r.created_at) ASC
  LIMIT 100;
END $$;

-- 5. Bounty payout queue
CREATE OR REPLACE FUNCTION public.founder_referral_bounty_queue()
RETURNS TABLE (
  id uuid,
  referral_id uuid,
  referrer_org_name text,
  referee_org_name text,
  amount_rupees integer,
  status text,
  queued_at timestamptz,
  days_in_queue numeric,
  payout_method text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.referral_id,
    o.name,
    r.referee_org_name,
    p.amount_rupees,
    p.status,
    p.queued_at,
    ROUND(EXTRACT(EPOCH FROM (now() - p.queued_at))/86400.0, 1),
    p.payout_method
  FROM public.hospital_referral_bounty_payouts p
  JOIN public.hospital_sales_referrals r ON r.id = p.referral_id
  JOIN public.organizations o ON o.id = p.referrer_org_id
  ORDER BY p.queued_at DESC
  LIMIT 200;
END $$;

-- 6. Closed-won referrals (recent conversions)
CREATE OR REPLACE FUNCTION public.founder_referral_recent_wins()
RETURNS TABLE (
  id uuid,
  referrer_org_name text,
  referee_org_name text,
  expected_amc_tier text,
  expected_monthly_fee_rupees integer,
  bounty_rupees integer,
  bounty_status text,
  closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    o.name,
    r.referee_org_name,
    r.expected_amc_tier,
    r.expected_monthly_fee_rupees,
    r.bounty_rupees,
    r.bounty_status,
    r.closed_at
  FROM public.hospital_sales_referrals r
  JOIN public.organizations o ON o.id = r.referrer_org_id
  WHERE r.status = 'closed'
  ORDER BY r.closed_at DESC NULLS LAST
  LIMIT 100;
END $$;

-- =============================================================================
-- WRITE RPC (VOLATILE SECDEF, founder-gated)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.founder_referral_advance_status(
  p_referral_id uuid, p_new_status text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old_status text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('submitted','contacted','met','negotiating','closed','lost') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status;
  END IF;
  SELECT status INTO v_old_status FROM public.hospital_sales_referrals WHERE id = p_referral_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'referral not found'; END IF;
  UPDATE public.hospital_sales_referrals
  SET status = p_new_status,
      contacted_at = CASE WHEN p_new_status='contacted' AND contacted_at IS NULL THEN now() ELSE contacted_at END,
      met_at = CASE WHEN p_new_status='met' AND met_at IS NULL THEN now() ELSE met_at END,
      closed_at = CASE WHEN p_new_status='closed' THEN now() ELSE closed_at END,
      updated_at = now()
  WHERE id = p_referral_id;
  PERFORM public.log_founder_referral_status_change(p_referral_id, v_old_status, p_new_status);
END $$;

-- =============================================================================
-- GRANTS
-- =============================================================================

REVOKE EXECUTE ON FUNCTION public.founder_referral_funnel_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_referral_top_referrers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_referral_pipeline() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_referral_stalled() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_referral_bounty_queue() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_referral_recent_wins() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_referral_advance_status(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_referral_funnel_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_referral_top_referrers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_referral_pipeline() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_referral_stalled() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_referral_bounty_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_referral_recent_wins() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_referral_advance_status(uuid, text) TO authenticated;

COMMIT;