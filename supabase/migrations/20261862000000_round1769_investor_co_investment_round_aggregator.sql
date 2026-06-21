BEGIN;

-- Table 1: observations
CREATE TABLE IF NOT EXISTS public.investor_co_investment_observations_r1769 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_a_id uuid NOT NULL,
  investor_b_id uuid NOT NULL,
  round_label text,
  co_invest_count int NOT NULL DEFAULT 1,
  last_seen_together_at timestamptz DEFAULT now(),
  relationship_strength text CHECK (relationship_strength IN ('weak','moderate','strong')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_co_investment_observations_r1769 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_obs_r1769 ON public.investor_co_investment_observations_r1769;
CREATE POLICY founder_all_obs_r1769 ON public.investor_co_investment_observations_r1769
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: pairings
CREATE TABLE IF NOT EXISTS public.investor_co_investment_pairings_r1769 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pairing_id uuid NOT NULL DEFAULT gen_random_uuid(),
  investor_a_id uuid NOT NULL,
  investor_b_id uuid NOT NULL,
  latest_round text,
  anchor_investor uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_co_investment_pairings_r1769 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pairs_r1769 ON public.investor_co_investment_pairings_r1769;
CREATE POLICY founder_all_pairs_r1769 ON public.investor_co_investment_pairings_r1769
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_co_investment_observations
CREATE OR REPLACE FUNCTION public.list_co_investment_observations_r1769()
RETURNS TABLE (
  id uuid,
  investor_a_id uuid,
  investor_b_id uuid,
  round_label text,
  co_invest_count int,
  last_seen_together_at timestamptz,
  relationship_strength text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.id, o.investor_a_id, o.investor_b_id, o.round_label, o.co_invest_count,
         o.last_seen_together_at, o.relationship_strength, o.created_at
  FROM public.investor_co_investment_observations_r1769 o
  ORDER BY o.last_seen_together_at DESC NULLS LAST
  LIMIT 200;
END;
$$;

-- RPC 2: log_observation
CREATE OR REPLACE FUNCTION public.log_co_investment_observation_r1769(
  p_investor_a uuid,
  p_investor_b uuid,
  p_round_label text,
  p_strength text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_co_investment_observations_r1769
    (investor_a_id, investor_b_id, round_label, relationship_strength, last_seen_together_at)
  VALUES (p_investor_a, p_investor_b, p_round_label, p_strength, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_co_investment_observation_r1769',
          jsonb_build_object('id', v_id, 'a', p_investor_a, 'b', p_investor_b, 'round', p_round_label));
  RETURN v_id;
END;
$$;

-- RPC 3: list_pairings
CREATE OR REPLACE FUNCTION public.list_co_investment_pairings_r1769()
RETURNS TABLE (
  id uuid,
  pairing_id uuid,
  investor_a_id uuid,
  investor_b_id uuid,
  latest_round text,
  anchor_investor uuid,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT p.id, p.pairing_id, p.investor_a_id, p.investor_b_id, p.latest_round,
         p.anchor_investor, p.created_at
  FROM public.investor_co_investment_pairings_r1769 p
  ORDER BY p.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: refresh_pairings
CREATE OR REPLACE FUNCTION public.refresh_co_investment_pairings_r1769()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.investor_co_investment_pairings_r1769
    (investor_a_id, investor_b_id, latest_round, anchor_investor)
  SELECT o.investor_a_id, o.investor_b_id,
         (array_agg(o.round_label ORDER BY o.last_seen_together_at DESC NULLS LAST))[1] AS latest_round,
         o.investor_a_id AS anchor_investor
  FROM public.investor_co_investment_observations_r1769 o
  WHERE NOT EXISTS (
    SELECT 1 FROM public.investor_co_investment_pairings_r1769 p
    WHERE p.investor_a_id = o.investor_a_id AND p.investor_b_id = o.investor_b_id
  )
  GROUP BY o.investor_a_id, o.investor_b_id;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_co_investment_pairings_r1769',
          jsonb_build_object('inserted', v_inserted));

  RETURN v_inserted;
END;
$$;

-- RPC 5: top_co_investor_pairs
CREATE OR REPLACE FUNCTION public.top_co_investor_pairs_r1769()
RETURNS TABLE (
  investor_a_id uuid,
  investor_b_id uuid,
  total_co_invests bigint,
  strong_count bigint,
  last_seen timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.investor_a_id,
         o.investor_b_id,
         SUM(o.co_invest_count)::bigint AS total_co_invests,
         (COUNT(*) FILTER (WHERE o.relationship_strength = 'strong'))::bigint AS strong_count,
         MAX(o.last_seen_together_at) AS last_seen
  FROM public.investor_co_investment_observations_r1769 o
  GROUP BY o.investor_a_id, o.investor_b_id
  ORDER BY total_co_invests DESC
  LIMIT 50;
END;
$$;

-- RPC 6: suggested_intros_per_investor
CREATE OR REPLACE FUNCTION public.suggested_intros_per_investor_r1769(p_investor uuid)
RETURNS TABLE (
  candidate_investor uuid,
  co_invest_count bigint,
  latest_round text,
  strength text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    CASE WHEN o.investor_a_id = p_investor THEN o.investor_b_id ELSE o.investor_a_id END AS candidate_investor,
    SUM(o.co_invest_count)::bigint AS co_invest_count,
    (array_agg(o.round_label ORDER BY o.last_seen_together_at DESC NULLS LAST))[1] AS latest_round,
    (array_agg(o.relationship_strength ORDER BY o.last_seen_together_at DESC NULLS LAST))[1] AS strength
  FROM public.investor_co_investment_observations_r1769 o
  WHERE o.investor_a_id = p_investor OR o.investor_b_id = p_investor
  GROUP BY candidate_investor
  ORDER BY co_invest_count DESC
  LIMIT 25;
END;
$$;

-- RPC 7: network_density_summary
CREATE OR REPLACE FUNCTION public.co_investment_network_density_summary_r1769()
RETURNS TABLE (
  total_observations bigint,
  total_pairings bigint,
  unique_investors bigint,
  strong_pairings bigint,
  moderate_pairings bigint,
  weak_pairings bigint,
  avg_co_invests numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.investor_co_investment_observations_r1769)::bigint AS total_observations,
    (SELECT COUNT(*) FROM public.investor_co_investment_pairings_r1769)::bigint AS total_pairings,
    (SELECT COUNT(DISTINCT inv) FROM (
        SELECT investor_a_id AS inv FROM public.investor_co_investment_observations_r1769
        UNION
        SELECT investor_b_id AS inv FROM public.investor_co_investment_observations_r1769
    ) u)::bigint AS unique_investors,
    (SELECT COUNT(*) FROM public.investor_co_investment_observations_r1769 WHERE relationship_strength='strong')::bigint AS strong_pairings,
    (SELECT COUNT(*) FROM public.investor_co_investment_observations_r1769 WHERE relationship_strength='moderate')::bigint AS moderate_pairings,
    (SELECT COUNT(*) FROM public.investor_co_investment_observations_r1769 WHERE relationship_strength='weak')::bigint AS weak_pairings,
    COALESCE((SELECT AVG(co_invest_count)::numeric(10,2) FROM public.investor_co_investment_observations_r1769), 0)::numeric AS avg_co_invests;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_co_investment_observations_r1769() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_co_investment_observation_r1769(uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_co_investment_pairings_r1769() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_co_investment_pairings_r1769() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_co_investor_pairs_r1769() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.suggested_intros_per_investor_r1769(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.co_investment_network_density_summary_r1769() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_co_investment_observations_r1769() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_co_investment_observation_r1769(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_co_investment_pairings_r1769() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_co_investment_pairings_r1769() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_co_investor_pairs_r1769() TO authenticated;
GRANT EXECUTE ON FUNCTION public.suggested_intros_per_investor_r1769(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.co_investment_network_density_summary_r1769() TO authenticated;

COMMIT;