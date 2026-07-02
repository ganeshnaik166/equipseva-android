BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_dividend_distributions_r2005 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  dividend_label text NOT NULL,
  distribution_date date NOT NULL,
  amount_rupees bigint NOT NULL CHECK (amount_rupees >= 0),
  dividend_type text NOT NULL CHECK (dividend_type IN ('ordinary','preferred','special','liquidating')),
  status text NOT NULL DEFAULT 'declared' CHECK (status IN ('declared','paid','withheld','disputed')),
  declared_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_dividend_action_log_r2005 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL REFERENCES public.investor_dividend_distributions_r2005(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('declared','sent','received','disputed','clawback')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_dividend_distributions_r2005 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_dividend_action_log_r2005 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_dist_r2005 ON public.investor_dividend_distributions_r2005;
CREATE POLICY founder_all_dist_r2005 ON public.investor_dividend_distributions_r2005
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2005 ON public.investor_dividend_action_log_r2005;
CREATE POLICY founder_all_actions_r2005 ON public.investor_dividend_action_log_r2005
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_distributions_r2005()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  dividend_label text,
  distribution_date date,
  amount_rupees bigint,
  dividend_type text,
  status text,
  declared_at timestamptz,
  paid_at timestamptz,
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
  SELECT d.id, d.investor_id, p.email::text, d.dividend_label, d.distribution_date,
         d.amount_rupees, d.dividend_type, d.status, d.declared_at, d.paid_at, d.created_at
  FROM public.investor_dividend_distributions_r2005 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  ORDER BY d.distribution_date DESC, d.created_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_distribution_r2005(
  p_investor_id uuid,
  p_dividend_label text,
  p_distribution_date date,
  p_amount_rupees bigint,
  p_dividend_type text,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_dividend_distributions_r2005
    (investor_id, dividend_label, distribution_date, amount_rupees, dividend_type, status, declared_at)
  VALUES (p_investor_id, p_dividend_label, p_distribution_date, p_amount_rupees, p_dividend_type, p_status,
          CASE WHEN p_status = 'declared' THEN now() ELSE NULL END)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_distribution_r2005',
          jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'amount_rupees', p_amount_rupees, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2005(p_distribution_id uuid)
RETURNS TABLE (
  id uuid,
  distribution_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.distribution_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
  FROM public.investor_dividend_action_log_r2005 a
  WHERE a.distribution_id = p_distribution_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2005(
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
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.investor_dividend_action_log_r2005
    (distribution_id, action_type, by_email, amount_rupees, notes_md)
  VALUES (p_distribution_id, p_action_type, v_email, p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r2005',
          jsonb_build_object('id', v_id, 'distribution_id', p_distribution_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2005(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_dividend_distributions_r2005
  SET status = p_status,
      paid_at = CASE WHEN p_status = 'paid' THEN now() ELSE paid_at END,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2005',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.total_paid_r2005()
RETURNS TABLE (
  total_paid_rupees bigint,
  total_declared_rupees bigint,
  total_withheld_rupees bigint,
  total_disputed_rupees bigint,
  distinct_investors bigint
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
    COALESCE(SUM(CASE WHEN status = 'paid' THEN amount_rupees ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN status = 'declared' THEN amount_rupees ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN status = 'withheld' THEN amount_rupees ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN status = 'disputed' THEN amount_rupees ELSE 0 END), 0)::bigint,
    COUNT(DISTINCT investor_id)::bigint
  FROM public.investor_dividend_distributions_r2005;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2005()
RETURNS TABLE (
  id uuid,
  distribution_id uuid,
  dividend_label text,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.distribution_id, d.dividend_label, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
  FROM public.investor_dividend_action_log_r2005 a
  LEFT JOIN public.investor_dividend_distributions_r2005 d ON d.id = a.distribution_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_distributions_r2005() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_distribution_r2005(uuid, text, date, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2005(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2005(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2005(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_paid_r2005() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2005() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_distributions_r2005() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_distribution_r2005(uuid, text, date, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2005(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2005(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2005(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_paid_r2005() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2005() TO authenticated;

COMMIT;
