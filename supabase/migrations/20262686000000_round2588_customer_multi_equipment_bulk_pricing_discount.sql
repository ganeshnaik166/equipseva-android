-- Round 2588: customer-multi-equipment-bulk-pricing-discount
-- Hospital bulk equipment spend tracking, discount tier, annual savings, loyalty lock-in.

BEGIN;

-- =========================================================================
-- TABLE 1: customer_bulk_pricing_r2588
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.customer_bulk_pricing_r2588 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_count int NOT NULL DEFAULT 0,
  spend_tier text NOT NULL CHECK (spend_tier IN ('bronze','silver','gold','platinum','diamond')),
  spend_rupees bigint NOT NULL DEFAULT 0,
  discount_pct numeric(5,2) NOT NULL DEFAULT 0,
  annual_savings_rupees bigint NOT NULL DEFAULT 0,
  loyalty_lock_in_months int NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('proposed','accepted','negotiating','rejected','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_bulk_pricing_r2588 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_bulk_pricing_r2588;
CREATE POLICY founder_all ON public.customer_bulk_pricing_r2588
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- TABLE 2: bulk_pricing_decision_log_r2588
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.bulk_pricing_decision_log_r2588 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bulk_id uuid NOT NULL REFERENCES public.customer_bulk_pricing_r2588(id) ON DELETE CASCADE,
  decision_at timestamptz NOT NULL DEFAULT now(),
  decision_kind text NOT NULL CHECK (decision_kind IN ('approved','rejected','counter_offer','escalated')),
  summary_md text NOT NULL,
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bulk_pricing_decision_log_r2588 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.bulk_pricing_decision_log_r2588;
CREATE POLICY founder_all ON public.bulk_pricing_decision_log_r2588
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- SEED DATA
-- =========================================================================
DO $seed$
DECLARE
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_hosp4 uuid;
  v_hosp5 uuid;
  v_bulk1 uuid;
  v_bulk2 uuid;
  v_bulk3 uuid;
  v_bulk4 uuid;
  v_bulk5 uuid;
BEGIN
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 2 LIMIT 1;
  SELECT id INTO v_hosp4 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 3 LIMIT 1;
  SELECT id INTO v_hosp5 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 4 LIMIT 1;

  IF v_hosp1 IS NULL THEN
    SELECT id INTO v_hosp1 FROM public.profiles ORDER BY created_at LIMIT 1;
  END IF;
  IF v_hosp2 IS NULL THEN v_hosp2 := v_hosp1; END IF;
  IF v_hosp3 IS NULL THEN v_hosp3 := v_hosp1; END IF;
  IF v_hosp4 IS NULL THEN v_hosp4 := v_hosp1; END IF;
  IF v_hosp5 IS NULL THEN v_hosp5 := v_hosp1; END IF;

  IF v_hosp1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_bulk_pricing_r2588
    (hospital_user_id, equipment_count, spend_tier, spend_rupees, discount_pct, annual_savings_rupees, loyalty_lock_in_months, owner_email, status, notes)
  VALUES (v_hosp1, 12, 'gold', 4800000, 8.50, 408000, 24, 'sales@equipseva.in', 'accepted', 'Apollo Hyd cluster 12 units')
  RETURNING id INTO v_bulk1;

  INSERT INTO public.customer_bulk_pricing_r2588
    (hospital_user_id, equipment_count, spend_tier, spend_rupees, discount_pct, annual_savings_rupees, loyalty_lock_in_months, owner_email, status, notes)
  VALUES (v_hosp2, 25, 'platinum', 11200000, 12.00, 1344000, 36, 'sales@equipseva.in', 'negotiating', 'Yashoda 25 unit ask')
  RETURNING id INTO v_bulk2;

  INSERT INTO public.customer_bulk_pricing_r2588
    (hospital_user_id, equipment_count, spend_tier, spend_rupees, discount_pct, annual_savings_rupees, loyalty_lock_in_months, owner_email, status, notes)
  VALUES (v_hosp3, 6, 'silver', 1800000, 5.00, 90000, 12, 'sales@equipseva.in', 'proposed', 'KIMS pilot 6 units')
  RETURNING id INTO v_bulk3;

  INSERT INTO public.customer_bulk_pricing_r2588
    (hospital_user_id, equipment_count, spend_tier, spend_rupees, discount_pct, annual_savings_rupees, loyalty_lock_in_months, owner_email, status, notes)
  VALUES (v_hosp4, 45, 'diamond', 22500000, 15.00, 3375000, 48, 'sales@equipseva.in', 'accepted', 'Care Hospitals enterprise')
  RETURNING id INTO v_bulk4;

  INSERT INTO public.customer_bulk_pricing_r2588
    (hospital_user_id, equipment_count, spend_tier, spend_rupees, discount_pct, annual_savings_rupees, loyalty_lock_in_months, owner_email, status, notes)
  VALUES (v_hosp5, 3, 'bronze', 750000, 3.00, 22500, 12, 'sales@equipseva.in', 'rejected', 'Small clinic declined lock-in')
  RETURNING id INTO v_bulk5;

  INSERT INTO public.bulk_pricing_decision_log_r2588
    (bulk_id, decision_kind, summary_md, owner_email, status, notes)
  VALUES
    (v_bulk1, 'approved', '## Apollo Hyd approved\n8.5 pct discount on 12 units, 24 month lock-in.', 'founder@equipseva.in', 'done', null),
    (v_bulk2, 'counter_offer', '## Yashoda counter\nAsked 15 pct, we offered 12 pct + extended warranty.', 'founder@equipseva.in', 'open', null),
    (v_bulk3, 'escalated', '## KIMS pilot escalation\nNeed founder sign-off on 12-month minimum.', 'founder@equipseva.in', 'open', null),
    (v_bulk4, 'approved', '## Care Hospitals enterprise\nDiamond tier, 15 pct, 48 month lock-in. Marquee logo.', 'founder@equipseva.in', 'done', null),
    (v_bulk5, 'rejected', '## Small clinic\nDeclined lock-in, walked away.', 'founder@equipseva.in', 'done', null);

END
$seed$;

-- =========================================================================
-- RPC 1: list_bulk_pricing_r2588
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_bulk_pricing_r2588()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_count int,
  spend_tier text,
  spend_rupees bigint,
  discount_pct numeric,
  annual_savings_rupees bigint,
  loyalty_lock_in_months int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.hospital_user_id, p.email::text, b.equipment_count, b.spend_tier,
         b.spend_rupees, b.discount_pct, b.annual_savings_rupees, b.loyalty_lock_in_months,
         b.owner_email, b.status, b.notes, b.created_at
  FROM public.customer_bulk_pricing_r2588 b
  LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
  ORDER BY b.created_at DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_bulk_pricing_r2588() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bulk_pricing_r2588() TO authenticated;

-- =========================================================================
-- RPC 2: list_decision_log_r2588
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_decision_log_r2588()
RETURNS TABLE (
  id uuid,
  bulk_id uuid,
  hospital_email text,
  decision_at timestamptz,
  decision_kind text,
  summary_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.bulk_id, p.email::text, d.decision_at, d.decision_kind,
         d.summary_md, d.owner_email, d.status, d.notes, d.created_at
  FROM public.bulk_pricing_decision_log_r2588 d
  LEFT JOIN public.customer_bulk_pricing_r2588 b ON b.id = d.bulk_id
  LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
  ORDER BY d.decision_at DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_decision_log_r2588() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decision_log_r2588() TO authenticated;

-- =========================================================================
-- RPC 3: top_savings_focus_r2588
-- =========================================================================
CREATE OR REPLACE FUNCTION public.top_savings_focus_r2588()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  spend_tier text,
  equipment_count int,
  spend_rupees bigint,
  annual_savings_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, p.email::text, b.spend_tier, b.equipment_count, b.spend_rupees,
         b.annual_savings_rupees, b.status
  FROM public.customer_bulk_pricing_r2588 b
  LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
  ORDER BY b.annual_savings_rupees DESC NULLS LAST
  LIMIT 10;
END
$$;
REVOKE EXECUTE ON FUNCTION public.top_savings_focus_r2588() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_savings_focus_r2588() TO authenticated;

-- =========================================================================
-- RPC 4: spend_tier_distribution_r2588
-- =========================================================================
CREATE OR REPLACE FUNCTION public.spend_tier_distribution_r2588()
RETURNS TABLE (
  spend_tier text,
  account_count bigint,
  total_spend_rupees bigint,
  total_annual_savings_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.spend_tier,
         count(*)::bigint,
         coalesce(sum(b.spend_rupees), 0)::bigint,
         coalesce(sum(b.annual_savings_rupees), 0)::bigint
  FROM public.customer_bulk_pricing_r2588 b
  GROUP BY b.spend_tier
  ORDER BY sum(b.spend_rupees) DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.spend_tier_distribution_r2588() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.spend_tier_distribution_r2588() TO authenticated;

-- =========================================================================
-- RPC 5: status_funnel_r2588
-- =========================================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2588()
RETURNS TABLE (
  status text,
  account_count bigint,
  total_annual_savings_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.status,
         count(*)::bigint,
         coalesce(sum(b.annual_savings_rupees), 0)::bigint
  FROM public.customer_bulk_pricing_r2588 b
  GROUP BY b.status
  ORDER BY count(*) DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2588() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2588() TO authenticated;

-- =========================================================================
-- RPC 6: monthly_decision_trend_r2588
-- =========================================================================
CREATE OR REPLACE FUNCTION public.monthly_decision_trend_r2588()
RETURNS TABLE (
  month_label text,
  decisions_count bigint,
  approved_count bigint,
  rejected_count bigint,
  counter_offer_count bigint,
  escalated_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', d.decision_at), 'YYYY-MM')::text,
         count(*)::bigint,
         count(*) FILTER (WHERE d.decision_kind = 'approved')::bigint,
         count(*) FILTER (WHERE d.decision_kind = 'rejected')::bigint,
         count(*) FILTER (WHERE d.decision_kind = 'counter_offer')::bigint,
         count(*) FILTER (WHERE d.decision_kind = 'escalated')::bigint
  FROM public.bulk_pricing_decision_log_r2588 d
  GROUP BY date_trunc('month', d.decision_at)
  ORDER BY date_trunc('month', d.decision_at) DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_decision_trend_r2588() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_decision_trend_r2588() TO authenticated;

-- =========================================================================
-- RPC 7: total_annual_savings_summary_r2588
-- =========================================================================
CREATE OR REPLACE FUNCTION public.total_annual_savings_summary_r2588()
RETURNS TABLE (
  total_accounts bigint,
  total_equipment_count bigint,
  total_spend_rupees bigint,
  total_annual_savings_rupees bigint,
  accepted_accounts bigint,
  accepted_annual_savings_rupees bigint,
  avg_discount_pct numeric,
  avg_loyalty_lock_in_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint,
         coalesce(sum(b.equipment_count), 0)::bigint,
         coalesce(sum(b.spend_rupees), 0)::bigint,
         coalesce(sum(b.annual_savings_rupees), 0)::bigint,
         count(*) FILTER (WHERE b.status = 'accepted')::bigint,
         coalesce(sum(b.annual_savings_rupees) FILTER (WHERE b.status = 'accepted'), 0)::bigint,
         coalesce(round(avg(b.discount_pct)::numeric, 2), 0),
         coalesce(round(avg(b.loyalty_lock_in_months)::numeric, 1), 0)
  FROM public.customer_bulk_pricing_r2588 b;
END
$$;
REVOKE EXECUTE ON FUNCTION public.total_annual_savings_summary_r2588() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_annual_savings_summary_r2588() TO authenticated;

