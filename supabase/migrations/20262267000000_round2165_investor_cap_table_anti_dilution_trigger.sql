BEGIN;

-- ============================================================================
-- Round 2165: Investor Cap Table Anti-Dilution Trigger
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_cap_table_anti_dilution_trigger_r2165 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  trigger_event_label text NOT NULL,
  trigger_date date NOT NULL DEFAULT CURRENT_DATE,
  shares_compensated bigint NOT NULL DEFAULT 0,
  trigger_type text NOT NULL CHECK (trigger_type IN ('weighted_avg_broad','weighted_avg_narrow','full_ratchet')),
  status text NOT NULL DEFAULT 'triggered' CHECK (status IN ('triggered','calculated','issued','disputed','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_anti_dilution_action_log_r2165 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trigger_id uuid NOT NULL REFERENCES public.investor_cap_table_anti_dilution_trigger_r2165(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('triggered','calculated','issued','disputed','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_count bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_adt_r2165_investor ON public.investor_cap_table_anti_dilution_trigger_r2165(investor_id);
CREATE INDEX IF NOT EXISTS idx_adt_r2165_status ON public.investor_cap_table_anti_dilution_trigger_r2165(status);
CREATE INDEX IF NOT EXISTS idx_adt_r2165_captured ON public.investor_cap_table_anti_dilution_trigger_r2165(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_adl_r2165_trigger ON public.investor_anti_dilution_action_log_r2165(trigger_id);
CREATE INDEX IF NOT EXISTS idx_adl_r2165_taken ON public.investor_anti_dilution_action_log_r2165(taken_at DESC);

ALTER TABLE public.investor_cap_table_anti_dilution_trigger_r2165 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_anti_dilution_action_log_r2165 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS adt_r2165_founder ON public.investor_cap_table_anti_dilution_trigger_r2165;
CREATE POLICY adt_r2165_founder ON public.investor_cap_table_anti_dilution_trigger_r2165
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS adl_r2165_founder ON public.investor_anti_dilution_action_log_r2165;
CREATE POLICY adl_r2165_founder ON public.investor_anti_dilution_action_log_r2165
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_triggers
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_triggers_r2165()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  trigger_event_label text,
  trigger_date date,
  shares_compensated bigint,
  trigger_type text,
  status text,
  captured_at timestamptz
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
  SELECT t.id, t.investor_id, t.trigger_event_label, t.trigger_date,
         t.shares_compensated, t.trigger_type, t.status, t.captured_at
  FROM public.investor_cap_table_anti_dilution_trigger_r2165 t
  ORDER BY t.captured_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_triggers_r2165() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_triggers_r2165() TO authenticated;

-- ============================================================================
-- RPC 2: log_trigger
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_trigger_r2165(
  p_investor_id uuid,
  p_trigger_event_label text,
  p_trigger_date date,
  p_shares_compensated bigint,
  p_trigger_type text
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
  INSERT INTO public.investor_cap_table_anti_dilution_trigger_r2165(
    investor_id, trigger_event_label, trigger_date, shares_compensated, trigger_type, status
  ) VALUES (
    p_investor_id, p_trigger_event_label, p_trigger_date, p_shares_compensated, p_trigger_type, 'triggered'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_trigger_r2165',
          jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'trigger_type', p_trigger_type));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_trigger_r2165(uuid, text, date, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_trigger_r2165(uuid, text, date, bigint, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r2165(p_trigger_id uuid)
RETURNS TABLE (
  id uuid,
  trigger_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_count bigint,
  notes_md text
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
  SELECT a.id, a.trigger_id, a.action_type, a.taken_at, a.by_email, a.shares_count, a.notes_md
  FROM public.investor_anti_dilution_action_log_r2165 a
  WHERE a.trigger_id = p_trigger_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2165(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2165(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r2165(
  p_trigger_id uuid,
  p_action_type text,
  p_by_email text,
  p_shares_count bigint,
  p_notes_md text
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
  INSERT INTO public.investor_anti_dilution_action_log_r2165(
    trigger_id, action_type, by_email, shares_count, notes_md
  ) VALUES (
    p_trigger_id, p_action_type, p_by_email, p_shares_count, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2165',
          jsonb_build_object('id', v_id, 'trigger_id', p_trigger_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r2165(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2165(uuid, text, text, bigint, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2165(
  p_trigger_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_cap_table_anti_dilution_trigger_r2165
  SET status = p_status, updated_at = now()
  WHERE id = p_trigger_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2165',
          jsonb_build_object('id', p_trigger_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2165(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2165(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: recent_triggers
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_triggers_r2165(p_limit int)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  trigger_event_label text,
  trigger_date date,
  shares_compensated bigint,
  trigger_type text,
  status text,
  captured_at timestamptz
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
  SELECT t.id, t.investor_id, t.trigger_event_label, t.trigger_date,
         t.shares_compensated, t.trigger_type, t.status, t.captured_at
  FROM public.investor_cap_table_anti_dilution_trigger_r2165 t
  ORDER BY t.captured_at DESC
  LIMIT COALESCE(p_limit, 20);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_triggers_r2165(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_triggers_r2165(int) TO authenticated;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2165(p_limit int)
RETURNS TABLE (
  id uuid,
  trigger_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_count bigint,
  notes_md text
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
  SELECT a.id, a.trigger_id, a.action_type, a.taken_at, a.by_email, a.shares_count, a.notes_md
  FROM public.investor_anti_dilution_action_log_r2165 a
  ORDER BY a.taken_at DESC
  LIMIT COALESCE(p_limit, 20);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2165(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2165(int) TO authenticated;

COMMIT;
