BEGIN;

-- ============================================================
-- Round 1758: Founder Outbound Investor Map
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_outbound_investor_targets_r1758 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_investor_name text NOT NULL,
  target_firm text,
  expected_check_rupees bigint,
  intro_path_md text,
  priority text NOT NULL DEFAULT 'tier_2' CHECK (priority IN ('tier_1','tier_2','tier_3')),
  status text NOT NULL DEFAULT 'unconnected' CHECK (status IN ('unconnected','in_research','intro_requested','intro_made','in_dialog','closed')),
  last_action_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_outbound_intro_attempts_r1758 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES public.founder_outbound_investor_targets_r1758(id) ON DELETE CASCADE,
  attempt_via text NOT NULL CHECK (attempt_via IN ('intro_request','cold_email','event','linkedin','twitter')),
  attempted_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fo_targets_r1758_priority ON public.founder_outbound_investor_targets_r1758(priority);
CREATE INDEX IF NOT EXISTS idx_fo_targets_r1758_status ON public.founder_outbound_investor_targets_r1758(status);
CREATE INDEX IF NOT EXISTS idx_fo_attempts_r1758_target ON public.founder_outbound_intro_attempts_r1758(target_id);
CREATE INDEX IF NOT EXISTS idx_fo_attempts_r1758_when ON public.founder_outbound_intro_attempts_r1758(attempted_at DESC);

