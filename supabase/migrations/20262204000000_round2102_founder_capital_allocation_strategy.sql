BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_capital_allocation_strategy_r2102 (
  id uuid primary key default gen_random_uuid(),
  period_label text not null,
  total_allocated_rupees bigint not null default 0,
  growth_rupees bigint not null default 0,
  ops_rupees bigint not null default 0,
  hires_rupees bigint not null default 0,
  marketing_rupees bigint not null default 0,
  reserves_rupees bigint not null default 0,
  status text not null default 'planned' check (status in ('planned','executing','closed','superseded')),
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

CREATE TABLE IF NOT EXISTS public.founder_allocation_action_log_r2102 (
  id uuid primary key default gen_random_uuid(),
  allocation_id uuid not null references public.founder_capital_allocation_strategy_r2102(id) on delete cascade,
  action_type text not null check (action_type in ('planned','executed','reallocated','escalated','closed')),
  taken_at timestamptz not null default now(),
  by_email text,
  amount_rupees bigint not null default 0,
  notes_md text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

ALTER TABLE public.founder_capital_allocation_strategy_r2102 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_allocation_action_log_r2102 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_strategy_r2102 ON public.founder_capital_allocation_strategy_r2102;
CREATE POLICY founder_only_strategy_r2102 ON public.founder_capital_allocation_strategy_r2102
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_actions_r2102 ON public.founder_allocation_action_log_r2102;
CREATE POLICY founder_only_actions_r2102 ON public.founder_allocation_action_log_r2102
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_allocations_r2102()
RETURNS TABLE (
  id uuid,
  period_label text,
  total_allocated_rupees bigint,
  growth_rupees bigint,
  ops_rupees bigint,
  hires_rupees bigint,
  marketing_rupees bigint,
  reserves_rupees bigint,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.period_label, s.total_allocated_rupees, s.growth_rupees, s.ops_rupees,
           s.hires_rupees, s.marketing_rupees, s.reserves_rupees, s.status, s.captured_at
    FROM public.founder_capital_allocation_strategy_r2102 s
    ORDER BY s.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_allocation_r2102(
  p_period_label text,
  p_total bigint,
  p_growth bigint,
  p_ops bigint,
  p_hires bigint,
  p_marketing bigint,
  p_reserves bigint,
  p_status text
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
  INSERT INTO public.founder_capital_allocation_strategy_r2102(
    period_label, total_allocated_rupees, growth_rupees, ops_rupees,
    hires_rupees, marketing_rupees, reserves_rupees, status
  ) VALUES (
    p_period_label, p_total, p_growth, p_ops, p_hires, p_marketing, p_reserves, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_allocation_r2102',
          jsonb_build_object('id', v_id, 'period', p_period_label, 'total', p_total, 'status', p_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2102(p_allocation_id uuid)
RETURNS TABLE (
  id uuid,
  allocation_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.allocation_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.founder_allocation_action_log_r2102 a
    WHERE a.allocation_id = p_allocation_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2102(
  p_allocation_id uuid,
  p_action_type text,
  p_by_email text,
  p_amount_rupees bigint,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_allocation_action_log_r2102(
    allocation_id, action_type, by_email, amount_rupees, notes_md
  ) VALUES (
    p_allocation_id, p_action_type, p_by_email, p_amount_rupees, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2102',
          jsonb_build_object('id', v_id, 'allocation_id', p_allocation_id, 'action_type', p_action_type, 'amount', p_amount_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2102(p_allocation_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_capital_allocation_strategy_r2102
     SET status = p_status, updated_at = now()
   WHERE id = p_allocation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2102',
          jsonb_build_object('id', p_allocation_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.current_allocation_r2102()
RETURNS TABLE (
  id uuid,
  period_label text,
  total_allocated_rupees bigint,
  growth_rupees bigint,
  ops_rupees bigint,
  hires_rupees bigint,
  marketing_rupees bigint,
  reserves_rupees bigint,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.period_label, s.total_allocated_rupees, s.growth_rupees, s.ops_rupees,
           s.hires_rupees, s.marketing_rupees, s.reserves_rupees, s.status, s.captured_at
    FROM public.founder_capital_allocation_strategy_r2102 s
    WHERE s.status IN ('planned','executing')
    ORDER BY s.captured_at DESC
    LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2102()
RETURNS TABLE (
  id uuid,
  allocation_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.allocation_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.founder_allocation_action_log_r2102 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_allocations_r2102() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_allocation_r2102(text, bigint, bigint, bigint, bigint, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2102(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2102(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2102(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_allocation_r2102() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2102() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_allocations_r2102() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_allocation_r2102(text, bigint, bigint, bigint, bigint, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2102(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2102(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2102(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_allocation_r2102() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2102() TO authenticated;

COMMIT;
