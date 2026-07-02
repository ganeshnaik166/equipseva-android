-- Round 2543: hospital-chain-pharmacy-spend-influence
-- Tracks pharmacy spend per hospital chain, our influence over that spend,
-- and cross-sell / upsell opportunities unlocked from pharmacy data.

CREATE TABLE IF NOT EXISTS public.chain_pharmacy_spend_r2543 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  observation_period_start date NOT NULL,
  observation_period_end date NOT NULL,
  pharmacy_spend_rupees bigint NOT NULL DEFAULT 0 CHECK (pharmacy_spend_rupees >= 0),
  our_influence_kind text NOT NULL CHECK (our_influence_kind IN ('none','indirect','direct','strategic_partner')),
  cross_sell_opportunity_rupees bigint NOT NULL DEFAULT 0 CHECK (cross_sell_opportunity_rupees >= 0),
  upsell_target_kind text NOT NULL CHECK (upsell_target_kind IN ('amc_tier_up','equipment_add','training','consumables','installation')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','in_discussion','won','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pharmacy_cross_sell_actions_r2543 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spend_id uuid NOT NULL REFERENCES public.chain_pharmacy_spend_r2543(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('meeting','pitch_pack','discount','joint_program','email_followup')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_pharmacy_spend_r2543 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_cross_sell_actions_r2543 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_pharmacy_spend_r2543;
CREATE POLICY founder_all ON public.chain_pharmacy_spend_r2543
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.pharmacy_cross_sell_actions_r2543;
CREATE POLICY founder_all ON public.pharmacy_cross_sell_actions_r2543
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed: 4 spend rows
INSERT INTO public.chain_pharmacy_spend_r2543
  (chain_name, observation_period_start, observation_period_end, pharmacy_spend_rupees, our_influence_kind, cross_sell_opportunity_rupees, upsell_target_kind, owner_email, status, notes)
VALUES
  ('Apollo Telangana Cluster','2026-01-01','2026-03-31',45000000,'indirect',1200000,'amc_tier_up','bd@equipseva.in','in_discussion','Pharmacy buyer open to bundling AMC tier-up with consumables'),
  ('Yashoda Hyderabad','2026-01-01','2026-03-31',22000000,'direct',850000,'consumables','founder@equipseva.in','won','Cross-sell consumables won via joint program'),
  ('Continental Hospitals','2026-02-01','2026-04-30',18500000,'strategic_partner',650000,'equipment_add','bd@equipseva.in','in_discussion','Strategic partner status post Q1 pilot'),
  ('KIMS Secunderabad','2026-01-01','2026-03-31',31000000,'none',420000,'training','bd@equipseva.in','monitoring','No influence yet, training-led wedge planned');

-- Seed: 5 action rows
INSERT INTO public.pharmacy_cross_sell_actions_r2543
  (spend_id, action_at, action_kind, outcome, owner_email, status, notes)
VALUES
  ((SELECT id FROM public.chain_pharmacy_spend_r2543 WHERE chain_name='Apollo Telangana Cluster'),'2026-02-15 10:00:00'::timestamptz,'meeting','positive','bd@equipseva.in','done','Met procurement head, pitched AMC tier-up bundle'),
  ((SELECT id FROM public.chain_pharmacy_spend_r2543 WHERE chain_name='Apollo Telangana Cluster'),'2026-03-01 14:00:00'::timestamptz,'pitch_pack','pending','bd@equipseva.in','in_progress','Sent custom pitch pack with consumables overlay'),
  ((SELECT id FROM public.chain_pharmacy_spend_r2543 WHERE chain_name='Yashoda Hyderabad'),'2026-02-20 11:00:00'::timestamptz,'joint_program','positive','founder@equipseva.in','done','Joint consumables program signed'),
  ((SELECT id FROM public.chain_pharmacy_spend_r2543 WHERE chain_name='Continental Hospitals'),'2026-03-10 15:30:00'::timestamptz,'discount','neutral','bd@equipseva.in','in_progress','Offered 8% on equipment add-on, pending CFO'),
  ((SELECT id FROM public.chain_pharmacy_spend_r2543 WHERE chain_name='KIMS Secunderabad'),'2026-03-25 09:00:00'::timestamptz,'email_followup','pending','bd@equipseva.in','open','Initial training wedge intro email sent');

-- RPC 1: list_spend_r2543
CREATE OR REPLACE FUNCTION public.list_spend_r2543()
RETURNS SETOF public.chain_pharmacy_spend_r2543
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.chain_pharmacy_spend_r2543 ORDER BY pharmacy_spend_rupees DESC, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_spend_r2543() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_spend_r2543() TO authenticated;

-- RPC 2: list_cross_sell_actions_r2543
CREATE OR REPLACE FUNCTION public.list_cross_sell_actions_r2543()
RETURNS TABLE (
  id uuid,
  spend_id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.spend_id, s.chain_name, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
  FROM public.pharmacy_cross_sell_actions_r2543 a
  JOIN public.chain_pharmacy_spend_r2543 s ON s.id = a.spend_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_cross_sell_actions_r2543() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cross_sell_actions_r2543() TO authenticated;

-- RPC 3: top_opportunity_chains_r2543
CREATE OR REPLACE FUNCTION public.top_opportunity_chains_r2543()
RETURNS TABLE (
  chain_name text,
  total_pharmacy_spend_rupees bigint,
  total_cross_sell_opportunity_rupees bigint,
  influence_kind text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.chain_name,
         SUM(s.pharmacy_spend_rupees)::bigint,
         SUM(s.cross_sell_opportunity_rupees)::bigint,
         MAX(s.our_influence_kind),
         MAX(s.status)
  FROM public.chain_pharmacy_spend_r2543 s
  GROUP BY s.chain_name
  ORDER BY SUM(s.cross_sell_opportunity_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_opportunity_chains_r2543() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_opportunity_chains_r2543() TO authenticated;

-- RPC 4: influence_kind_summary_r2543
CREATE OR REPLACE FUNCTION public.influence_kind_summary_r2543()
RETURNS TABLE (
  our_influence_kind text,
  chain_count bigint,
  total_pharmacy_spend_rupees bigint,
  total_cross_sell_opportunity_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.our_influence_kind,
         COUNT(*)::bigint,
         SUM(s.pharmacy_spend_rupees)::bigint,
         SUM(s.cross_sell_opportunity_rupees)::bigint
  FROM public.chain_pharmacy_spend_r2543 s
  GROUP BY s.our_influence_kind
  ORDER BY SUM(s.pharmacy_spend_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.influence_kind_summary_r2543() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.influence_kind_summary_r2543() TO authenticated;

-- RPC 5: upsell_target_breakdown_r2543
CREATE OR REPLACE FUNCTION public.upsell_target_breakdown_r2543()
RETURNS TABLE (
  upsell_target_kind text,
  chain_count bigint,
  total_cross_sell_opportunity_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.upsell_target_kind,
         COUNT(*)::bigint,
         SUM(s.cross_sell_opportunity_rupees)::bigint
  FROM public.chain_pharmacy_spend_r2543 s
  GROUP BY s.upsell_target_kind
  ORDER BY SUM(s.cross_sell_opportunity_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.upsell_target_breakdown_r2543() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsell_target_breakdown_r2543() TO authenticated;

-- RPC 6: monthly_cross_sell_trend_r2543
CREATE OR REPLACE FUNCTION public.monthly_cross_sell_trend_r2543()
RETURNS TABLE (
  month_label text,
  action_count bigint,
  positive_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', a.action_at), 'YYYY-MM'),
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'pending')::bigint
  FROM public.pharmacy_cross_sell_actions_r2543 a
  GROUP BY date_trunc('month', a.action_at)
  ORDER BY date_trunc('month', a.action_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_cross_sell_trend_r2543() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_cross_sell_trend_r2543() TO authenticated;

-- RPC 7: status_funnel_r2543
CREATE OR REPLACE FUNCTION public.status_funnel_r2543()
RETURNS TABLE (
  status text,
  chain_count bigint,
  total_cross_sell_opportunity_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.status,
         COUNT(*)::bigint,
         SUM(s.cross_sell_opportunity_rupees)::bigint
  FROM public.chain_pharmacy_spend_r2543 s
  GROUP BY s.status
  ORDER BY
    CASE s.status
      WHEN 'monitoring' THEN 1
      WHEN 'in_discussion' THEN 2
      WHEN 'won' THEN 3
      WHEN 'lost' THEN 4
      WHEN 'dropped' THEN 5
      ELSE 6
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2543() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2543() TO authenticated;
