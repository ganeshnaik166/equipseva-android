BEGIN;

-- ============================================================================
-- Round 1854: Founder Strategy Off-Site Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_strategy_offsites_r1854 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offsite_label text NOT NULL,
  location text,
  start_date date,
  end_date date,
  attendees text[] DEFAULT '{}'::text[],
  theme text,
  key_decisions_md text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_strategy_offsite_outcomes_r1854 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offsite_id uuid NOT NULL REFERENCES public.founder_strategy_offsites_r1854(id) ON DELETE CASCADE,
  outcome_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategy_offsites_r1854 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_strategy_offsite_outcomes_r1854 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_offsites_r1854 ON public.founder_strategy_offsites_r1854;
CREATE POLICY founder_all_offsites_r1854 ON public.founder_strategy_offsites_r1854
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_outcomes_r1854 ON public.founder_strategy_offsite_outcomes_r1854;
CREATE POLICY founder_all_outcomes_r1854 ON public.founder_strategy_offsite_outcomes_r1854
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_offsites_r1854_status ON public.founder_strategy_offsites_r1854(status);
CREATE INDEX IF NOT EXISTS idx_offsites_r1854_start ON public.founder_strategy_offsites_r1854(start_date DESC);
CREATE INDEX IF NOT EXISTS idx_outcomes_r1854_offsite ON public.founder_strategy_offsite_outcomes_r1854(offsite_id);
CREATE INDEX IF NOT EXISTS idx_outcomes_r1854_status ON public.founder_strategy_offsite_outcomes_r1854(status);

-- ============================================================================
-- RPC 1: list_offsites
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_offsites_r1854()
RETURNS TABLE (
  id uuid,
  offsite_label text,
  location text,
  start_date date,
  end_date date,
  attendees text[],
  theme text,
  status text,
  outcome_count int,
  outcomes_done int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.offsite_label,
    o.location,
    o.start_date,
    o.end_date,
    o.attendees,
    o.theme,
    o.status,
    (COUNT(oc.id))::int AS outcome_count,
    (COUNT(oc.id) FILTER (WHERE oc.status = 'done'))::int AS outcomes_done,
    o.created_at
  FROM public.founder_strategy_offsites_r1854 o
  LEFT JOIN public.founder_strategy_offsite_outcomes_r1854 oc ON oc.offsite_id = o.id
  GROUP BY o.id
  ORDER BY o.start_date DESC NULLS LAST, o.created_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: plan_offsite
-- ============================================================================
CREATE OR REPLACE FUNCTION public.plan_offsite_r1854(
  p_label text,
  p_location text,
  p_start_date date,
  p_end_date date,
  p_attendees text[],
  p_theme text,
  p_key_decisions_md text
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

  INSERT INTO public.founder_strategy_offsites_r1854(
    offsite_label, location, start_date, end_date, attendees, theme, key_decisions_md, status
  )
  VALUES (
    p_label, p_location, p_start_date, p_end_date,
    COALESCE(p_attendees, '{}'::text[]), p_theme, p_key_decisions_md, 'planned'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'plan_offsite_r1854',
    jsonb_build_object('offsite_id', v_id, 'label', p_label, 'location', p_location)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_outcomes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_outcomes_r1854(p_offsite_id uuid)
RETURNS TABLE (
  id uuid,
  offsite_id uuid,
  outcome_text text,
  owner_email text,
  due_date date,
  status text,
  completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    oc.id, oc.offsite_id, oc.outcome_text, oc.owner_email, oc.due_date,
    oc.status, oc.completed_at, oc.created_at
  FROM public.founder_strategy_offsite_outcomes_r1854 oc
  WHERE oc.offsite_id = p_offsite_id
  ORDER BY
    CASE oc.status WHEN 'open' THEN 0 WHEN 'done' THEN 1 ELSE 2 END,
    oc.due_date NULLS LAST,
    oc.created_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================================
-- RPC 4: log_outcome
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_outcome_r1854(
  p_offsite_id uuid,
  p_outcome_text text,
  p_owner_email text,
  p_due_date date
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

  INSERT INTO public.founder_strategy_offsite_outcomes_r1854(
    offsite_id, outcome_text, owner_email, due_date, status
  )
  VALUES (p_offsite_id, p_outcome_text, p_owner_email, p_due_date, 'open')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_outcome_r1854',
    jsonb_build_object('outcome_id', v_id, 'offsite_id', p_offsite_id, 'owner', p_owner_email)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: complete_outcome
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_outcome_r1854(
  p_outcome_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('open','done','dropped') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status;
  END IF;

  UPDATE public.founder_strategy_offsite_outcomes_r1854
  SET status = p_new_status,
      completed_at = CASE WHEN p_new_status = 'done' THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_outcome_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'complete_outcome_r1854',
    jsonb_build_object('outcome_id', p_outcome_id, 'new_status', p_new_status)
  );
END;
$$;

-- ============================================================================
-- RPC 6: recent_offsites
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_offsites_r1854(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  offsite_label text,
  location text,
  start_date date,
  status text,
  theme text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.offsite_label, o.location, o.start_date, o.status, o.theme
  FROM public.founder_strategy_offsites_r1854 o
  ORDER BY o.created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 10), 1);
END;
$$;

-- ============================================================================
-- RPC 7: recent_outcomes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_outcomes_r1854(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  offsite_id uuid,
  offsite_label text,
  outcome_text text,
  owner_email text,
  due_date date,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    oc.id, oc.offsite_id, o.offsite_label, oc.outcome_text,
    oc.owner_email, oc.due_date, oc.status, oc.created_at
  FROM public.founder_strategy_offsite_outcomes_r1854 oc
  JOIN public.founder_strategy_offsites_r1854 o ON o.id = oc.offsite_id
  ORDER BY oc.created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 25), 1);
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_offsites_r1854() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.plan_offsite_r1854(text, text, date, date, text[], text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r1854(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_outcome_r1854(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_outcome_r1854(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_offsites_r1854(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_outcomes_r1854(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_offsites_r1854() TO authenticated;
GRANT EXECUTE ON FUNCTION public.plan_offsite_r1854(text, text, date, date, text[], text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r1854(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_outcome_r1854(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_outcome_r1854(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_offsites_r1854(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_outcomes_r1854(int) TO authenticated;

COMMIT;