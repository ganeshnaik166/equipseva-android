BEGIN;

-- =========================================================================
-- Round 1996 — Engineer Loyalty Program Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_loyalty_program_r1996 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  loyalty_tier text NOT NULL CHECK (loyalty_tier IN ('rookie','bronze','silver','gold','platinum')),
  tenure_months int NOT NULL DEFAULT 0,
  quality_score int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','upgraded','lapsed','exited')),
  reward_balance_rupees bigint NOT NULL DEFAULT 0,
  last_assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_loyalty_r1996_engineer ON public.engineer_loyalty_program_r1996(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_loyalty_r1996_tier ON public.engineer_loyalty_program_r1996(loyalty_tier);
CREATE INDEX IF NOT EXISTS idx_eng_loyalty_r1996_status ON public.engineer_loyalty_program_r1996(status);

ALTER TABLE public.engineer_loyalty_program_r1996 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_loyalty_r1996_founder_all ON public.engineer_loyalty_program_r1996;
CREATE POLICY eng_loyalty_r1996_founder_all
  ON public.engineer_loyalty_program_r1996
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_loyalty_reward_log_r1996 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loyalty_id uuid NOT NULL REFERENCES public.engineer_loyalty_program_r1996(id) ON DELETE CASCADE,
  reward_type text NOT NULL CHECK (reward_type IN ('bonus_payout','recognition','promotion_bonus','exit_bonus','anniversary')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_loyalty_reward_r1996_loyalty ON public.engineer_loyalty_reward_log_r1996(loyalty_id);
CREATE INDEX IF NOT EXISTS idx_eng_loyalty_reward_r1996_type ON public.engineer_loyalty_reward_log_r1996(reward_type);
CREATE INDEX IF NOT EXISTS idx_eng_loyalty_reward_r1996_taken ON public.engineer_loyalty_reward_log_r1996(taken_at DESC);

ALTER TABLE public.engineer_loyalty_reward_log_r1996 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_loyalty_reward_r1996_founder_all ON public.engineer_loyalty_reward_log_r1996;
CREATE POLICY eng_loyalty_reward_r1996_founder_all
  ON public.engineer_loyalty_reward_log_r1996
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

CREATE OR REPLACE FUNCTION public.list_loyalties_r1996(p_limit int DEFAULT 100)
RETURNS SETOF public.engineer_loyalty_program_r1996
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_loyalty_program_r1996
    ORDER BY created_at DESC
    LIMIT GREATEST(COALESCE(p_limit, 100), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_loyalty_r1996(
  p_engineer_user_id uuid,
  p_loyalty_tier text,
  p_tenure_months int,
  p_quality_score int,
  p_status text,
  p_reward_balance_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_loyalty_program_r1996(
    engineer_user_id, loyalty_tier, tenure_months, quality_score, status, reward_balance_rupees, last_assessed_at
  ) VALUES (
    p_engineer_user_id, p_loyalty_tier, COALESCE(p_tenure_months,0), COALESCE(p_quality_score,0),
    COALESCE(p_status,'active'), COALESCE(p_reward_balance_rupees,0), now()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_loyalty_r1996',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'tier', p_loyalty_tier));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_rewards_r1996(p_loyalty_id uuid, p_limit int DEFAULT 100)
RETURNS SETOF public.engineer_loyalty_reward_log_r1996
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_loyalty_reward_log_r1996
    WHERE loyalty_id = p_loyalty_id
    ORDER BY taken_at DESC
    LIMIT GREATEST(COALESCE(p_limit, 100), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reward_r1996(
  p_loyalty_id uuid,
  p_reward_type text,
  p_by_email text,
  p_amount_rupees bigint,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_loyalty_reward_log_r1996(loyalty_id, reward_type, by_email, amount_rupees, notes_md)
  VALUES (p_loyalty_id, p_reward_type, p_by_email, COALESCE(p_amount_rupees,0), p_notes_md)
  RETURNING id INTO v_id;

  UPDATE public.engineer_loyalty_program_r1996
     SET reward_balance_rupees = reward_balance_rupees + COALESCE(p_amount_rupees,0),
         updated_at = now()
   WHERE id = p_loyalty_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reward_r1996',
          jsonb_build_object('id', v_id, 'loyalty_id', p_loyalty_id, 'reward_type', p_reward_type, 'amount', p_amount_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1996(p_loyalty_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_loyalty_program_r1996
     SET status = p_status, last_assessed_at = now(), updated_at = now()
   WHERE id = p_loyalty_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1996',
          jsonb_build_object('id', p_loyalty_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_loyal_r1996(p_limit int DEFAULT 20)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  loyalty_tier text,
  tenure_months int,
  quality_score int,
  reward_balance_rupees bigint,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.engineer_user_id, l.loyalty_tier, l.tenure_months, l.quality_score,
           l.reward_balance_rupees, l.status
    FROM public.engineer_loyalty_program_r1996 l
    WHERE l.status = 'active'
    ORDER BY l.quality_score DESC, l.tenure_months DESC
    LIMIT GREATEST(COALESCE(p_limit, 20), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_rewards_r1996(p_limit int DEFAULT 50)
RETURNS SETOF public.engineer_loyalty_reward_log_r1996
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_loyalty_reward_log_r1996
    ORDER BY taken_at DESC
    LIMIT GREATEST(COALESCE(p_limit, 50), 1);
END;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_loyalties_r1996(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_loyalty_r1996(uuid, text, int, int, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_rewards_r1996(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reward_r1996(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1996(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_loyal_r1996(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_rewards_r1996(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_loyalties_r1996(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_loyalty_r1996(uuid, text, int, int, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_rewards_r1996(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reward_r1996(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1996(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_loyal_r1996(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_rewards_r1996(int) TO authenticated;

COMMIT;
