-- Round 2527: Hospital Chain Rebate Loyalty Credit Ledger
-- chain × earned rebate × redeemed × pending × kind × policy compliance

CREATE TABLE IF NOT EXISTS public.chain_rebate_ledger_r2527 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  earned_at timestamptz NOT NULL DEFAULT now(),
  earned_rupees bigint NOT NULL DEFAULT 0,
  rebate_kind text NOT NULL CHECK (rebate_kind IN ('volume','multi_year','marketing_co_op','referral','loyalty_tier_bump')),
  policy_compliance text NOT NULL CHECK (policy_compliance IN ('compliant','marginal','non_compliant')),
  redeemed_at timestamptz,
  redeemed_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('earned','pending_redeem','redeemed','expired','forfeited')),
  owner_email text,
  notes text
);

CREATE TABLE IF NOT EXISTS public.rebate_redemption_actions_r2527 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  rebate_id uuid NOT NULL REFERENCES public.chain_rebate_ledger_r2527(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('amc_discount','spare_credit','marketing_spend','event_sponsor','refund')),
  action_summary text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  notes text
);

ALTER TABLE public.chain_rebate_ledger_r2527 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rebate_redemption_actions_r2527 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_rebate_ledger_r2527;
CREATE POLICY founder_all ON public.chain_rebate_ledger_r2527 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.rebate_redemption_actions_r2527;
CREATE POLICY founder_all ON public.rebate_redemption_actions_r2527 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed rebate ledger
INSERT INTO public.chain_rebate_ledger_r2527 (chain_name, earned_at, earned_rupees, rebate_kind, policy_compliance, redeemed_at, redeemed_rupees, status, owner_email, notes) VALUES
  ('Apollo Group', '2026-04-12T10:00:00+05:30'::timestamptz, 450000, 'volume', 'compliant', '2026-05-20T12:00:00+05:30'::timestamptz, 450000, 'redeemed', 'cfo@apollo.example', '12 facility annual volume tier hit'),
  ('Fortis Chain', '2026-05-01T09:00:00+05:30'::timestamptz, 280000, 'multi_year', 'compliant', NULL, 0, 'pending_redeem', 'finance@fortis.example', '3-year AMC lock-in bonus'),
  ('Manipal Network', '2026-05-15T11:30:00+05:30'::timestamptz, 120000, 'marketing_co_op', 'marginal', NULL, 0, 'earned', 'ops@manipal.example', 'Co-op spend pending receipts'),
  ('Max Healthcare', '2026-03-20T14:00:00+05:30'::timestamptz, 90000, 'referral', 'compliant', '2026-04-05T10:00:00+05:30'::timestamptz, 90000, 'redeemed', 'gm@maxhc.example', 'Referred 2 new chains'),
  ('Yashoda Hospitals', '2026-02-10T09:00:00+05:30'::timestamptz, 60000, 'loyalty_tier_bump', 'non_compliant', NULL, 0, 'forfeited', 'cfo@yashoda.example', 'Late payments forfeited bonus');

-- Seed redemption actions
INSERT INTO public.rebate_redemption_actions_r2527 (rebate_id, action_at, action_kind, action_summary, owner_email, status, notes)
SELECT id, '2026-05-20T12:00:00+05:30'::timestamptz, 'amc_discount', 'Apollo Q2 AMC discount applied', 'cfo@apollo.example', 'done', 'Applied to 12 facilities'
FROM public.chain_rebate_ledger_r2527 WHERE chain_name='Apollo Group' LIMIT 1;

INSERT INTO public.rebate_redemption_actions_r2527 (rebate_id, action_at, action_kind, action_summary, owner_email, status, notes)
SELECT id, '2026-05-25T10:00:00+05:30'::timestamptz, 'spare_credit', 'Fortis spare-part credit line opened', 'finance@fortis.example', 'in_progress', 'Awaiting PO confirmation'
FROM public.chain_rebate_ledger_r2527 WHERE chain_name='Fortis Chain' LIMIT 1;

INSERT INTO public.rebate_redemption_actions_r2527 (rebate_id, action_at, action_kind, action_summary, owner_email, status, notes)
SELECT id, '2026-05-30T14:00:00+05:30'::timestamptz, 'marketing_spend', 'Manipal co-op camp budget plan', 'ops@manipal.example', 'open', 'Need receipt audit'
FROM public.chain_rebate_ledger_r2527 WHERE chain_name='Manipal Network' LIMIT 1;