ALTER TABLE public.founder_outbound_investor_targets_r1758 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_outbound_intro_attempts_r1758 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_targets_r1758 ON public.founder_outbound_investor_targets_r1758;
CREATE POLICY founder_all_targets_r1758 ON public.founder_outbound_investor_targets_r1758
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_attempts_r1758 ON public.founder_outbound_intro_attempts_r1758;
CREATE POLICY founder_all_attempts_r1758 ON public.founder_outbound_intro_attempts_r1758
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_targets
-- ============================================================
DROP FUNCTION IF EXISTS public.r1758_list_targets();
CREATE OR REPLACE FUNCTION public.r1758_list_targets()
RETURNS TABLE (
  id uuid,
  target_investor_name text,
  target_firm text,
  expected_check_rupees bigint,
  intro_path_md text,
  priority text,
  status text,
  last_action_at timestamptz,
  attempts_count int,
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
  SELECT
    t.id,
    t.target_investor_name,
    t.target_firm,
    t.expected_check_rupees,
    t.intro_path_md,
    t.priority,
    t.status,
    t.last_action_at,
    (SELECT COUNT(*) FROM public.founder_outbound_intro_attempts_r1758 a WHERE a.target_id = t.id)::int AS attempts_count,
    t.created_at
  FROM public.founder_outbound_investor_targets_r1758 t
  ORDER BY
    CASE t.priority WHEN 'tier_1' THEN 1 WHEN 'tier_2' THEN 2 ELSE 3 END,
    t.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1758_list_targets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1758_list_targets() TO authenticated;

-- ============================================================
-- RPC 2: add_target
-- ============================================================
DROP FUNCTION IF EXISTS public.r1758_add_target(text, text, bigint, text, text);
CREATE OR REPLACE FUNCTION public.r1758_add_target(
  p_target_investor_name text,
  p_target_firm text,
  p_expected_check_rupees bigint,
  p_intro_path_md text,
  p_priority text
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

  INSERT INTO public.founder_outbound_investor_targets_r1758 (
    target_investor_name, target_firm, expected_check_rupees, intro_path_md, priority
  ) VALUES (
    p_target_investor_name, p_target_firm, p_expected_check_rupees, p_intro_path_md, COALESCE(p_priority, 'tier_2')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1758_add_target',
    jsonb_build_object('id', v_id, 'name', p_target_investor_name, 'priority', p_priority)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1758_add_target(text, text, bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1758_add_target(text, text, bigint, text, text) TO authenticated;

-- ============================================================
-- RPC 3: list_attempts
-- ============================================================
DROP FUNCTION IF EXISTS public.r1758_list_attempts(uuid);
CREATE OR REPLACE FUNCTION public.r1758_list_attempts(p_target_id uuid)
RETURNS TABLE (
  id uuid,
  target_id uuid,
  target_investor_name text,
  attempt_via text,
  attempted_at timestamptz,
  by_email text,
  response text
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
    a.id,
    a.target_id,
    t.target_investor_name,
    a.attempt_via,
    a.attempted_at,
    a.by_email,
    a.response
  FROM public.founder_outbound_intro_attempts_r1758 a
  JOIN public.founder_outbound_investor_targets_r1758 t ON t.id = a.target_id
  WHERE p_target_id IS NULL OR a.target_id = p_target_id
  ORDER BY a.attempted_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1758_list_attempts(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1758_list_attempts(uuid) TO authenticated;

-- ============================================================
-- RPC 4: log_attempt
-- ============================================================
DROP FUNCTION IF EXISTS public.r1758_log_attempt(uuid, text, text);
CREATE OR REPLACE FUNCTION public.r1758_log_attempt(
  p_target_id uuid,
  p_attempt_via text,
  p_response text
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

  INSERT INTO public.founder_outbound_intro_attempts_r1758 (
    target_id, attempt_via, by_email, response
  ) VALUES (
    p_target_id, p_attempt_via, v_email, p_response
  )
  RETURNING id INTO v_id;

  UPDATE public.founder_outbound_investor_targets_r1758
  SET last_action_at = now(), updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'r1758_log_attempt',
    jsonb_build_object('attempt_id', v_id, 'target_id', p_target_id, 'via', p_attempt_via)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1758_log_attempt(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1758_log_attempt(uuid, text, text) TO authenticated;

-- ============================================================
-- RPC 5: update_status
-- ============================================================
DROP FUNCTION IF EXISTS public.r1758_update_status(uuid, text);
CREATE OR REPLACE FUNCTION public.r1758_update_status(
  p_target_id uuid,
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

  UPDATE public.founder_outbound_investor_targets_r1758
  SET status = p_status, last_action_at = now(), updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1758_update_status',
    jsonb_build_object('target_id', p_target_id, 'status', p_status)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1758_update_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1758_update_status(uuid, text) TO authenticated;

-- ============================================================
-- RPC 6: priority_summary
-- ============================================================
DROP FUNCTION IF EXISTS public.r1758_priority_summary();
CREATE OR REPLACE FUNCTION public.r1758_priority_summary()
RETURNS TABLE (
  priority text,
  target_count int,
  expected_check_total_rupees bigint,
  unconnected_count int,
  in_dialog_count int,
  closed_count int
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
    t.priority,
    COUNT(*)::int AS target_count,
    COALESCE(SUM(t.expected_check_rupees), 0)::bigint AS expected_check_total_rupees,
    (COUNT(*) FILTER (WHERE t.status = 'unconnected'))::int AS unconnected_count,
    (COUNT(*) FILTER (WHERE t.status = 'in_dialog'))::int AS in_dialog_count,
    (COUNT(*) FILTER (WHERE t.status = 'closed'))::int AS closed_count
  FROM public.founder_outbound_investor_targets_r1758 t
  GROUP BY t.priority
  ORDER BY CASE t.priority WHEN 'tier_1' THEN 1 WHEN 'tier_2' THEN 2 ELSE 3 END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1758_priority_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1758_priority_summary() TO authenticated;

-- ============================================================
-- RPC 7: conversion_funnel
-- ============================================================
DROP FUNCTION IF EXISTS public.r1758_conversion_funnel();
CREATE OR REPLACE FUNCTION public.r1758_conversion_funnel()
RETURNS TABLE (
  stage text,
  stage_order int,
  target_count int,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COUNT(*)::int INTO v_total FROM public.founder_outbound_investor_targets_r1758;

  RETURN QUERY
  SELECT
    s.stage,
    s.stage_order,
    (COUNT(t.id) FILTER (WHERE t.status = s.stage))::int AS target_count,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE ROUND(((COUNT(t.id) FILTER (WHERE t.status = s.stage))::numeric / v_total::numeric) * 100, 2)
    END AS pct_of_total
  FROM (
    VALUES
      ('unconnected', 1),
      ('in_research', 2),
      ('intro_requested', 3),
      ('intro_made', 4),
      ('in_dialog', 5),
      ('closed', 6)
  ) AS s(stage, stage_order)
  LEFT JOIN public.founder_outbound_investor_targets_r1758 t ON t.status = s.stage
  GROUP BY s.stage, s.stage_order
  ORDER BY s.stage_order;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1758_conversion_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1758_conversion_funnel() TO authenticated;

COMMIT;