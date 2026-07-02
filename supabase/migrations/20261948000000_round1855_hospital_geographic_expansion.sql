BEGIN;

-- ============================================================================
-- Round 1855: Hospital Geographic Expansion
-- Track new geographic markets entered + revenue performance
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_geographic_expansion_r1855 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  market_name text NOT NULL,
  city text NOT NULL,
  state text NOT NULL,
  launched_at timestamptz NOT NULL DEFAULT now(),
  first_hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  total_hospitals int NOT NULL DEFAULT 0,
  total_arr_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','exited')),
  exited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hge_r1855_status ON public.hospital_geographic_expansion_r1855(status);
CREATE INDEX IF NOT EXISTS idx_hge_r1855_launched ON public.hospital_geographic_expansion_r1855(launched_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_expansion_milestones_r1855 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id uuid NOT NULL REFERENCES public.hospital_geographic_expansion_r1855(id) ON DELETE CASCADE,
  milestone text NOT NULL CHECK (milestone IN ('first_hospital','first_engineer','first_arr_lakh','break_even','first_amc')),
  achieved_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hem_r1855_market ON public.hospital_expansion_milestones_r1855(market_id);
CREATE INDEX IF NOT EXISTS idx_hem_r1855_milestone ON public.hospital_expansion_milestones_r1855(milestone);

-- RLS
ALTER TABLE public.hospital_geographic_expansion_r1855 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_expansion_milestones_r1855 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hge_r1855 ON public.hospital_geographic_expansion_r1855;
CREATE POLICY founder_all_hge_r1855 ON public.hospital_geographic_expansion_r1855
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hem_r1855 ON public.hospital_expansion_milestones_r1855;
CREATE POLICY founder_all_hem_r1855 ON public.hospital_expansion_milestones_r1855
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_markets
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_markets_r1855();
CREATE OR REPLACE FUNCTION public.list_markets_r1855()
RETURNS TABLE (
  id uuid,
  market_name text,
  city text,
  state text,
  launched_at timestamptz,
  total_hospitals int,
  total_arr_rupees bigint,
  status text,
  exited_at timestamptz
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
  SELECT m.id, m.market_name, m.city, m.state, m.launched_at,
         m.total_hospitals, m.total_arr_rupees, m.status, m.exited_at
  FROM public.hospital_geographic_expansion_r1855 m
  ORDER BY m.launched_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_markets_r1855() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_markets_r1855() TO authenticated;

-- ============================================================================
-- RPC 2: launch_market
-- ============================================================================
DROP FUNCTION IF EXISTS public.launch_market_r1855(text, text, text, uuid);
CREATE OR REPLACE FUNCTION public.launch_market_r1855(
  p_market_name text,
  p_city text,
  p_state text,
  p_first_hospital_user_id uuid DEFAULT NULL
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

  INSERT INTO public.hospital_geographic_expansion_r1855
    (market_name, city, state, first_hospital_user_id, status)
  VALUES (p_market_name, p_city, p_state, p_first_hospital_user_id, 'active')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'launch_market_r1855',
    jsonb_build_object('market_id', v_id, 'market_name', p_market_name, 'city', p_city, 'state', p_state)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.launch_market_r1855(text, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.launch_market_r1855(text, text, text, uuid) TO authenticated;

-- ============================================================================
-- RPC 3: list_milestones
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_milestones_r1855(uuid);
CREATE OR REPLACE FUNCTION public.list_milestones_r1855(p_market_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  market_id uuid,
  market_name text,
  milestone text,
  achieved_at timestamptz
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
  SELECT em.id, em.market_id, m.market_name, em.milestone, em.achieved_at
  FROM public.hospital_expansion_milestones_r1855 em
  JOIN public.hospital_geographic_expansion_r1855 m ON m.id = em.market_id
  WHERE p_market_id IS NULL OR em.market_id = p_market_id
  ORDER BY em.achieved_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_milestones_r1855(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_milestones_r1855(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_milestone
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_milestone_r1855(uuid, text);
CREATE OR REPLACE FUNCTION public.log_milestone_r1855(
  p_market_id uuid,
  p_milestone text
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

  INSERT INTO public.hospital_expansion_milestones_r1855 (market_id, milestone)
  VALUES (p_market_id, p_milestone)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_milestone_r1855',
    jsonb_build_object('milestone_id', v_id, 'market_id', p_market_id, 'milestone', p_milestone)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_milestone_r1855(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_milestone_r1855(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 5: exit_market
-- ============================================================================
DROP FUNCTION IF EXISTS public.exit_market_r1855(uuid);
CREATE OR REPLACE FUNCTION public.exit_market_r1855(p_market_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.hospital_geographic_expansion_r1855
  SET status = 'exited',
      exited_at = now(),
      updated_at = now()
  WHERE id = p_market_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'exit_market_r1855',
    jsonb_build_object('market_id', p_market_id)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.exit_market_r1855(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.exit_market_r1855(uuid) TO authenticated;

-- ============================================================================
-- RPC 6: top_growth_markets
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_growth_markets_r1855();
CREATE OR REPLACE FUNCTION public.top_growth_markets_r1855()
RETURNS TABLE (
  id uuid,
  market_name text,
  city text,
  state text,
  total_hospitals int,
  total_arr_rupees bigint,
  status text
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
  SELECT m.id, m.market_name, m.city, m.state,
         m.total_hospitals, m.total_arr_rupees, m.status
  FROM public.hospital_geographic_expansion_r1855 m
  WHERE m.status = 'active'
  ORDER BY m.total_arr_rupees DESC, m.total_hospitals DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_growth_markets_r1855() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_growth_markets_r1855() TO authenticated;

-- ============================================================================
-- RPC 7: total_expansion_arr
-- ============================================================================
DROP FUNCTION IF EXISTS public.total_expansion_arr_r1855();
CREATE OR REPLACE FUNCTION public.total_expansion_arr_r1855()
RETURNS TABLE (
  total_markets int,
  active_markets int,
  exited_markets int,
  total_hospitals int,
  total_arr_rupees bigint
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
    (COUNT(*))::int AS total_markets,
    (COUNT(*) FILTER (WHERE m.status = 'active'))::int AS active_markets,
    (COUNT(*) FILTER (WHERE m.status = 'exited'))::int AS exited_markets,
    COALESCE(SUM(m.total_hospitals), 0)::int AS total_hospitals,
    COALESCE(SUM(m.total_arr_rupees), 0)::bigint AS total_arr_rupees
  FROM public.hospital_geographic_expansion_r1855 m;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.total_expansion_arr_r1855() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_expansion_arr_r1855() TO authenticated;

COMMIT;