-- RPC 1: list rebate ledger
CREATE OR REPLACE FUNCTION public.list_rebate_ledger_r2527()
RETURNS TABLE(id uuid, chain_name text, earned_at timestamptz, earned_rupees bigint, rebate_kind text, policy_compliance text, redeemed_at timestamptz, redeemed_rupees bigint, status text, owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.chain_name, l.earned_at, l.earned_rupees, l.rebate_kind, l.policy_compliance, l.redeemed_at, l.redeemed_rupees, l.status, l.owner_email, l.notes
    FROM public.chain_rebate_ledger_r2527 l
    ORDER BY l.earned_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_rebate_ledger_r2527() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_rebate_ledger_r2527() TO authenticated;

-- RPC 2: list redemption actions
CREATE OR REPLACE FUNCTION public.list_redemption_actions_r2527()
RETURNS TABLE(id uuid, rebate_id uuid, chain_name text, action_at timestamptz, action_kind text, action_summary text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.rebate_id, l.chain_name, a.action_at, a.action_kind, a.action_summary, a.owner_email, a.status, a.notes
    FROM public.rebate_redemption_actions_r2527 a
    JOIN public.chain_rebate_ledger_r2527 l ON l.id = a.rebate_id
    ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_redemption_actions_r2527() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_redemption_actions_r2527() TO authenticated;

-- RPC 3: top earning chains
CREATE OR REPLACE FUNCTION public.top_earning_chains_r2527()
RETURNS TABLE(chain_name text, total_earned_rupees bigint, total_redeemed_rupees bigint, pending_rupees bigint, rebate_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.chain_name,
           COALESCE(SUM(l.earned_rupees),0)::bigint AS total_earned_rupees,
           COALESCE(SUM(l.redeemed_rupees),0)::bigint AS total_redeemed_rupees,
           COALESCE(SUM(l.earned_rupees - l.redeemed_rupees),0)::bigint AS pending_rupees,
           COUNT(*)::bigint AS rebate_count
    FROM public.chain_rebate_ledger_r2527 l
    GROUP BY l.chain_name
    ORDER BY total_earned_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_earning_chains_r2527() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_earning_chains_r2527() TO authenticated;

-- RPC 4: rebate kind breakdown
CREATE OR REPLACE FUNCTION public.rebate_kind_breakdown_r2527()
RETURNS TABLE(rebate_kind text, ledger_count bigint, earned_rupees bigint, redeemed_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.rebate_kind,
           COUNT(*)::bigint AS ledger_count,
           COALESCE(SUM(l.earned_rupees),0)::bigint AS earned_rupees,
           COALESCE(SUM(l.redeemed_rupees),0)::bigint AS redeemed_rupees
    FROM public.chain_rebate_ledger_r2527 l
    GROUP BY l.rebate_kind
    ORDER BY earned_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.rebate_kind_breakdown_r2527() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rebate_kind_breakdown_r2527() TO authenticated;

-- RPC 5: pending redeem focus
CREATE OR REPLACE FUNCTION public.pending_redeem_focus_r2527()
RETURNS TABLE(id uuid, chain_name text, earned_at timestamptz, earned_rupees bigint, rebate_kind text, status text, owner_email text, days_outstanding integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.chain_name, l.earned_at, l.earned_rupees, l.rebate_kind, l.status, l.owner_email,
           EXTRACT(DAY FROM (now() - l.earned_at))::integer AS days_outstanding
    FROM public.chain_rebate_ledger_r2527 l
    WHERE l.status IN ('earned','pending_redeem')
    ORDER BY l.earned_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.pending_redeem_focus_r2527() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pending_redeem_focus_r2527() TO authenticated;

-- RPC 6: monthly earn trend
CREATE OR REPLACE FUNCTION public.monthly_earn_trend_r2527()
RETURNS TABLE(month_label text, ledger_count bigint, earned_rupees bigint, redeemed_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', l.earned_at), 'YYYY-MM') AS month_label,
           COUNT(*)::bigint AS ledger_count,
           COALESCE(SUM(l.earned_rupees),0)::bigint AS earned_rupees,
           COALESCE(SUM(l.redeemed_rupees),0)::bigint AS redeemed_rupees
    FROM public.chain_rebate_ledger_r2527 l
    GROUP BY date_trunc('month', l.earned_at)
    ORDER BY date_trunc('month', l.earned_at) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_earn_trend_r2527() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_earn_trend_r2527() TO authenticated;

-- RPC 7: compliance summary
CREATE OR REPLACE FUNCTION public.compliance_summary_r2527()
RETURNS TABLE(policy_compliance text, ledger_count bigint, earned_rupees bigint, redeemed_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.policy_compliance,
           COUNT(*)::bigint AS ledger_count,
           COALESCE(SUM(l.earned_rupees),0)::bigint AS earned_rupees,
           COALESCE(SUM(l.redeemed_rupees),0)::bigint AS redeemed_rupees
    FROM public.chain_rebate_ledger_r2527 l
    GROUP BY l.policy_compliance
    ORDER BY earned_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.compliance_summary_r2527() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compliance_summary_r2527() TO authenticated;
