BEGIN;

-- Table 1: Investor annual report reactions
CREATE TABLE IF NOT EXISTS public.investor_annual_report_reaction_log_r2129 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  report_year text NOT NULL,
  reaction_type text NOT NULL CHECK (reaction_type IN ('very_positive','positive','neutral','concern','critical')),
  reaction_md text,
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received','follow_up_needed','escalated','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iarrl_r2129_investor ON public.investor_annual_report_reaction_log_r2129(investor_id);
CREATE INDEX IF NOT EXISTS idx_iarrl_r2129_year ON public.investor_annual_report_reaction_log_r2129(report_year);
CREATE INDEX IF NOT EXISTS idx_iarrl_r2129_status ON public.investor_annual_report_reaction_log_r2129(status);
CREATE INDEX IF NOT EXISTS idx_iarrl_r2129_captured ON public.investor_annual_report_reaction_log_r2129(captured_at DESC);

ALTER TABLE public.investor_annual_report_reaction_log_r2129 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iarrl_r2129_founder_all ON public.investor_annual_report_reaction_log_r2129;
CREATE POLICY iarrl_r2129_founder_all ON public.investor_annual_report_reaction_log_r2129
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: Action log per reaction
CREATE TABLE IF NOT EXISTS public.investor_reaction_action_log_r2129 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reaction_id uuid NOT NULL REFERENCES public.investor_annual_report_reaction_log_r2129(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('acknowledged','follow_up','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iral_r2129_reaction ON public.investor_reaction_action_log_r2129(reaction_id);
CREATE INDEX IF NOT EXISTS idx_iral_r2129_taken ON public.investor_reaction_action_log_r2129(taken_at DESC);

ALTER TABLE public.investor_reaction_action_log_r2129 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iral_r2129_founder_all ON public.investor_reaction_action_log_r2129;
CREATE POLICY iral_r2129_founder_all ON public.investor_reaction_action_log_r2129
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list reactions
CREATE OR REPLACE FUNCTION public.list_investor_annual_report_reactions_r2129()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  report_year text,
  reaction_type text,
  reaction_md text,
  status text,
  captured_at timestamptz,
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
  SELECT r.id, r.investor_id, p.email::text, r.report_year, r.reaction_type, r.reaction_md, r.status, r.captured_at, r.created_at
  FROM public.investor_annual_report_reaction_log_r2129 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY r.captured_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: log reaction
CREATE OR REPLACE FUNCTION public.log_investor_annual_report_reaction_r2129(
  p_investor_id uuid,
  p_report_year text,
  p_reaction_type text,
  p_reaction_md text
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
  INSERT INTO public.investor_annual_report_reaction_log_r2129(investor_id, report_year, reaction_type, reaction_md)
  VALUES (p_investor_id, p_report_year, p_reaction_type, p_reaction_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_annual_report_reaction_r2129',
    jsonb_build_object('reaction_id', v_id, 'investor_id', p_investor_id, 'report_year', p_report_year, 'reaction_type', p_reaction_type));
  RETURN v_id;
END;
$$;

-- RPC 3: list actions
CREATE OR REPLACE FUNCTION public.list_investor_reaction_actions_r2129()
RETURNS TABLE (
  id uuid,
  reaction_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text,
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
  SELECT a.id, a.reaction_id, a.action_type, a.taken_at, a.by_email, a.notes_md, a.created_at
  FROM public.investor_reaction_action_log_r2129 a
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log action
CREATE OR REPLACE FUNCTION public.log_investor_reaction_action_r2129(
  p_reaction_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.investor_reaction_action_log_r2129(reaction_id, action_type, by_email, notes_md)
  VALUES (p_reaction_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_investor_reaction_action_r2129',
    jsonb_build_object('action_id', v_id, 'reaction_id', p_reaction_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark status
CREATE OR REPLACE FUNCTION public.mark_investor_reaction_status_r2129(
  p_reaction_id uuid,
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
  UPDATE public.investor_annual_report_reaction_log_r2129
  SET status = p_status, updated_at = now()
  WHERE id = p_reaction_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_investor_reaction_status_r2129',
    jsonb_build_object('reaction_id', p_reaction_id, 'status', p_status));
END;
$$;

-- RPC 6: concerns (concern + critical)
CREATE OR REPLACE FUNCTION public.list_investor_reaction_concerns_r2129()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  report_year text,
  reaction_type text,
  reaction_md text,
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
  SELECT r.id, r.investor_id, p.email::text, r.report_year, r.reaction_type, r.reaction_md, r.status, r.captured_at
  FROM public.investor_annual_report_reaction_log_r2129 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  WHERE r.reaction_type IN ('concern','critical')
  ORDER BY r.captured_at DESC
  LIMIT 200;
END;
$$;

-- RPC 7: recent actions (last 14 days)
CREATE OR REPLACE FUNCTION public.list_investor_reaction_recent_actions_r2129()
RETURNS TABLE (
  id uuid,
  reaction_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
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
  SELECT a.id, a.reaction_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_reaction_action_log_r2129 a
  WHERE a.taken_at >= now() - interval '14 days'
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_investor_annual_report_reactions_r2129() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_annual_report_reactions_r2129() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_annual_report_reaction_r2129(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_annual_report_reaction_r2129(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_reaction_actions_r2129() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_reaction_actions_r2129() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_reaction_action_r2129(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_reaction_action_r2129(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_investor_reaction_status_r2129(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_investor_reaction_status_r2129(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_reaction_concerns_r2129() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_reaction_concerns_r2129() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_reaction_recent_actions_r2129() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_reaction_recent_actions_r2129() TO authenticated;

COMMIT;
