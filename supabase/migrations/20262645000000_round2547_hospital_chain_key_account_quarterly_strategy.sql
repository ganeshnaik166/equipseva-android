-- Round 2547: Hospital chain key-account quarterly strategy
-- Chain x KAS quarterly x growth plan x expansion targets x at-risk plan x commitments

CREATE TABLE IF NOT EXISTS public.chain_key_account_quarterly_strategy_r2547 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  growth_plan_md text,
  expansion_targets_md text,
  at_risk_plan_md text,
  commitments_md text,
  our_owner_email text,
  their_sponsor_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','aligned','in_execution','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.key_account_quarterly_checkpoints_r2547 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_id uuid NOT NULL REFERENCES public.chain_key_account_quarterly_strategy_r2547(id) ON DELETE CASCADE,
  checkpoint_at timestamptz NOT NULL DEFAULT now(),
  checkpoint_kind text NOT NULL CHECK (checkpoint_kind IN ('month_1_review','month_2_review','quarter_end')),
  status text NOT NULL DEFAULT 'green' CHECK (status IN ('green','amber','red')),
  commitment_achievement_pct int CHECK (commitment_achievement_pct BETWEEN 0 AND 100),
  observations_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_key_account_quarterly_strategy_r2547 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.key_account_quarterly_checkpoints_r2547 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_key_account_quarterly_strategy_r2547;
CREATE POLICY founder_all ON public.chain_key_account_quarterly_strategy_r2547
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.key_account_quarterly_checkpoints_r2547;
CREATE POLICY founder_all ON public.key_account_quarterly_checkpoints_r2547
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_key_account_quarterly_strategy_r2547
  (chain_name, quarter_label, growth_plan_md, expansion_targets_md, at_risk_plan_md, commitments_md, our_owner_email, their_sponsor_email, status, notes)
VALUES
  ('Apollo Multi-Speciality', 'Q3-2026', '- Cross-sell AMC Platinum to 3 sister hospitals\n- Add 2 ventilators to coverage', '- 4 new hospitals onboarded\n- ₹18L expansion revenue', '- Apollo Hyderabad at risk: 2 escalations in Q2\n- Dedicated SLA + monthly QBR', '- Quarterly QBR\n- 24h critical SLA\n- Dedicated engineer pool', 'founder@equipseva.com', 'cio@apollo.com', 'in_execution', 'Strategic anchor account'),
  ('Care Hospitals Chain', 'Q3-2026', '- Pilot predictive maintenance dashboard\n- Joint case studies', '- 2 new locations\n- Predictive PoC live', '- Renewal at risk Sept-26\n- CFO pushback on AMC pricing', '- Locked rate card Q3\n- Monthly exec review', 'founder@equipseva.com', 'coo@carehospitals.com', 'aligned', 'Renewal cycle starting'),
  ('Yashoda Hospitals', 'Q3-2026', '- Expand to imaging + cathlab\n- BMC director onsite', '- ₹12L new spend\n- 2 new modalities', '- Competing vendor pitch flagged\n- Owner intervention needed', '- Director-level QBR\n- Joint roadmap workshop', 'founder@equipseva.com', 'director@yashoda.com', 'draft', 'New strategic plan'),
  ('Continental Hospitals', 'Q2-2026', '- AMC migration to Platinum\n- Train onsite team', '- 3 new units\n- Full coverage AMC', '- No major risk identified', '- Quarterly business review\n- Training delivered', 'founder@equipseva.com', 'cto@continental.com', 'closed', 'Successful quarter');

INSERT INTO public.key_account_quarterly_checkpoints_r2547
  (strategy_id, checkpoint_kind, status, commitment_achievement_pct, observations_md, owner_email)
SELECT id, 'month_1_review', 'amber', 65, '- Apollo Hyderabad still 1 escalation\n- 2 of 4 new hospitals signed LoI', 'founder@equipseva.com'
FROM public.chain_key_account_quarterly_strategy_r2547 WHERE chain_name='Apollo Multi-Speciality' LIMIT 1;

INSERT INTO public.key_account_quarterly_checkpoints_r2547
  (strategy_id, checkpoint_kind, status, commitment_achievement_pct, observations_md, owner_email)
SELECT id, 'month_1_review', 'green', 85, '- Rate card finalized\n- CFO meeting positive', 'founder@equipseva.com'
FROM public.chain_key_account_quarterly_strategy_r2547 WHERE chain_name='Care Hospitals Chain' LIMIT 1;

INSERT INTO public.key_account_quarterly_checkpoints_r2547
  (strategy_id, checkpoint_kind, status, commitment_achievement_pct, observations_md, owner_email)
