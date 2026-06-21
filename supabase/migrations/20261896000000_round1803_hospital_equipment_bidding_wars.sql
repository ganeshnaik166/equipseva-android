BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_bidding_wars_r1803 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  bid_window_start timestamptz NOT NULL,
  bid_window_end timestamptz NOT NULL,
  our_quote_rupees bigint NOT NULL,
  competitor_count int NOT NULL DEFAULT 0,
  won boolean,
  decision_basis text CHECK (decision_basis IN ('price','relationship','features','service','timing')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_bidding_competitors_r1803 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bidding_war_id uuid NOT NULL REFERENCES public.hospital_bidding_wars_r1803(id) ON DELETE CASCADE,
  competitor_name text NOT NULL,
  competitor_quote_rupees bigint NOT NULL,
  competitor_strength text,
  our_disadvantage text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_bidding_wars_r1803 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_bidding_competitors_r1803 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_bidding_wars_r1803 ON public.hospital_bidding_wars_r1803;
CREATE POLICY founder_all_bidding_wars_r1803 ON public.hospital_bidding_wars_r1803
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_bidding_competitors_r1803 ON public.hospital_bidding_competitors_r1803;
CREATE POLICY founder_all_bidding_competitors_r1803 ON public.hospital_bidding_competitors_r1803
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- list_bidding_wars
CREATE OR REPLACE FUNCTION public.list_bidding_wars_r1803()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_name text,
  bid_window_start timestamptz,
  bid_window_end timestamptz,
  our_quote_rupees bigint,
  competitor_count int,
  won boolean,
  decision_basis text,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.id, w.hospital_user_id, p.email, w.equipment_name, w.bid_window_start, w.bid_window_end,
           w.our_quote_rupees, w.competitor_count, w.won, w.decision_basis, w.decided_at, w.created_at
    FROM public.hospital_bidding_wars_r1803 w
    LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
    ORDER BY w.created_at DESC
    LIMIT 200;
END;
$$;

-- log_bidding_war
CREATE OR REPLACE FUNCTION public.log_bidding_war_r1803(
  p_hospital_user_id uuid,
  p_equipment_name text,
  p_bid_window_start timestamptz,
  p_bid_window_end timestamptz,
  p_our_quote_rupees bigint,
  p_competitor_count int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_bidding_wars_r1803(hospital_user_id, equipment_name, bid_window_start, bid_window_end, our_quote_rupees, competitor_count)
  VALUES (p_hospital_user_id, p_equipment_name, p_bid_window_start, p_bid_window_end, p_our_quote_rupees, COALESCE(p_competitor_count, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_bidding_war_r1803',
          jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'equipment_name', p_equipment_name, 'our_quote_rupees', p_our_quote_rupees));
  RETURN v_id;
END;
$$;

-- list_competitors
CREATE OR REPLACE FUNCTION public.list_competitors_r1803(p_bidding_war_id uuid)
RETURNS TABLE (
  id uuid,
  bidding_war_id uuid,
  competitor_name text,
  competitor_quote_rupees bigint,
  competitor_strength text,
  our_disadvantage text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.bidding_war_id, c.competitor_name, c.competitor_quote_rupees, c.competitor_strength, c.our_disadvantage, c.created_at
    FROM public.hospital_bidding_competitors_r1803 c
    WHERE c.bidding_war_id = p_bidding_war_id
    ORDER BY c.competitor_quote_rupees ASC NULLS LAST
    LIMIT 200;
END;
$$;

-- log_competitor
CREATE OR REPLACE FUNCTION public.log_competitor_r1803(
  p_bidding_war_id uuid,
  p_competitor_name text,
  p_competitor_quote_rupees bigint,
  p_competitor_strength text,
  p_our_disadvantage text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_bidding_competitors_r1803(bidding_war_id, competitor_name, competitor_quote_rupees, competitor_strength, our_disadvantage)
  VALUES (p_bidding_war_id, p_competitor_name, p_competitor_quote_rupees, p_competitor_strength, p_our_disadvantage)
  RETURNING id INTO v_id;

  UPDATE public.hospital_bidding_wars_r1803
    SET competitor_count = (SELECT COUNT(*)::int FROM public.hospital_bidding_competitors_r1803 WHERE bidding_war_id = p_bidding_war_id),
        updated_at = now()
    WHERE id = p_bidding_war_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_competitor_r1803',
          jsonb_build_object('id', v_id, 'bidding_war_id', p_bidding_war_id, 'competitor_name', p_competitor_name, 'competitor_quote_rupees', p_competitor_quote_rupees));
  RETURN v_id;
END;
$$;

-- mark_decision
CREATE OR REPLACE FUNCTION public.mark_decision_r1803(
  p_bidding_war_id uuid,
  p_won boolean,
  p_decision_basis text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision_basis NOT IN ('price','relationship','features','service','timing') THEN
    RAISE EXCEPTION 'invalid decision_basis';
  END IF;
  UPDATE public.hospital_bidding_wars_r1803
    SET won = p_won,
        decision_basis = p_decision_basis,
        decided_at = now(),
        updated_at = now()
    WHERE id = p_bidding_war_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_decision_r1803',
          jsonb_build_object('bidding_war_id', p_bidding_war_id, 'won', p_won, 'decision_basis', p_decision_basis));
END;
$$;

-- win_rate_summary
CREATE OR REPLACE FUNCTION public.win_rate_summary_r1803()
RETURNS TABLE (
  total_wars int,
  decided_wars int,
  wins int,
  losses int,
  win_rate_pct numeric,
  avg_competitor_count numeric,
  total_our_quote_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::int AS total_wars,
      (COUNT(*) FILTER (WHERE decided_at IS NOT NULL))::int AS decided_wars,
      (COUNT(*) FILTER (WHERE won = true))::int AS wins,
      (COUNT(*) FILTER (WHERE won = false))::int AS losses,
      ROUND(
        CASE WHEN (COUNT(*) FILTER (WHERE decided_at IS NOT NULL))::int = 0 THEN 0
        ELSE ((COUNT(*) FILTER (WHERE won = true))::numeric * 100.0
              / (COUNT(*) FILTER (WHERE decided_at IS NOT NULL))::numeric)
        END, 2) AS win_rate_pct,
      COALESCE(ROUND(AVG(competitor_count)::numeric, 2), 0) AS avg_competitor_count,
      COALESCE(SUM(our_quote_rupees), 0)::bigint AS total_our_quote_rupees
    FROM public.hospital_bidding_wars_r1803;
END;
$$;

-- decision_basis_distribution
CREATE OR REPLACE FUNCTION public.decision_basis_distribution_r1803()
RETURNS TABLE (
  decision_basis text,
  wars int,
  wins int,
  losses int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      w.decision_basis,
      COUNT(*)::int AS wars,
      (COUNT(*) FILTER (WHERE w.won = true))::int AS wins,
      (COUNT(*) FILTER (WHERE w.won = false))::int AS losses
    FROM public.hospital_bidding_wars_r1803 w
    WHERE w.decision_basis IS NOT NULL
    GROUP BY w.decision_basis
    ORDER BY wars DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_bidding_wars_r1803() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_bidding_war_r1803(uuid, text, timestamptz, timestamptz, bigint, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_competitors_r1803(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_competitor_r1803(uuid, text, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_decision_r1803(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.win_rate_summary_r1803() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decision_basis_distribution_r1803() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_bidding_wars_r1803() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_bidding_war_r1803(uuid, text, timestamptz, timestamptz, bigint, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_competitors_r1803(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_competitor_r1803(uuid, text, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_decision_r1803(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.win_rate_summary_r1803() TO authenticated;
GRANT EXECUTE ON FUNCTION public.decision_basis_distribution_r1803() TO authenticated;

COMMIT;