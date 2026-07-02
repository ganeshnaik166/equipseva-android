BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.investor_special_distribution_tracker_r2145 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  distribution_label text NOT NULL,
  amount_rupees bigint NOT NULL DEFAULT 0,
  reason text NOT NULL CHECK (reason IN ('liquidity_event','buyback','extraordinary_dividend','legal_settlement')),
  status text NOT NULL DEFAULT 'declared' CHECK (status IN ('declared','paid','clawback','disputed')),
  declared_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_special_dist_action_log_r2145 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL REFERENCES public.investor_special_distribution_tracker_r2145(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('declared','paid','clawback','disputed','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.investor_special_distribution_tracker_r2145 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_special_dist_action_log_r2145 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2145_dist ON public.investor_special_distribution_tracker_r2145;
CREATE POLICY founder_all_r2145_dist ON public.investor_special_distribution_tracker_r2145
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2145_log ON public.investor_special_dist_action_log_r2145;
CREATE POLICY founder_all_r2145_log ON public.investor_special_dist_action_log_r2145
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_distributions
CREATE OR REPLACE FUNCTION public.list_distributions_r2145()
RETURNS TABLE(id uuid, distribution_label text, amount_rupees bigint, reason text, status text, declared_at timestamptz, paid_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.distribution_label, d.amount_rupees, d.reason, d.status, d.declared_at, d.paid_at, d.created_at
    FROM public.investor_special_distribution_tracker_r2145 d
    ORDER BY d.created_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log_distribution
CREATE OR REPLACE FUNCTION public.log_distribution_r2145(
  p_investor_id uuid,
  p_label text,
  p_amount_rupees bigint,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_special_distribution_tracker_r2145(investor_id, distribution_label, amount_rupees, reason, status, declared_at)
  VALUES (p_investor_id, p_label, p_amount_rupees, p_reason, 'declared', now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_distribution_r2145', jsonb_build_object('id', v_id, 'label', p_label, 'amount_rupees', p_amount_rupees, 'reason', p_reason));

  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2145(p_distribution_id uuid)
RETURNS TABLE(id uuid, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_special_dist_action_log_r2145 a
    WHERE a.distribution_id = p_distribution_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r2145(
  p_distribution_id uuid,
  p_action_type text,
  p_amount_rupees bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_special_dist_action_log_r2145(distribution_id, action_type, by_email, amount_rupees, notes_md)
  VALUES (p_distribution_id, p_action_type, (auth.jwt()->>'email'), p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2145', jsonb_build_object('action_id', v_id, 'distribution_id', p_distribution_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2145(
  p_distribution_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_special_distribution_tracker_r2145
  SET status = p_status,
      paid_at = CASE WHEN p_status = 'paid' THEN now() ELSE paid_at END,
      updated_at = now()
  WHERE id = p_distribution_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2145', jsonb_build_object('distribution_id', p_distribution_id, 'status', p_status));
END;
$$;

-- RPC 6: recent_special
CREATE OR REPLACE FUNCTION public.recent_special_r2145()
RETURNS TABLE(id uuid, distribution_label text, amount_rupees bigint, reason text, status text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.distribution_label, d.amount_rupees, d.reason, d.status, d.created_at
    FROM public.investor_special_distribution_tracker_r2145 d
    WHERE d.created_at > now() - interval '90 days'
    ORDER BY d.created_at DESC
    LIMIT 50;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2145()
RETURNS TABLE(id uuid, distribution_id uuid, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.distribution_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees
    FROM public.investor_special_dist_action_log_r2145 a
    WHERE a.taken_at > now() - interval '60 days'
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

-- REVOKE + GRANT
REVOKE EXECUTE ON FUNCTION public.list_distributions_r2145() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_distributions_r2145() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_distribution_r2145(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_distribution_r2145(uuid, text, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2145(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2145(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_action_r2145(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2145(uuid, text, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2145(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2145(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_special_r2145() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_special_r2145() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2145() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2145() TO authenticated;

COMMIT;
