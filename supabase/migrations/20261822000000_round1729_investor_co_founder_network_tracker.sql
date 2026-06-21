BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.investor_network_intros_r1729 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  intro_to_name text NOT NULL,
  intro_to_org text,
  intro_to_role text,
  intro_date date NOT NULL DEFAULT CURRENT_DATE,
  intro_purpose text NOT NULL CHECK (intro_purpose IN ('hire','customer','funding','advice','partnership')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','converted','dropped','closed')),
  value_realized_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_intro_outcome_log_r1729 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intro_id uuid NOT NULL REFERENCES public.investor_network_intros_r1729(id) ON DELETE CASCADE,
  outcome_type text NOT NULL CHECK (outcome_type IN ('hired','customer_signed','funding_received','advice_taken','partnership_formed')),
  outcome_at timestamptz NOT NULL DEFAULT now(),
  outcome_value_rupees bigint,
  founder_thanks_sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.investor_network_intros_r1729 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_intro_outcome_log_r1729 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_intros_r1729 ON public.investor_network_intros_r1729;
CREATE POLICY founder_all_intros_r1729 ON public.investor_network_intros_r1729
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_outcomes_r1729 ON public.investor_intro_outcome_log_r1729;
CREATE POLICY founder_all_outcomes_r1729 ON public.investor_intro_outcome_log_r1729
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_intros
CREATE OR REPLACE FUNCTION public.list_intros_r1729()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  intro_to_name text,
  intro_to_org text,
  intro_to_role text,
  intro_date date,
  intro_purpose text,
  status text,
  value_realized_md text,
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
    SELECT i.id, i.investor_id, p.email::text, i.intro_to_name, i.intro_to_org, i.intro_to_role,
           i.intro_date, i.intro_purpose, i.status, i.value_realized_md, i.created_at
      FROM public.investor_network_intros_r1729 i
      LEFT JOIN public.profiles p ON p.id = i.investor_id
     ORDER BY i.intro_date DESC, i.created_at DESC
     LIMIT 200;
END;
$$;

-- RPC 2: log_intro
CREATE OR REPLACE FUNCTION public.log_intro_r1729(
  p_investor_id uuid,
  p_intro_to_name text,
  p_intro_to_org text,
  p_intro_to_role text,
  p_intro_purpose text,
  p_value_md text
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
  INSERT INTO public.investor_network_intros_r1729 (investor_id, intro_to_name, intro_to_org, intro_to_role, intro_purpose, value_realized_md)
    VALUES (p_investor_id, p_intro_to_name, p_intro_to_org, p_intro_to_role, p_intro_purpose, p_value_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_intro_r1729',
            jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'intro_to_name', p_intro_to_name, 'purpose', p_intro_purpose));
  RETURN v_id;
END;
$$;

-- RPC 3: list_outcomes
CREATE OR REPLACE FUNCTION public.list_outcomes_r1729()
RETURNS TABLE (
  id uuid,
  intro_id uuid,
  intro_to_name text,
  outcome_type text,
  outcome_at timestamptz,
  outcome_value_rupees bigint,
  founder_thanks_sent_at timestamptz
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
    SELECT o.id, o.intro_id, i.intro_to_name, o.outcome_type, o.outcome_at, o.outcome_value_rupees, o.founder_thanks_sent_at
      FROM public.investor_intro_outcome_log_r1729 o
      LEFT JOIN public.investor_network_intros_r1729 i ON i.id = o.intro_id
     ORDER BY o.outcome_at DESC
     LIMIT 200;
END;
$$;

-- RPC 4: record_outcome
CREATE OR REPLACE FUNCTION public.record_outcome_r1729(
  p_intro_id uuid,
  p_outcome_type text,
  p_outcome_value bigint
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
  INSERT INTO public.investor_intro_outcome_log_r1729 (intro_id, outcome_type, outcome_value_rupees)
    VALUES (p_intro_id, p_outcome_type, p_outcome_value)
    RETURNING id INTO v_id;
  UPDATE public.investor_network_intros_r1729
     SET status = 'converted', updated_at = now()
   WHERE id = p_intro_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_outcome_r1729',
            jsonb_build_object('id', v_id, 'intro_id', p_intro_id, 'outcome_type', p_outcome_type, 'value', p_outcome_value));
  RETURN v_id;
END;
$$;

-- RPC 5: top_intro_investors
CREATE OR REPLACE FUNCTION public.top_intro_investors_r1729()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  intros_count int,
  conversions int,
  total_value_rupees bigint
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
    SELECT i.investor_id,
           p.email::text,
           COUNT(*)::int AS intros_count,
           (COUNT(*) FILTER (WHERE i.status = 'converted'))::int AS conversions,
           COALESCE(SUM(o.outcome_value_rupees), 0)::bigint AS total_value_rupees
      FROM public.investor_network_intros_r1729 i
      LEFT JOIN public.profiles p ON p.id = i.investor_id
      LEFT JOIN public.investor_intro_outcome_log_r1729 o ON o.intro_id = i.id
     GROUP BY i.investor_id, p.email
     ORDER BY conversions DESC, intros_count DESC
     LIMIT 50;
END;
$$;

-- RPC 6: recent_conversions
CREATE OR REPLACE FUNCTION public.recent_conversions_r1729()
RETURNS TABLE (
  intro_id uuid,
  intro_to_name text,
  intro_to_org text,
  outcome_type text,
  outcome_at timestamptz,
  outcome_value_rupees bigint
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
    SELECT i.id, i.intro_to_name, i.intro_to_org, o.outcome_type, o.outcome_at, o.outcome_value_rupees
      FROM public.investor_intro_outcome_log_r1729 o
      JOIN public.investor_network_intros_r1729 i ON i.id = o.intro_id
     WHERE o.outcome_at > now() - interval '90 days'
     ORDER BY o.outcome_at DESC
     LIMIT 100;
END;
$$;

-- RPC 7: unthanked_intros
CREATE OR REPLACE FUNCTION public.unthanked_intros_r1729()
RETURNS TABLE (
  outcome_id uuid,
  intro_id uuid,
  intro_to_name text,
  investor_email text,
  outcome_type text,
  outcome_at timestamptz,
  days_since int
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
    SELECT o.id, o.intro_id, i.intro_to_name, p.email::text, o.outcome_type, o.outcome_at,
           EXTRACT(DAY FROM (now() - o.outcome_at))::int AS days_since
      FROM public.investor_intro_outcome_log_r1729 o
      JOIN public.investor_network_intros_r1729 i ON i.id = o.intro_id
      LEFT JOIN public.profiles p ON p.id = i.investor_id
     WHERE o.founder_thanks_sent_at IS NULL
     ORDER BY o.outcome_at ASC
     LIMIT 100;
END;
$$;

-- Permissions
REVOKE EXECUTE ON FUNCTION public.list_intros_r1729() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_intro_r1729(uuid, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r1729() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_outcome_r1729(uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_intro_investors_r1729() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_conversions_r1729() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.unthanked_intros_r1729() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_intros_r1729() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_intro_r1729(uuid, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r1729() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_outcome_r1729(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_intro_investors_r1729() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_conversions_r1729() TO authenticated;
GRANT EXECUTE ON FUNCTION public.unthanked_intros_r1729() TO authenticated;

COMMIT;