SELECT id, 'quarter_end', 'green', 95, '- All commitments delivered\n- Renewal locked', 'founder@equipseva.com'
FROM public.chain_key_account_quarterly_strategy_r2547 WHERE chain_name='Continental Hospitals' LIMIT 1;

INSERT INTO public.key_account_quarterly_checkpoints_r2547
  (strategy_id, checkpoint_kind, status, commitment_achievement_pct, observations_md, owner_email)
SELECT id, 'month_2_review', 'red', 40, '- Competing vendor escalated to board\n- Owner intervention scheduled', 'founder@equipseva.com'
FROM public.chain_key_account_quarterly_strategy_r2547 WHERE chain_name='Yashoda Hospitals' LIMIT 1;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_strategies_r2547()
RETURNS TABLE(id uuid, chain_name text, quarter_label text, status text, our_owner_email text, their_sponsor_email text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.quarter_label, s.status, s.our_owner_email, s.their_sponsor_email, s.created_at
  FROM public.chain_key_account_quarterly_strategy_r2547 s
  ORDER BY s.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_strategies_r2547() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_strategies_r2547() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_checkpoints_r2547()
RETURNS TABLE(id uuid, chain_name text, quarter_label text, checkpoint_kind text, status text, commitment_achievement_pct int, owner_email text, checkpoint_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, s.chain_name, s.quarter_label, c.checkpoint_kind, c.status, c.commitment_achievement_pct, c.owner_email, c.checkpoint_at
  FROM public.key_account_quarterly_checkpoints_r2547 c
  JOIN public.chain_key_account_quarterly_strategy_r2547 s ON s.id = c.strategy_id
  ORDER BY c.checkpoint_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_checkpoints_r2547() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_checkpoints_r2547() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_at_risk_strategies_r2547()
RETURNS TABLE(chain_name text, quarter_label text, latest_status text, latest_achievement_pct int, our_owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.chain_name, s.quarter_label,
         (SELECT c.status FROM public.key_account_quarterly_checkpoints_r2547 c WHERE c.strategy_id=s.id ORDER BY c.checkpoint_at DESC LIMIT 1) AS latest_status,
         (SELECT c.commitment_achievement_pct FROM public.key_account_quarterly_checkpoints_r2547 c WHERE c.strategy_id=s.id ORDER BY c.checkpoint_at DESC LIMIT 1) AS latest_achievement_pct,
         s.our_owner_email
  FROM public.chain_key_account_quarterly_strategy_r2547 s
  WHERE s.status IN ('draft','aligned','in_execution')
  ORDER BY latest_achievement_pct ASC NULLS LAST
  LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_strategies_r2547() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_at_risk_strategies_r2547() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2547()
RETURNS TABLE(status text, n bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.status, count(*)::bigint
  FROM public.chain_key_account_quarterly_strategy_r2547 s
  GROUP BY s.status
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2547() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2547() TO authenticated;

CREATE OR REPLACE FUNCTION public.commitment_achievement_summary_r2547()
RETURNS TABLE(checkpoint_kind text, n bigint, avg_pct numeric, green_n bigint, amber_n bigint, red_n bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.checkpoint_kind,
         count(*)::bigint,
         round(avg(c.commitment_achievement_pct)::numeric, 1),
         count(*) FILTER (WHERE c.status='green')::bigint,
         count(*) FILTER (WHERE c.status='amber')::bigint,
         count(*) FILTER (WHERE c.status='red')::bigint
  FROM public.key_account_quarterly_checkpoints_r2547 c
  GROUP BY c.checkpoint_kind
  ORDER BY c.checkpoint_kind;
END $$;
REVOKE EXECUTE ON FUNCTION public.commitment_achievement_summary_r2547() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commitment_achievement_summary_r2547() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_strategy_trend_r2547()
RETURNS TABLE(quarter_label text, n_strategies bigint, n_closed bigint, n_in_execution bigint, n_aligned bigint, n_draft bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label,
         count(*)::bigint,
         count(*) FILTER (WHERE s.status='closed')::bigint,
         count(*) FILTER (WHERE s.status='in_execution')::bigint,
         count(*) FILTER (WHERE s.status='aligned')::bigint,
         count(*) FILTER (WHERE s.status='draft')::bigint
  FROM public.chain_key_account_quarterly_strategy_r2547 s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_strategy_trend_r2547() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_strategy_trend_r2547() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2547()
RETURNS TABLE(our_owner_email text, n_strategies bigint, n_in_execution bigint, n_closed bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.our_owner_email,
         count(*)::bigint,
         count(*) FILTER (WHERE s.status='in_execution')::bigint,
         count(*) FILTER (WHERE s.status='closed')::bigint
  FROM public.chain_key_account_quarterly_strategy_r2547 s
  WHERE s.our_owner_email IS NOT NULL
  GROUP BY s.our_owner_email
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2547() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2547() TO authenticated;
