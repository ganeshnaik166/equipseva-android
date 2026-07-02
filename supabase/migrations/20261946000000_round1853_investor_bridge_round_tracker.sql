BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.investor_bridge_rounds_r1853 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bridge_label text NOT NULL,
  target_amount_rupees bigint NOT NULL DEFAULT 0,
  raised_amount_rupees bigint NOT NULL DEFAULT 0,
  lead_investor_id uuid,
  started_at timestamptz NOT NULL DEFAULT now(),
  expected_close timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','extended')),
  valuation_cap_rupees bigint,
  discount_pct numeric(5,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_bridge_participants_r1853 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bridge_id uuid NOT NULL REFERENCES public.investor_bridge_rounds_r1853(id) ON DELETE CASCADE,
  investor_id uuid NOT NULL,
  commitment_rupees bigint NOT NULL DEFAULT 0,
  funded_rupees bigint NOT NULL DEFAULT 0,
  funded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.investor_bridge_rounds_r1853 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_bridge_participants_r1853 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bridge_rounds_founder_all ON public.investor_bridge_rounds_r1853;
CREATE POLICY bridge_rounds_founder_all ON public.investor_bridge_rounds_r1853
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS bridge_participants_founder_all ON public.investor_bridge_participants_r1853;
CREATE POLICY bridge_participants_founder_all ON public.investor_bridge_participants_r1853
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC: list_bridges
CREATE OR REPLACE FUNCTION public.list_bridges_r1853()
RETURNS TABLE (
  id uuid,
  bridge_label text,
  target_amount_rupees bigint,
  raised_amount_rupees bigint,
  lead_investor_id uuid,
  started_at timestamptz,
  expected_close timestamptz,
  status text,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  participant_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.bridge_label, b.target_amount_rupees, b.raised_amount_rupees,
         b.lead_investor_id, b.started_at, b.expected_close, b.status,
         b.valuation_cap_rupees, b.discount_pct,
         (SELECT COUNT(*) FROM public.investor_bridge_participants_r1853 p WHERE p.bridge_id = b.id)::int
  FROM public.investor_bridge_rounds_r1853 b
  ORDER BY b.started_at DESC;
END $$;

-- RPC: plan_bridge
CREATE OR REPLACE FUNCTION public.plan_bridge_r1853(
  p_label text,
  p_target_rupees bigint,
  p_lead_investor uuid,
  p_expected_close timestamptz,
  p_valuation_cap_rupees bigint,
  p_discount_pct numeric
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_bridge_rounds_r1853 (
    bridge_label, target_amount_rupees, lead_investor_id, expected_close,
    valuation_cap_rupees, discount_pct
  ) VALUES (
    p_label, COALESCE(p_target_rupees,0), p_lead_investor, p_expected_close,
    p_valuation_cap_rupees, p_discount_pct
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'plan_bridge_r1853',
          jsonb_build_object('id', v_id, 'label', p_label, 'target_rupees', p_target_rupees));
  RETURN v_id;
END $$;

-- RPC: list_participants
CREATE OR REPLACE FUNCTION public.list_participants_r1853(p_bridge_id uuid)
RETURNS TABLE (
  id uuid,
  bridge_id uuid,
  investor_id uuid,
  commitment_rupees bigint,
  funded_rupees bigint,
  funded_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.bridge_id, p.investor_id, p.commitment_rupees, p.funded_rupees, p.funded_at, p.created_at
  FROM public.investor_bridge_participants_r1853 p
  WHERE p.bridge_id = p_bridge_id
  ORDER BY p.created_at DESC;
END $$;

-- RPC: log_participant
CREATE OR REPLACE FUNCTION public.log_participant_r1853(
  p_bridge_id uuid,
  p_investor_id uuid,
  p_commitment_rupees bigint,
  p_funded_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_bridge_participants_r1853 (
    bridge_id, investor_id, commitment_rupees, funded_rupees, funded_at
  ) VALUES (
    p_bridge_id, p_investor_id, COALESCE(p_commitment_rupees,0), COALESCE(p_funded_rupees,0),
    CASE WHEN COALESCE(p_funded_rupees,0) > 0 THEN now() ELSE NULL END
  ) RETURNING id INTO v_id;

  UPDATE public.investor_bridge_rounds_r1853 b
  SET raised_amount_rupees = COALESCE((
    SELECT SUM(funded_rupees) FROM public.investor_bridge_participants_r1853 WHERE bridge_id = p_bridge_id
  ),0),
  updated_at = now()
  WHERE b.id = p_bridge_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_participant_r1853',
          jsonb_build_object('id', v_id, 'bridge_id', p_bridge_id, 'investor_id', p_investor_id, 'funded', p_funded_rupees));
  RETURN v_id;
END $$;

-- RPC: close_bridge
CREATE OR REPLACE FUNCTION public.close_bridge_r1853(p_bridge_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_bridge_rounds_r1853
  SET status = 'closed', updated_at = now()
  WHERE id = p_bridge_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_bridge_r1853',
          jsonb_build_object('bridge_id', p_bridge_id));
END $$;

-- RPC: total_bridge_volume
CREATE OR REPLACE FUNCTION public.total_bridge_volume_r1853()
RETURNS TABLE (
  total_target_rupees bigint,
  total_raised_rupees bigint,
  open_count int,
  closed_count int,
  in_progress_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(target_amount_rupees),0)::bigint,
    COALESCE(SUM(raised_amount_rupees),0)::bigint,
    (COUNT(*) FILTER (WHERE status = 'open'))::int,
    (COUNT(*) FILTER (WHERE status = 'closed'))::int,
    (COUNT(*) FILTER (WHERE status = 'in_progress'))::int
  FROM public.investor_bridge_rounds_r1853;
END $$;

-- RPC: recent_closes
CREATE OR REPLACE FUNCTION public.recent_closes_r1853()
RETURNS TABLE (
  id uuid,
  bridge_label text,
  raised_amount_rupees bigint,
  target_amount_rupees bigint,
  status text,
  updated_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.bridge_label, b.raised_amount_rupees, b.target_amount_rupees, b.status, b.updated_at
  FROM public.investor_bridge_rounds_r1853 b
  WHERE b.status IN ('closed','extended')
  ORDER BY b.updated_at DESC
  LIMIT 20;
END $$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_bridges_r1853() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.plan_bridge_r1853(text, bigint, uuid, timestamptz, bigint, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_participants_r1853(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_participant_r1853(uuid, uuid, bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_bridge_r1853(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_bridge_volume_r1853() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_closes_r1853() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_bridges_r1853() TO authenticated;
GRANT EXECUTE ON FUNCTION public.plan_bridge_r1853(text, bigint, uuid, timestamptz, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_participants_r1853(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_participant_r1853(uuid, uuid, bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_bridge_r1853(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_bridge_volume_r1853() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_closes_r1853() TO authenticated;

COMMIT;